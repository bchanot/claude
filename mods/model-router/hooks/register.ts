// model-router: routes each model request (main loop and sub-agents) to the
// model and effort its phase deserves. Phases, agents, skills and prompt
// rules come from DEFAULT_CONFIG, overridable by ~/.claude/model-router.json.
// One writer per concern: the Agent tool's own params are never rewritten,
// the spawn hook sets an agent's model once, turn.step sets efforts.
import type { EngineInterface, On, Register, TurnStepInput } from 'claude-code'

type Api = EngineInterface
type Level = 'low' | 'medium' | 'high' | 'xhigh' | 'max'
type Route = { model?: string; effort?: Level } // model: alias or full id
type PromptRule = { pattern: string; phase: string }
type Config = {
  models: Record<string, string> // alias -> full id
  windows: Record<string, number> // full id -> context window (tokens)
  phases: Record<string, Route>
  agents: Record<string, string> // built-in subagentType -> phase
  skills: Record<string, string> // skill name -> phase
  prompt: PromptRule[]
  mainModelSwitch: boolean
  verbose: boolean
  spinner: boolean
}
type Rule = { re: RegExp; phase: string }
type Source = 'user' | 'model' | 'skill' | 'prompt' | 'slash'
type Routed = { phase: string; route: Route; source: Source }
type Loop = {
  effort?: Level
  model?: string // routed by the table or an in-agent call
  spawnModel: string // the engine's model at spawn
  frozen: boolean // fork or workflow agent: never re-modelled
  explicitModel: boolean // Agent call gave a model: axis frozen
  explicitEffort: boolean // Agent call gave an effort: axis frozen
}
type State = {
  cfg: Config
  rules: Rule[]
  source: string // 'defaults' or the override path
  userMain: Routed | null // /route by the user, sticky until /route clear
  turnMain: Routed | null // tool, skill, slash, prompt; dropped at turn end
  pendingPrompt: Routed | null // typed mid-turn, promoted next turn
  loops: Map<string, Loop> // agentId -> that loop's routing
  explicitEffort: Map<string, Level> // Agent tool_use_id -> effort param
  skillCalls: number // Skill tool calls in flight
  off: boolean // /route off: every hook passes through
  lastMain: string // "model/effort" of the last main step (spinner)
  windowWarned: boolean // context-window warning already logged this turn
}
type Log = (text: string) => void
type StepIn = Readonly<TurnStepInput>
type Plan = { model: string; effort: StepIn['effort'] }
type RouteInput = {
  phase?: unknown
  effort?: unknown
  clear?: unknown
  agentId?: string
}
type Picked = { phase: string; route: Route }

const LEVELS: readonly Level[] = ['low', 'medium', 'high', 'xhigh', 'max']
const MODEL_ID = /^claude-[a-z0-9.-]+$/
const TOOL = 'mcp__model-router__route'
const EFFORT_SKILL = /^effort-(low|medium|high|xhigh|max)$/
const OVERRIDE = '.claude/model-router.json'
const HAIKU = 'claude-haiku'

const DEFAULT_CONFIG: Config = {
  models: {
    haiku: 'claude-haiku-4-5-20251001',
    sonnet: 'claude-sonnet-5-5',
    opus: 'claude-opus-5-5',
    fable: 'claude-fable-5-1',
  },
  windows: { 'claude-haiku-4-5-20251001': 200000 },
  phases: {
    plan: { effort: 'xhigh' },
    reflect: { effort: 'high' },
    orchestrate: { effort: 'medium' },
    escalate: { effort: 'max' },
    judge: { model: 'opus', effort: 'xhigh' },
    implement: { model: 'sonnet', effort: 'medium' },
    write: { model: 'sonnet', effort: 'medium' },
    verify: { model: 'sonnet', effort: 'xhigh' },
    explore: { model: 'sonnet', effort: 'medium' },
    mechanical: { model: 'haiku', effort: 'low' },
  },
  // Built-ins only: repo agents keep their frontmatter pin (wave 2).
  agents: { Explore: 'explore', Plan: 'judge' },
  skills: {},
  prompt: [{ pattern: '\\bultrathink\\b', phase: 'escalate' }],
  mainModelSwitch: false,
  verbose: false,
  spinner: true,
}

// ---- config ----------------------------------------------------------

const isRecord = (v: unknown): v is Record<string, unknown> =>
  typeof v === 'object' && v !== null && !Array.isArray(v)
const isLevel = (v: unknown): v is Level => LEVELS.some(l => l === v)
const isFullId = (v: unknown): v is string =>
  typeof v === 'string' && MODEL_ID.test(v)
const hasKey = (table: object, key: string): boolean =>
  Object.hasOwn(table, key)

function isModelName(models: Record<string, string>, v: unknown): v is string {
  return typeof v === 'string' && (hasKey(models, v) || isFullId(v))
}

function resolveModel(cfg: Config, name: string): string {
  return hasKey(cfg.models, name) ? (cfg.models[name] ?? name) : name
}

function phaseRoute(cfg: Config, phase: string): Route | undefined {
  return hasKey(cfg.phases, phase) ? cfg.phases[phase] : undefined
}

/** Merges a user table over a default one, dropping invalid entries. */
function mergeTable<T>(
  base: Record<string, T>,
  user: unknown,
  name: string,
  accept: (key: string, value: unknown) => T | undefined,
  log: Log,
): Record<string, T> {
  const out = { ...base }
  if (!isRecord(user)) return out
  for (const [key, value] of Object.entries(user)) {
    const ok = key === '__proto__' ? undefined : accept(key, value)
    if (ok === undefined) log(`model-router: config ${name}.${key} ignored`)
    else out[key] = ok
  }
  return out
}

const acceptModel = (_key: string, v: unknown): string | undefined =>
  isFullId(v) ? v : undefined

const acceptWindow = (key: string, v: unknown): number | undefined =>
  isFullId(key) && typeof v === 'number' && Number.isInteger(v) && v > 0
    ? v
    : undefined

function acceptPhase(models: Record<string, string>) {
  return (_key: string, v: unknown): Route | undefined => {
    if (!isRecord(v)) return undefined
    const route: Route = {}
    if (v.effort !== undefined) {
      if (!isLevel(v.effort)) return undefined
      route.effort = v.effort
    }
    if (v.model !== undefined) {
      if (!isModelName(models, v.model)) return undefined
      route.model = v.model
    }
    return route.effort || route.model ? route : undefined
  }
}

function acceptPhaseRef(phases: Record<string, Route>) {
  return (_key: string, v: unknown): string | undefined =>
    typeof v === 'string' && hasKey(phases, v) ? v : undefined
}

function compiles(pattern: string): boolean {
  try {
    new RegExp(pattern, 'i')
    return true
  } catch {
    return false
  }
}

function acceptRule(phases: Record<string, Route>, v: unknown) {
  if (!isRecord(v)) return undefined
  const { pattern, phase } = v
  if (typeof pattern !== 'string' || typeof phase !== 'string') return undefined
  return hasKey(phases, phase) && compiles(pattern)
    ? { pattern, phase }
    : undefined
}

/** A user prompt array replaces the default rules; bad rules are dropped. */
function mergePrompt(
  base: PromptRule[],
  user: unknown,
  phases: Record<string, Route>,
  log: Log,
): PromptRule[] {
  if (!Array.isArray(user)) return base
  const rules: PromptRule[] = []
  for (const item of user as unknown[]) {
    const rule = acceptRule(phases, item)
    if (rule) rules.push(rule)
    else log('model-router: config prompt rule ignored')
  }
  return rules
}

const pickBool = (v: unknown, fallback: boolean): boolean =>
  typeof v === 'boolean' ? v : fallback

/** Defaults overlaid with the user's entries, each validated first. */
function mergeConfig(user: unknown, log: Log): Config {
  const base = structuredClone(DEFAULT_CONFIG)
  if (!isRecord(user)) return base
  const models = mergeTable(
    base.models, user.models, 'models', acceptModel, log)
  const phases = mergeTable(
    base.phases, user.phases, 'phases', acceptPhase(models), log)
  const ref = acceptPhaseRef(phases)
  return {
    models,
    windows: mergeTable(
      base.windows, user.windows, 'windows', acceptWindow, log),
    phases,
    agents: mergeTable(base.agents, user.agents, 'agents', ref, log),
    skills: mergeTable(base.skills, user.skills, 'skills', ref, log),
    prompt: mergePrompt(base.prompt, user.prompt, phases, log),
    mainModelSwitch: pickBool(user.mainModelSwitch, base.mainModelSwitch),
    verbose: pickBool(user.verbose, base.verbose),
    spinner: pickBool(user.spinner, base.spinner),
  }
}

async function readOverride(
  $: Api,
  log: Log,
): Promise<{ path: string; data: unknown } | undefined> {
  try {
    const home = await $.env.get('HOME')
    if (!home) return undefined
    const path = `${home}/${OVERRIDE}`
    if (!(await $.fs.exists(path))) return undefined
    return { path, data: JSON.parse(await $.fs.read(path)) }
  } catch (err) {
    log(`model-router: ${OVERRIDE} unreadable (${String(err)}); defaults`)
    return undefined
  }
}

/** Never throws; a failed read or parse leaves the defaults. */
async function loadConfig(
  $: Api,
  log: Log,
): Promise<{ cfg: Config; source: string }> {
  const found = await readOverride($, log)
  if (!found) return { cfg: mergeConfig(undefined, log), source: 'defaults' }
  return { cfg: mergeConfig(found.data, log), source: found.path }
}

function compileRules(cfg: Config): Rule[] {
  return cfg.prompt.map(r => ({
    re: new RegExp(r.pattern, 'i'),
    phase: r.phase,
  }))
}

// ---- state -----------------------------------------------------------

function newState(cfg: Config, source: string): State {
  return {
    cfg,
    rules: compileRules(cfg),
    source,
    userMain: null,
    turnMain: null,
    pendingPrompt: null,
    loops: new Map(),
    explicitEffort: new Map(),
    skillCalls: 0,
    off: false,
    lastMain: '',
    windowWarned: false,
  }
}

/** The main loop's effective route: user /route > latest turn route. */
const mainRoute = (st: State): Routed | null => st.userMain ?? st.turnMain

function loopOf(st: State, agentId: string): Loop {
  const known = st.loops.get(agentId)
  if (known) return known
  const fresh: Loop = {
    spawnModel: '',
    frozen: false,
    explicitModel: false,
    explicitEffort: false,
  }
  st.loops.set(agentId, fresh)
  return fresh
}

/** Writes a route on an agent loop, never on an axis given explicitly. */
function writeLoop(loop: Loop, route: Route): void {
  if (!loop.explicitEffort) loop.effort = route.effort
  if (!loop.explicitModel) loop.model = route.model
}

function clearRoutes(st: State): void {
  st.userMain = null
  st.turnMain = null
  st.pendingPrompt = null
}

// ---- text ------------------------------------------------------------

const modelText = (cfg: Config, model: string | undefined): string =>
  model === undefined ? '-' : resolveModel(cfg, model)

function mainText(st: State): string {
  const r = mainRoute(st)
  if (!r) return 'main: session defaults'
  const model = modelText(st.cfg, r.route.model)
  return `main: ${r.source} ${r.phase} · model ${model} · effort ${
    r.route.effort ?? '-'}`
}

function phasesText(cfg: Config): string {
  const entries = Object.entries(cfg.phases).map(([name, r]) =>
    `${name}=${r.model ? resolveModel(cfg, r.model) : 'session'}/${
      r.effort ?? 'session'}`)
  return `phases: ${entries.join(' ')}`
}

function show(st: State): string {
  const c = st.cfg
  const flag = (b: boolean) => (b ? 'on' : 'off')
  return [
    mainText(st),
    `router: ${st.off ? 'off' : 'on'} · switch: ${flag(c.mainModelSwitch)} · ` +
      `verbose: ${flag(c.verbose)} · spinner: ${flag(c.spinner)}`,
    `live loops: ${st.loops.size}`,
    phasesText(c),
    `config: ${st.source}`,
  ].join('\n')
}

function statusLine(st: State): string {
  const r = mainRoute(st)
  const now = st.off ? 'off' : r ? `${r.source} ${r.phase}` : 'session defaults'
  return `route: ${now}${st.cfg.mainModelSwitch ? ' · switch on' : ''}`
}

const refresh = ($: Api, st: State): void => $.ui.status(statusLine(st))

function vlog($: Api, st: State, text: string): void {
  if (st.cfg.verbose) $.ui.log(text)
}

const unknownText = (cfg: Config, token: string): string =>
  `unknown token "${token}"; phases: ${Object.keys(cfg.phases).join(' ')}; ` +
  `levels: ${LEVELS.join(' ')}; models: ${Object.keys(cfg.models).join(' ')} ` +
  'or a full claude-* id'

// ---- /route command --------------------------------------------------

/** One token: `model=x`, `effort=y`, a bare alias, id or level. */
function applyToken(cfg: Config, route: Route, token: string): boolean {
  const eq = token.indexOf('=')
  const key = eq < 0 ? '' : token.slice(0, eq)
  const value = eq < 0 ? token : token.slice(eq + 1)
  if (key !== '' && key !== 'model' && key !== 'effort') return false
  if (key !== 'model' && isLevel(value)) route.effort = value
  else if (key !== 'effort' && isModelName(cfg.models, value)) {
    route.model = value
  } else return false
  return true
}

function parseRoute(cfg: Config, args: string): Routed | string {
  const words = args.trim().split(/\s+/)
  const only = words.length === 1 ? words[0] : undefined
  const named = only === undefined ? undefined : phaseRoute(cfg, only)
  if (only !== undefined && named) {
    return { phase: only, route: { ...named }, source: 'user' }
  }
  const route: Route = {}
  for (const word of words) {
    if (!applyToken(cfg, route, word)) return unknownText(cfg, word)
  }
  return { phase: 'custom', route, source: 'user' }
}

function toggle(st: State, what: string, arg: string | undefined): string {
  if (arg !== 'on' && arg !== 'off') return `usage: /route ${what} on|off`
  if (what === 'switch') st.cfg.mainModelSwitch = arg === 'on'
  else st.cfg.verbose = arg === 'on'
  return show(st)
}

function setUserRoute($: Api, st: State, args: string): string {
  const parsed = parseRoute(st.cfg, args)
  if (typeof parsed === 'string') return parsed
  st.userMain = parsed
  refresh($, st)
  return show(st)
}

/** (Re)loads the config into the state and re-registers the route tool. */
async function reloadConfig($: Api, st: State): Promise<void> {
  const loaded = await loadConfig($, text => $.ui.log(text))
  st.cfg = loaded.cfg
  st.rules = compileRules(loaded.cfg)
  st.source = loaded.source
  await registerTool($, st)
}

async function handleCommand($: Api, st: State, args: string): Promise<string> {
  const [head = '', ...rest] = args.trim().split(/\s+/)
  switch (head) {
    case '':
    case 'show':
      return show(st)
    case 'clear':
      clearRoutes(st)
      refresh($, st)
      return 'route cleared\n' + show(st)
    case 'on':
    case 'off':
      st.off = head === 'off'
      refresh($, st)
      return show(st)
    case 'reload':
      await reloadConfig($, st)
      refresh($, st)
      return 'config reloaded\n' + show(st)
    case 'switch':
    case 'verbose':
      return toggle(st, head, rest[0])
    default:
      return setUserRoute($, st, args)
  }
}

// ---- route tool ------------------------------------------------------

async function registerTool($: Api, st: State): Promise<void> {
  try {
    await $.tool.register({
      name: 'route',
      description:
        'Declare the phase of the work ahead so the next model requests ' +
        'run at the effort (and model) it deserves. Call it before a span ' +
        'of work changes nature (planning, orchestrating, mechanical ' +
        'work). It acts on the calling loop only; no model choice here. ' +
        `Phases: ${Object.keys(st.cfg.phases).join(', ')}.`,
      inputSchema: {
        type: 'object',
        properties: {
          phase: { type: 'string', enum: Object.keys(st.cfg.phases) },
          effort: { type: 'string', enum: [...LEVELS] },
          clear: { type: 'boolean', description: 'drop this loop\'s route' },
        },
      },
    })
  } catch (err) {
    $.ui.log(`model-router: route tool not registered: ${String(err)}`)
  }
}

async function registerCommand($: Api): Promise<void> {
  try {
    await $.command.register({
      name: 'route',
      description: 'model-router: show or set the model and effort route',
      argumentHint:
        '[show|clear|off|on|reload|<phase>|model=<alias|id> effort=<level>' +
        '|switch on|off|verbose on|off]',
      immediate: true,
    })
  } catch (err) {
    $.ui.log(`model-router: /route not registered: ${String(err)}`)
  }
}

function pickRoute(cfg: Config, phase: unknown, effort: unknown) {
  const phases = Object.keys(cfg.phases).join(', ')
  const named = typeof phase === 'string' ? phaseRoute(cfg, phase) : undefined
  if (phase !== undefined && !named) {
    return `unknown phase "${String(phase)}"; phases: ${phases}`
  }
  if (effort !== undefined && !isLevel(effort)) {
    return `unknown effort "${String(effort)}"; levels: ${LEVELS.join(', ')}`
  }
  if (phase === undefined && effort === undefined) {
    return `give a phase (${phases}), an effort, or clear`
  }
  const route: Route = { ...named, ...(isLevel(effort) ? { effort } : {}) }
  const name = typeof phase === 'string' ? phase : `effort-${String(effort)}`
  return { phase: name, route }
}

function applyRoute(st: State, agentId: string | undefined, p: Picked): void {
  if (agentId === undefined) {
    st.turnMain = { phase: p.phase, route: p.route, source: 'model' }
  } else {
    writeLoop(loopOf(st, agentId), p.route)
  }
}

function clearLoop(st: State, agentId: string | undefined): string {
  if (agentId === undefined) {
    st.turnMain = null
    return 'route cleared for main'
  }
  const loop = st.loops.get(agentId)
  if (loop) writeLoop(loop, {})
  return 'route cleared for this agent'
}

/** Truthful answer: states what the calling loop will actually do. */
function routedText(st: State, agentId: string | undefined, p: Picked): string {
  if (agentId === undefined && st.userMain) {
    return `recorded ${p.phase} for this turn, but a sticky /route ` +
      `${st.userMain.phase} is in force; it wins until /route clear`
  }
  const loop = agentId === undefined ? undefined : st.loops.get(agentId)
  const effort = loop?.explicitEffort ? undefined : p.route.effort
  const model = agentId === undefined && !st.cfg.mainModelSwitch
    ? undefined
    : loop?.explicitModel ? undefined : p.route.model
  const modelNote = p.route.model && model === undefined ? ' (switch off)' : ''
  return `routed ${agentId === undefined ? 'main' : 'this agent'} to ` +
    `${p.phase}: effort ${effort ?? 'unchanged'}, model ` +
    `${model === undefined ? 'unchanged' : resolveModel(st.cfg, model)}` +
    modelNote
}

function handleRouteTool(st: State, e: RouteInput) {
  if (st.off) {
    return {
      result: 'model-router is off (/route on to resume); nothing routed',
    }
  }
  if (e.clear === true) return { result: clearLoop(st, e.agentId) }
  const picked = pickRoute(st.cfg, e.phase, e.effort)
  if (typeof picked === 'string') return { deny: picked }
  applyRoute(st, e.agentId, picked)
  return { result: routedText(st, e.agentId, picked) }
}

// ---- skills ----------------------------------------------------------

const skillResult = (skill: string, line: string) => ({
  result: { success: true, commandName: skill, status: 'inline' as const },
  context: [line],
})

/** Answers Skill(effort-<l>) in place: one writer, the skill never loads. */
function effortBridge(st: State, agentId: string | undefined, skill: string,
  level: Level) {
  if (agentId === undefined) {
    const route = { ...st.turnMain?.route, effort: level }
    st.turnMain = { phase: skill, route, source: 'skill' }
    return skillResult(skill, st.userMain
      ? `model-router: ${skill} recorded, but a sticky /route ` +
        `${st.userMain.phase} is in force and wins until /route clear.`
      : `model-router: effort → ${level} for this loop from the next ` +
        `request on; the ${skill} skill text was not loaded.`)
  }
  const loop = loopOf(st, agentId)
  if (loop.explicitEffort) {
    return skillResult(skill, 'model-router: this agent was dispatched with ' +
      'an explicit effort; the shift does not apply.')
  }
  loop.effort = level
  return skillResult(skill, `model-router: effort → ${level} for this ` +
    `loop from the next request on; the ${skill} skill text was not loaded.`)
}

/** A non-effort skill load: resets the loop's route, applies its table row. */
function onSkillLoad(st: State, skill: string, agentId: string | undefined) {
  const table = hasKey(st.cfg.skills, skill) ? st.cfg.skills[skill] : undefined
  const route = table === undefined ? undefined : phaseRoute(st.cfg, table)
  if (agentId === undefined) {
    if (st.turnMain && st.turnMain.source !== 'prompt') st.turnMain = null
    if (table !== undefined && route) {
      st.turnMain = { phase: table, route, source: 'skill' }
    }
    return
  }
  const loop = route ? loopOf(st, agentId) : st.loops.get(agentId)
  if (loop) writeLoop(loop, { effort: route?.effort })
}

/** A user-typed /effort-<l>: prepends one line, args ride in the text. */
function slashEffort(st: State, skill: string, text: string) {
  const level = EFFORT_SKILL.exec(skill)?.[1]
  if (!isLevel(level)) return undefined
  st.turnMain = { phase: skill, route: { effort: level }, source: 'slash' }
  const line = st.userMain
    ? `Effort ${level} recorded; the sticky /route ${st.userMain.phase} ` +
      'wins until /route clear.'
    : `Effort shifted to ${level} by model-router for this turn.`
  return { text: line + '\n' + text }
}

// ---- agents ----------------------------------------------------------

type SpawnIn = {
  tool_use_id: string
  subagentType: string
  provider: { plugin: string }
  model?: string
  fork: boolean
  workflow?: unknown
}

/**
 * The table row of a built-in agent. Known limit: provider.plugin ===
 * 'engine' is the best built-in test at spawn; a user agent named Explore
 * in a foreign project also matches (wave 1: sonnet/medium on it).
 */
function spawnRoute(cfg: Config, e: SpawnIn, frozen: boolean) {
  if (frozen || e.provider.plugin !== 'engine') return undefined
  if (!hasKey(cfg.agents, e.subagentType)) return undefined
  const phase = cfg.agents[e.subagentType]
  return phase === undefined ? undefined : phaseRoute(cfg, phase)
}

function trackLoop(st: State, e: SpawnIn, started: {
  model: string
  agentId?: string
}, route: Route | undefined, frozen: boolean): void {
  const given = st.explicitEffort.get(e.tool_use_id)
  st.explicitEffort.delete(e.tool_use_id)
  if (started.agentId === undefined) return
  st.loops.set(started.agentId, {
    spawnModel: started.model,
    frozen,
    explicitModel: e.model !== undefined,
    explicitEffort: given !== undefined,
    effort: given ? undefined : route?.effort,
  })
}

// ---- turn steps ------------------------------------------------------

function agentPlan(st: State, e: StepIn): Plan {
  const loop = e.agentId === undefined ? undefined : st.loops.get(e.agentId)
  const wanted = loop?.model
  const reroute = loop && wanted !== undefined && !loop.frozen &&
    e.model === loop.spawnModel
  return {
    model: reroute ? resolveModel(st.cfg, wanted) : e.model,
    effort: loop?.effort ?? e.effort,
  }
}

/** True when the context still fits the target model's known window. */
async function windowOk($: Api, st: State, id: string): Promise<boolean> {
  const limit = hasKey(st.cfg.windows, id) ? st.cfg.windows[id] : undefined
  if (limit === undefined) return true
  let tokens: number | undefined
  try {
    tokens = (await $.session.usage()).context.tokens
  } catch {
    tokens = undefined
  }
  if (typeof tokens === 'number' && tokens < limit) return true
  if (!st.windowWarned) {
    st.windowWarned = true
    $.ui.log(`model-router: no switch to ${id}: context not known to fit`)
  }
  return false
}

async function mainPlan($: Api, st: State, e: StepIn): Promise<Plan> {
  const set = mainRoute(st)
  const effort = set?.route.effort ?? e.effort
  const wanted = set?.route.model
  if (wanted === undefined || !st.cfg.mainModelSwitch) {
    return { model: e.model, effort }
  }
  const id = resolveModel(st.cfg, wanted)
  return { model: (await windowOk($, st, id)) ? id : e.model, effort }
}

async function planStep($: Api, st: State, e: StepIn): Promise<Plan> {
  const plan = e.agentId === undefined
    ? await mainPlan($, st, e)
    : agentPlan(st, e)
  // Haiku takes no effort: omit it rather than send a hook-set value.
  return plan.model.startsWith(HAIKU) ? { ...plan, effort: undefined } : plan
}

function withPlan(e: StepIn, plan: Plan): StepIn {
  const { effort: _replaced, ...rest } = e
  const base = { ...rest, model: plan.model }
  return plan.effort === undefined ? base : { ...base, effort: plan.effort }
}

function stepLog(e: StepIn, plan: Plan): string {
  const id = e.agentId
  const loop = id === undefined ? 'main' : `agent ${id.slice(0, 8)}`
  return `step ${e.index} ${loop}: ${e.model}/${String(e.effort)} → ` +
    `${plan.model}/${String(plan.effort)}`
}

function noteMain($: Api, st: State, plan: Plan): void {
  st.lastMain = `${plan.model.replace(/^claude-/, '')}/${plan.effort ?? '-'}`
  refresh($, st)
}

function endMainTurn($: Api, st: State): void {
  st.turnMain = st.pendingPrompt
  st.pendingPrompt = null
  st.explicitEffort.clear()
  st.lastMain = ''
  st.windowWarned = false
  refresh($, st)
}

// ---- registration ----------------------------------------------------

function registerSession(on: On, st: State): void {
  on('session.start', async ($, e, next) => {
    await reloadConfig($, st)
    await registerCommand($)
    refresh($, st)
    return next(e)
  }).catch(($, e, next) => next(e))
  on('session.end', async ($, e, next) => {
    Object.assign(st, newState(st.cfg, st.source))
    return next(e)
  }).catch(($, e, next) => next(e))
  on('command.run', { command: 'route' }, async ($, e) => ({
    text: await handleCommand($, st, e.args),
  })).catch(($, e, next) => ({ text: `route failed (${next.error.kind})` }))
}

function registerRouteTool(on: On, st: State): void {
  on('tool.call', { tool: TOOL }, async ($, e) => {
    const out = handleRouteTool(st, e)
    refresh($, st)
    vlog($, st, `route ${e.agentId ?? 'main'}: ${JSON.stringify(out)}`)
    return out
  }).catch(($, e, next) => ({
    result: `route failed (${next.error.kind}); nothing routed`,
  }))
}

function registerSkills(on: On, st: State): void {
  on('tool.call', { tool: 'Skill' }, async ($, e, next) => {
    if (st.off) return next(e)
    const level = EFFORT_SKILL.exec(e.skill)?.[1]
    if (isLevel(level)) return effortBridge(st, e.agentId, e.skill, level)
    st.skillCalls += 1
    try {
      onSkillLoad(st, e.skill, e.agentId)
      return await next(e)
    } finally {
      st.skillCalls -= 1
    }
  }).catch(($, e, next) => next(e))
  on('skill.prompt', async ($, e, next) => {
    if (st.off || st.skillCalls > 0) return next(e)
    return slashEffort(st, e.skill, e.text) ?? next(e)
  }).catch(($, e, next) => next(e))
}

function registerAgents(on: On, st: State): void {
  on('tool.call', { tool: 'Agent' }, async ($, e, next) => {
    if (!st.off && isLevel(e.effort) && typeof e.tool_use_id === 'string') {
      st.explicitEffort.set(e.tool_use_id, e.effort)
    }
    return next(e)
  }).catch(($, e, next) => next(e))
  on('agent.spawn', async ($, e, next) => {
    if (st.off) return next(e)
    const frozen = e.fork || e.workflow !== undefined
    const route = spawnRoute(st.cfg, e, frozen)
    // An explicit model param on the Agent call always wins.
    const wanted = e.model === undefined ? route?.model : undefined
    const started = await next(wanted === undefined
      ? e
      : { ...e, model: resolveModel(st.cfg, wanted) })
    if (started.deny !== undefined) return started
    trackLoop(st, e, started, route, frozen)
    vlog($, st, `spawn ${e.subagentType}: ${e.model ?? '-'} → ${started.model}`)
    return started
  }).catch(($, e, next) => next(e))
}

function registerTurns(on: On, st: State): void {
  on('turn.step', async function* ($, e, next) {
    if (st.off) return yield* next(e)
    const plan = await planStep($, st, e)
    const changed = plan.model !== e.model || plan.effort !== e.effort
    if (e.agentId === undefined) noteMain($, st, plan)
    vlog($, st, stepLog(e, plan))
    const result = yield* next(changed ? withPlan(e, plan) : e)
    vlog($, st, `step ${e.index} answered by ${result.usage?.model ?? '?'}`)
    return result
  }).catch(async function* ($, e, next) {
    return yield* next(e)
  })
  on('turn.complete', async ($, e, next) => {
    if (e.agentId !== undefined) st.loops.delete(e.agentId)
    else endMainTurn($, st)
    return next(e)
  }).catch(($, e, next) => next(e))
}

function registerPrompt(on: On, st: State): void {
  on('prompt.submit', async ($, e, next) => {
    if (st.off || e.origin.kind !== 'composer') return next(e)
    const rule = st.rules.find(r => r.re.test(e.text))
    const route = rule ? phaseRoute(st.cfg, rule.phase) : undefined
    if (rule && route) {
      const routed: Routed = { phase: rule.phase, route, source: 'prompt' }
      // Typed mid-turn and asked to wait: it belongs to the NEXT turn.
      if (e.turnId !== undefined && e.wait) st.pendingPrompt = routed
      else st.turnMain = routed
      refresh($, st)
    }
    return next(e)
  }).catch(($, e, next) => next(e))
  on('ui.render', { component: 'Spinner' }, async ($, e, next) => {
    if (st.off || !st.cfg.spinner || !st.lastMain) return next(e)
    const suffix = ` · ${st.lastMain}…`
    return next({ ...e, props: { ...e.props, suffix } })
  }).catch(($, e, next) => next(e))
}

export const register: Register = on => {
  const st = newState(mergeConfig(undefined, () => undefined), 'defaults')
  registerSession(on, st)
  registerRouteTool(on, st)
  registerSkills(on, st)
  registerAgents(on, st)
  registerTurns(on, st)
  registerPrompt(on, st)
}
