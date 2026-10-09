// model-router: routes each model request (main loop and sub-agents) to the
// model and effort its phase deserves. Phases name a TIER (an ordered list of
// aliases, the first available wins); a circuit breaker fed by the engine's
// own failure events marks a model down for a while. Phases, agents, skills
// and prompt rules come from DEFAULT_CONFIG, overridable by
// ~/.claude/model-router.json.
// One writer per concern: the Agent tool's own params are never rewritten,
// the spawn hook sets an agent's model once, turn.step sets efforts.
import type { EngineInterface, On, Register, TurnStepInput } from 'claude-code'

type Api = EngineInterface
type Level = 'low' | 'medium' | 'high' | 'xhigh' | 'max'
type Route = {
  tier?: string // a `tiers` key: the first AVAILABLE alias of its list
  model?: string // alias or full id: explicit, never skipped when down
  effort?: Level
}
type PromptMode = 'floor' | 'default'
type PromptRule = { pattern: string; phase: string; mode?: PromptMode }
type Config = {
  models: Record<string, string> // alias -> full id
  windows: Record<string, number> // full id -> context window (tokens)
  phases: Record<string, Route>
  agents: Record<string, string> // subagentType -> phase
  skills: Record<string, string> // skill name -> phase
  prompt: PromptRule[]
  tiers: Record<string, string[]> // tier -> alias preference, best first
  fallback: string[] // alias order, best first: the rank and the fallback chain
  cooldownMinutes: number // breaker hold at the first strike
  mainUpgrade: boolean // main may move UP to a phase's tier by itself
  upgradeMaxTokens: number // above this context an upgrade is skipped
  mainModelSwitch: boolean // gates DOWNGRADES only
  verbose: boolean
  spinner: boolean
  enabled: boolean // false: every hook passes through (per machine)
}
type Rule = { re: RegExp; phase: string; mode: PromptMode }
type Source = 'user' | 'model' | 'skill' | 'prompt' | 'run' | 'derived'
type Routed = { phase: string; route: Route; source: Source }
type Hold = { until: number; reason: string } // until: ms, Infinity = reload
type Pushed = { prev: Routed | null; spawnIds: Set<string> }
type Loop = {
  effort?: Level // an agent's model is fixed at spawn: effort is its only axis
  explicitEffort: boolean // Agent call gave an effort: axis frozen
}
type State = {
  cfg: Config
  rules: Rule[]
  source: string // 'defaults' or the override path
  userMain: Routed | null // /route by the user, sticky until /route clear
  turnMain: Routed | null // model route tool, skill table row, Skill(effort-*)
  // bridge, prompt default rule, derived orchestrate; dropped at turn end
  runMain: Routed | null // best-tier skill row: spans the turns of a run;
  // only a skill, /route clear|off or a user /model write or drop it
  turnFloor: Routed | null // user-explicit level for this turn (prompt rule):
  // a floor, main loop only
  pendingPrompt: Routed | null // typed mid-turn: the next turn's floor
  typedSlash: string | null // the rowed skill the user typed at prompt.submit
  pendingSlash: string | null // same, typed mid-turn: promoted at turn end
  promptAllowed: boolean // this turn's prompt came from a typing origin
  pendingAllowed: boolean // same, for the mid-turn prompt
  spawning: number // agent.spawn hooks in flight (preloads fire inside)
  offers: Map<string, string> // subagentType -> definition source
  loops: Map<string, Loop> // agentId -> that loop's routing
  explicitEffort: Map<string, Level> // Agent tool_use_id -> effort param
  skillCalls: number // Skill tool calls in flight
  off: boolean // /route off or config: every hook passes through
  offConfig: boolean // `off` comes from the config key `enabled`
  spinner: string // "model/effort" of the last main step of this turn
  lastPlan: Plan | null // the plan last sent on main: the breaker's target
  turnModel: string | undefined // sticky main model, set when the router moved
  sessionModel: string // the main loop's model as /model shows it, '' unknown
  down: Map<string, Hold> // canonical id -> unavailable until (breaker)
  strikes: Map<string, number> // canonical id -> episodes, drives the backoff
  agentModels: Map<string, string> // agentId -> exact id sent at spawn
  pushed: Pushed | null // derived orchestrate in force (background dispatch)
  logged: Set<string> // session-once log lines
  turnLogged: Set<string> // turn-once log lines
  warned: Set<string> // hooks whose fail-open was already logged
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
type Effort = StepIn['effort']
type EffortBy = 'floor' | 'sticky' | 'turn' | 'engine'
type Decision = { effort: Effort; by: EffortBy }

const LEVELS: readonly Level[] = ['low', 'medium', 'high', 'xhigh', 'max']
const MODEL_ID = /^claude-[a-z0-9.-]+$/
const TOOL = 'mcp__model-router__route'
const EFFORT_SKILL = /^effort-(low|medium|high|xhigh|max)$/
const BEST = 'best' // the tier whose skill rows hold for a whole run
// Origins that are a person typing: only these arm a typed slash.
const TYPED_ORIGINS: ReadonlySet<string> = new Set([
  'composer', 'sdk', 'bridge',
])
// Definition sources of a foreign repo's own agent: its row is skipped.
const PROJECT_SOURCES: ReadonlySet<string> = new Set([
  'projectSettings', 'localSettings',
])
// PostModelSwitch sources a person chose (auto and resume are not).
const USER_SWITCH: ReadonlySet<string> = new Set([
  'command', 'picker', 'sdk',
])
const OVERRIDE = '.claude/model-router.json'
const HAIKU = 'claude-haiku'
const MAX_PATTERN = 200 // chars of a prompt-rule pattern
const MAX_PROMPT_SCAN = 4096 // chars of a prompt a rule is run against
const MAX_CONFIG_BYTES = 65536 // override file size
const MAX_AGENT_MODELS = 256 // agent -> model entries kept (oldest dropped)
const PREFIX = 'claude-'
const ONE_M = /\[1m\]$/ // the long-context variant of a model id
// Hold = cooldownMinutes x step: 15 -> 30 -> 60 -> 120 -> 300 by default.
const BACKOFF_STEPS: readonly number[] = [1, 2, 4, 8, 20]
// StopFailure kinds that mean "this model cannot serve now". The others
// (context limit, network, auth...) are not availability.
const UNAVAILABLE: ReadonlySet<string> = new Set([
  'rate_limit', 'overloaded', 'billing_error', 'model_not_found',
])
const PHASE_KEY = /^[a-z][a-z0-9_-]{0,31}$/

const DEFAULT_CONFIG: Config = {
  models: {
    haiku: 'claude-haiku-4-5-20251001',
    sonnet: 'claude-sonnet-5-5',
    opus: 'claude-opus-5-5',
    fable: 'claude-fable-5-1',
  },
  windows: { 'claude-haiku-4-5-20251001': 200000 },
  // A tier is an ordered alias list: the first one not down is used.
  tiers: {
    best: ['fable', 'opus', 'sonnet'],
    big: ['opus', 'fable', 'sonnet'],
    work: ['sonnet', 'opus'],
    cheap: ['haiku', 'sonnet'],
  },
  fallback: ['fable', 'opus', 'sonnet', 'haiku'], // rank = index, best first
  cooldownMinutes: 15,
  mainUpgrade: true,
  upgradeMaxTokens: 200000, // an upgrade re-reads the whole context cold
  phases: {
    plan: { tier: 'best', effort: 'xhigh' },
    reflect: { tier: 'best', effort: 'high' },
    orchestrate: { tier: 'best', effort: 'medium' },
    escalate: { tier: 'best', effort: 'max' },
    judge: { tier: 'big', effort: 'xhigh' },
    implement: { tier: 'work', effort: 'medium' },
    write: { tier: 'work', effort: 'high' },
    verify: { tier: 'work', effort: 'xhigh' },
    explore: { tier: 'work', effort: 'medium' },
    apply: { tier: 'work', effort: 'low' },
    mechanical: { tier: 'cheap', effort: 'low' },
  },
  // phase = role; one row per routed repo skill/agent (wave 2); a
  // project-level agent of the same name shadows its row (see spawnRoute).
  agents: {
    // explore
    Explore: 'explore',
    // judge
    Plan: 'judge', 'plan-challenger': 'judge', 'plugin-advisor': 'judge',
    'seo-analyzer': 'judge', 'geo-analyzer': 'judge', analyzer: 'judge',
    // implement
    feater: 'implement', bugfixer: 'implement', 'code-cleaner': 'implement',
    scaffolder: 'implement', onboarder: 'implement',
    // write
    'commit-changer': 'write', 'doc-syncer': 'write',
    'handover-doc-writer': 'write', refactorer: 'write',
    // apply
    hotfixer: 'apply', 'release-executor': 'apply', 'plugin-probe': 'apply',
    'validator-analyzer': 'apply',
    // verify
    verifier: 'verify', 'security-auditor': 'verify',
    // mechanical
    'status-reporter': 'mechanical',
  },
  skills: {
    // plan
    'ship-feature': 'plan', 'init-project': 'plan', onboard: 'plan',
    tour: 'plan', 'audit-delta': 'plan', analyze: 'plan',
    'code-clean': 'plan', 'client-handover': 'plan', brainstorming: 'plan',
    'writing-plans': 'plan', 'requesting-code-review': 'plan',
    '21st-ui-review': 'plan',
    // reflect
    feat: 'reflect', hotfix: 'reflect', bugfix: 'reflect',
    refactor: 'reflect', 'web-validate': 'reflect', harden: 'reflect',
    seo: 'reflect', geo: 'reflect', 'site-motion': 'reflect',
    'frontend-design': 'reflect', 'emil-design-eng': 'reflect',
    'design-motion-principles': 'reflect', '21st-ui-build': 'reflect',
    'scroll-world-storytelling': 'reflect',
    'build-threejs-scroll-worlds': 'reflect',
    'scroll-scrubbed-visual-sequence': 'reflect',
    'scroll-scrubbed-word-reveal': 'reflect',
    'scroll-progress-timeline': 'reflect',
    'subagent-driven-development': 'reflect', 'writing-skills': 'reflect',
    'deprecation-and-migration': 'reflect', '21st-ai': 'reflect',
    '21st-ui-explore': 'reflect',
    // implement
    gitflow: 'implement', 'prune-memory': 'implement',
    'pdf-translate': 'implement', 'ci-cd-and-automation': 'implement',
    'observability-and-instrumentation': 'implement',
    'test-driven-development': 'implement',
    // apply
    'commit-change': 'apply', 'release-candidate': 'apply', doc: 'apply',
    capitalize: 'apply', close: 'apply', reconcile: 'apply', deploy: 'apply',
    // mechanical
    status: 'mechanical', profile: 'mechanical', 'plugin-check': 'mechanical',
    'skills-perso': 'mechanical', 'using-git-worktrees': 'mechanical',
    '21st-cli-use': 'mechanical', '21st-registry': 'mechanical',
    '21st-design-sync': 'mechanical',
  },
  // `floor` rules set the turn's minimum effort; `default` rules set the
  // turn's route, which a route call or a skill overrides. Neither lowers.
  prompt: [
    { pattern: '\\bultrathink\\b', phase: 'escalate', mode: 'floor' },
    {
      pattern: '(?<![\\p{L}\\p{N}-])(plan|planifie|planning|brainstorm|' +
        'architecture|con[c\u00e7]ois|design)(?![\\p{L}\\p{N}-])',
      phase: 'plan',
      mode: 'default',
    },
    {
      pattern: '(?<![\\p{L}\\p{N}-])(pourquoi|why|explique|explain|analyse|' +
        'analyze|comprendre|understand|review|audit)(?![\\p{L}\\p{N}-])',
      phase: 'reflect',
      mode: 'default',
    },
  ],
  mainModelSwitch: false,
  verbose: false,
  spinner: true,
  enabled: true,
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
  if (!isRecord(user)) {
    if (user !== undefined) {
      log(`model-router: config ${name} ignored: not an object`)
    }
    return out
  }
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

/** A phase names a tier OR a model, never both; a tier must exist. */
function acceptPhase(
  models: Record<string, string>,
  tiers: Record<string, string[]>,
) {
  return (key: string, v: unknown): Route | undefined => {
    if (!PHASE_KEY.test(key) || !isRecord(v)) return undefined
    if (v.tier !== undefined && v.model !== undefined) return undefined
    const route: Route = {}
    if (v.effort !== undefined) {
      if (!isLevel(v.effort)) return undefined
      route.effort = v.effort
    }
    if (v.model !== undefined) {
      if (!isModelName(models, v.model)) return undefined
      route.model = v.model
    }
    if (v.tier !== undefined) {
      if (typeof v.tier !== 'string' || !hasKey(tiers, v.tier)) return undefined
      route.tier = v.tier
    }
    return route.effort || route.model || route.tier ? route : undefined
  }
}

/** A tier: a non-empty alias list; unknown aliases dropped, duplicates too. */
function acceptTier(models: Record<string, string>, log: Log) {
  return (key: string, v: unknown): string[] | undefined => {
    // a tier named like an alias would make a bare name ambiguous
    if (!PHASE_KEY.test(key) || hasKey(models, key)) return undefined
    if (!Array.isArray(v)) return undefined
    const items = v as unknown[]
    const kept = items.filter(
      (a): a is string => typeof a === 'string' && hasKey(models, a))
    if (kept.length < items.length) {
      log(`model-router: config tiers.${key} entries dropped`)
    }
    return kept.length > 0 ? [...new Set(kept)] : undefined
  }
}

/** Appends the `models` aliases a user's chain omits, so all are ranked. */
function withEveryAlias(
  chain: string[],
  models: Record<string, string>,
  log: Log,
): string[] {
  const missing = Object.keys(models).filter(a => !chain.includes(a))
  if (missing.length > 0) {
    log(`model-router: config fallback lacks ${missing.join(', ')}; appended`)
  }
  return [...chain, ...missing]
}

/** The fallback chain: deduplicated aliases of `models`, else the default. */
function pickFallback(
  user: unknown,
  base: string[],
  models: Record<string, string>,
  log: Log,
): string[] {
  if (user === undefined) return base
  const items = Array.isArray(user) ? (user as unknown[]) : []
  const kept = items.filter(
    (a): a is string => typeof a === 'string' && hasKey(models, a))
  if (kept.length > 0) return withEveryAlias([...new Set(kept)], models, log)
  log('model-router: config fallback ignored: need a list of model aliases')
  return base
}

function pickPositive(v: unknown, fallback: number, name: string, log: Log) {
  if (v === undefined) return fallback
  if (typeof v === 'number' && Number.isInteger(v) && v > 0) return v
  log(`model-router: config ${name} ignored: not a positive integer`)
  return fallback
}

function acceptPhaseRef(phases: Record<string, Route>) {
  return (_key: string, v: unknown): string | undefined =>
    typeof v === 'string' && PHASE_KEY.test(v) && hasKey(phases, v)
      ? v
      : undefined
}

/** Unicode-aware first; a pattern only valid without `u` still works. */
function buildRegex(pattern: string): RegExp | undefined {
  for (const flags of ['iu', 'i']) {
    try {
      return new RegExp(pattern, flags)
    } catch {
      // retry with the next flag set
    }
  }
  return undefined
}

/** Absent `mode` = floor: override files written before modes keep meaning. */
function acceptRule(
  phases: Record<string, Route>,
  v: unknown,
): PromptRule | undefined {
  if (!isRecord(v)) return undefined
  const { pattern, phase, mode } = v
  if (typeof pattern !== 'string' || typeof phase !== 'string') return undefined
  if (mode !== undefined && mode !== 'floor' && mode !== 'default') {
    return undefined
  }
  if (pattern.length > MAX_PATTERN) return undefined
  return hasKey(phases, phase) && buildRegex(pattern)
    ? { pattern, phase, mode: mode ?? 'floor' }
    : undefined
}

/** A user prompt array replaces the default rules; bad rules are dropped. */
function mergePrompt(
  base: PromptRule[],
  user: unknown,
  phases: Record<string, Route>,
  log: Log,
): PromptRule[] {
  if (!Array.isArray(user)) {
    if (user !== undefined) {
      log('model-router: config prompt ignored: not a list')
    }
    return base
  }
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

/** The kill switch: a non-boolean value is dropped, and said so. */
function pickEnabled(v: unknown, fallback: boolean, log: Log): boolean {
  if (v !== undefined && typeof v !== 'boolean') {
    log('model-router: config "enabled" is not a boolean; ignored')
  }
  return pickBool(v, fallback)
}

type Routing = Pick<Config, 'tiers' | 'fallback' | 'cooldownMinutes' |
  'mainUpgrade' | 'upgradeMaxTokens'>

/** Tiers, fallback chain and breaker knobs, validated against `models`. */
function mergeRouting(
  base: Config,
  user: Record<string, unknown>,
  models: Record<string, string>,
  log: Log,
): Routing {
  const tiers = mergeTable(
    base.tiers, user.tiers, 'tiers', acceptTier(models, log), log)
  const fallback = pickFallback(user.fallback, base.fallback, models, log)
  if (tiers.best?.[0] !== fallback[0]) {
    log('model-router: tiers.best does not lead the fallback chain; rank ' +
      'comes from the fallback list alone')
  }
  return {
    tiers,
    fallback,
    cooldownMinutes: pickPositive(
      user.cooldownMinutes, base.cooldownMinutes, 'cooldownMinutes', log),
    mainUpgrade: pickBool(user.mainUpgrade, base.mainUpgrade),
    upgradeMaxTokens: pickPositive(
      user.upgradeMaxTokens, base.upgradeMaxTokens, 'upgradeMaxTokens', log),
  }
}

/** A row table: `name: null` in the override drops a default row. */
function mergeRows(
  base: Record<string, string>,
  user: unknown,
  name: string,
  ref: (key: string, value: unknown) => string | undefined,
  log: Log,
): Record<string, string> {
  const entries = isRecord(user) ? Object.entries(user) : []
  const kept = isRecord(user)
    ? Object.fromEntries(entries.filter(([, v]) => v !== null))
    : user
  const rows = mergeTable(base, kept, name, ref, log)
  for (const [key, value] of entries) {
    if (value === null && key !== '__proto__') delete rows[key]
  }
  return rows
}

/** Defaults overlaid with the user's entries, each validated first. */
function mergeConfig(user: unknown, log: Log): Config {
  const base = structuredClone(DEFAULT_CONFIG)
  if (!isRecord(user)) {
    if (user !== undefined) log('model-router: config ignored: not an object')
    return base
  }
  const models = mergeTable(
    base.models, user.models, 'models', acceptModel, log)
  const routing = mergeRouting(base, user, models, log)
  const phases = mergeTable(base.phases, user.phases, 'phases',
    acceptPhase(models, routing.tiers), log)
  const ref = acceptPhaseRef(phases)
  return {
    models,
    ...routing,
    windows: mergeTable(
      base.windows, user.windows, 'windows', acceptWindow, log),
    phases,
    agents: mergeRows(base.agents, user.agents, 'agents', ref, log),
    skills: mergeRows(base.skills, user.skills, 'skills', ref, log),
    prompt: mergePrompt(base.prompt, user.prompt, phases, log),
    mainModelSwitch: pickBool(user.mainModelSwitch, base.mainModelSwitch),
    verbose: pickBool(user.verbose, base.verbose),
    spinner: pickBool(user.spinner, base.spinner),
    enabled: pickEnabled(user.enabled, base.enabled, log),
  }
}

/** The file's text, or undefined (logged) when it exceeds the cap. */
async function readCapped(
  $: Api,
  path: string,
  log: Log,
): Promise<string | undefined> {
  const tooBig =
    `model-router: ${OVERRIDE} over ${MAX_CONFIG_BYTES} bytes`
  if ((await $.fs.stat(path)).size > MAX_CONFIG_BYTES) {
    log(tooBig)
    return undefined
  }
  const text = await $.fs.read(path)
  if (text.length <= MAX_CONFIG_BYTES) return text
  log(tooBig)
  return undefined
}

type Override = { path: string; data: unknown } | 'absent' | 'failed'

/** 'absent': no file (defaults apply). 'failed': present but unusable. */
async function readOverride($: Api, log: Log): Promise<Override> {
  try {
    const home = await $.env.get('HOME')
    if (!home) return 'absent'
    const path = `${home}/${OVERRIDE}`
    if (!(await $.fs.exists(path))) return 'absent'
    const text = await readCapped($, path, log)
    if (text === undefined) return 'failed'
    const data: unknown = JSON.parse(text)
    if (isRecord(data)) return { path, data }
    log(`model-router: ${OVERRIDE} is not an object`)
    return 'failed'
  } catch (err) {
    log(`model-router: ${OVERRIDE} unreadable (${String(err)})`)
    return 'failed'
  }
}

/** Never throws; undefined when the override exists but cannot be used. */
async function loadConfig(
  $: Api,
  log: Log,
): Promise<{ cfg: Config; source: string } | undefined> {
  const found = await readOverride($, log)
  if (found === 'failed') return undefined
  if (found === 'absent') {
    return { cfg: mergeConfig(undefined, log), source: 'defaults' }
  }
  return { cfg: mergeConfig(found.data, log), source: found.path }
}

/** Compiles the prompt rules; one that fails to compile is dropped, logged. */
function compileRules(cfg: Config, log: Log): Rule[] {
  const rules: Rule[] = []
  for (const r of cfg.prompt) {
    const re = buildRegex(r.pattern)
    if (re) rules.push({ re, phase: r.phase, mode: r.mode ?? 'floor' })
    else log(`model-router: prompt rule for ${r.phase} does not compile`)
  }
  return rules
}

// ---- state -----------------------------------------------------------

function newState(cfg: Config, source: string): State {
  return {
    cfg,
    rules: compileRules(cfg, () => undefined),
    source,
    userMain: null,
    turnMain: null,
    runMain: null,
    turnFloor: null,
    pendingPrompt: null,
    typedSlash: null,
    pendingSlash: null,
    promptAllowed: false,
    pendingAllowed: false,
    spawning: 0,
    offers: new Map(),
    loops: new Map(),
    explicitEffort: new Map(),
    skillCalls: 0,
    off: false,
    offConfig: false,
    spinner: '',
    lastPlan: null,
    turnModel: undefined,
    sessionModel: '',
    down: new Map(),
    strikes: new Map(),
    agentModels: new Map(),
    pushed: null,
    logged: new Set(),
    turnLogged: new Set(),
    warned: new Set(),
  }
}

/**
 * /clear rebuilds the state but keeps what is account- or process-wide:
 * the breaker (a model's quota outlives the conversation), the model and
 * the agent definitions' sources (the listing is not offered again).
 */
function resetSession(st: State): void {
  const kept = {
    down: st.down,
    strikes: st.strikes,
    agentModels: st.agentModels,
    sessionModel: st.sessionModel,
    offers: st.offers,
  }
  Object.assign(st, newState(st.cfg, st.source), kept)
}

/** Logs a hook's fail-open once per session; never throws itself. */
function warnOnce(st: State, $: Api, hook: string, kind: string): void {
  if (st.warned.has(hook)) return
  st.warned.add(hook)
  try {
    $.ui.log(`model-router: ${hook} failed (${kind}): ` +
      'routing skipped for this event')
  } catch {
    // a failing log must not break the fail-open itself
  }
}

/** Runs post-`next` bookkeeping so its failure can never re-run `next`. */
function safely(st: State, $: Api, hook: string, work: () => void): void {
  try {
    work()
  } catch {
    warnOnce(st, $, hook, 'bookkeeping')
  }
}

// ---- models: ids, tiers, breaker, the main decision -------------------

/** The table id an alias, a `[1m]` variant or a dated id stands for. */
function canonical(cfg: Config, id: string): string {
  const bare = id.replace(ONE_M, '')
  if (hasKey(cfg.models, bare)) return cfg.models[bare] ?? bare
  if (!bare.startsWith(PREFIX) || bare.length <= PREFIX.length) return bare
  const hit = Object.values(cfg.models).find(
    known => bare.startsWith(known))
  return hit ?? bare
}

/** The table alias of a canonical id; undefined for an id the table lacks. */
const aliasOf = (cfg: Config, id: string): string | undefined =>
  Object.keys(cfg.models).find(alias => cfg.models[alias] === id)

/** Position in the fallback chain, best first; undefined when unranked. */
function modelRank(cfg: Config, id: string): number | undefined {
  const alias = aliasOf(cfg, id)
  const at = alias === undefined ? -1 : cfg.fallback.indexOf(alias)
  return at < 0 ? undefined : at
}

const routeName = (r: Route | null | undefined): string | undefined =>
  r?.tier ?? r?.model

/** First alias of the list whose model is not down. */
function availableIn(st: State, aliases: readonly string[]) {
  for (const alias of aliases) {
    const id = st.cfg.models[alias]
    if (id !== undefined && !st.down.has(id)) return id
  }
  return undefined
}

/** The first model not down in the fallback chain, after `after`'s place. */
function nextAvailable(st: State, after: string | undefined) {
  const { fallback, models } = st.cfg
  const at = fallback.findIndex(alias => models[alias] === after)
  return availableIn(st, fallback.slice(at + 1))
}

/**
 * A tier, alias or id as an id to run on. A tier skips down aliases, then
 * walks the global chain (from `after`, default the tier's last alias); an
 * alias or id is explicit and never skipped.
 */
function resolveName(st: State, name: string, after?: string) {
  const tier = hasKey(st.cfg.tiers, name) ? st.cfg.tiers[name] : undefined
  if (tier === undefined) return canonical(st.cfg, name)
  const last = tier[tier.length - 1]
  const from = after ?? (last === undefined ? undefined : st.cfg.models[last])
  return availableIn(st, tier) ?? nextAvailable(st, from)
}

function resolveRoute(st: State, route: Route | undefined) {
  const name = routeName(route)
  return name === undefined ? undefined : resolveName(st, name)
}

/** Drops lapsed holds; the clock is read only while something is held. */
async function prune($: Api, st: State): Promise<number> {
  if (st.down.size === 0) return 0
  const now = await $.clock.now()
  for (const [id, hold] of st.down) {
    if (hold.until <= now) st.down.delete(id)
  }
  return now
}

const holdWord = (until: number, now: number): string =>
  until === Infinity
    ? 'until reload'
    : `for ${Math.max(1, Math.ceil((until - now) / 60000))} min`

function holdMinutes(cfg: Config, strikes: number, reason: string): number {
  if (reason === 'model_not_found') return Infinity
  const step = BACKOFF_STEPS[Math.min(strikes, BACKOFF_STEPS.length) - 1] ?? 1
  return cfg.cooldownMinutes * step
}

/**
 * Marks a table model down for an episode. A mark on a model already down
 * adds no strike and no log, except `model_not_found`, which lengthens a
 * timed hold to "until reload". Inert while the router is off.
 */
function markDown(
  $: Api,
  st: State,
  id: string,
  reason: string,
  now: number,
): void {
  if (st.off || aliasOf(st.cfg, id) === undefined) return
  const held = st.down.get(id)
  const lengthen = reason === 'model_not_found' && held?.until !== Infinity
  if (held && !lengthen) return
  const strikes = (st.strikes.get(id) ?? 0) + (held ? 0 : 1)
  st.strikes.set(id, strikes)
  const until = now + holdMinutes(st.cfg, strikes, reason) * 60000
  st.down.set(id, { until, reason })
  $.ui.log(`model-router: ${id} unavailable (${reason}) ${
    holdWord(until, now)}; routing falls back`)
}

/** `/route reload` and a user /model: the marks are stale. */
function clearBreaker(st: State, id?: string): void {
  if (id === undefined) {
    st.down.clear()
    st.strikes.clear()
  } else {
    st.down.delete(id)
    st.strikes.delete(id)
  }
  st.turnModel = undefined
}

type Call = {
  model: string // exact string to send: `cur` verbatim when not moved
  why: string
  moved: boolean
  log?: string // turn-once line
  logKey?: string // its dedupe key when the text varies; default the text
  once?: string // session-once line
}

const keep = (cur: string, why = 'unchanged', log?: string): Call =>
  ({ model: cur, why, moved: false, ...(log === undefined ? {} : { log }) })

/** The replacement keeps the session's `[1m]` tier, haiku has none. */
function moveTo(cur: string, target: string, why: string): Call {
  const carried = ONE_M.test(cur) && !target.startsWith(HAIKU)
  const model = carried ? `${target}[1m]` : target
  const once = carried
    ? `model-router: ${why} to ${model}: the [1m] variant is carried over`
    : undefined
  return { model, why, moved: true, ...(once === undefined ? {} : { once }) }
}

/** True when the context still fits the target model's known window. */
function fits(st: State, id: string, tokens: number | undefined): boolean {
  const limit = hasKey(st.cfg.windows, id) ? st.cfg.windows[id] : undefined
  return limit === undefined || (tokens !== undefined && tokens < limit)
}

const noFit = (id: string): string =>
  `model-router: no switch to ${id}: context not known to fit`

/** Why the upgrade cap blocks a move, or undefined. Unknown size = blocked. */
function capBlock(st: State, tokens: number | undefined): string | undefined {
  if (tokens === undefined) return 'context size unknown'
  const max = st.cfg.upgradeMaxTokens
  return tokens > max ? `context ${tokens} tokens over ${max}` : undefined
}

/** True when `wanted` ranks above `id` in the fallback chain. */
function ranksAbove(st: State, wanted: string, id: string): boolean {
  const rw = modelRank(st.cfg, wanted)
  const rc = modelRank(st.cfg, id)
  return rw !== undefined && rc !== undefined && rw < rc
}

/**
 * `cur` is down: `wanted`, else the next model of the chain that fits. A
 * better `wanted` is an upgrade and passes the same switch and cap.
 */
function leaveDown(
  st: State,
  cur: string,
  wanted: string | undefined,
  tokens: number | undefined,
): Call {
  const id = canonical(st.cfg, cur)
  const upOk = st.cfg.mainUpgrade && capBlock(st, tokens) === undefined
  for (const option of [wanted, nextAvailable(st, id)]) {
    if (option === undefined || st.down.has(option)) continue
    if (aliasOf(st.cfg, option) === undefined) continue
    if (option === wanted && !upOk && ranksAbove(st, option, id)) continue
    if (fits(st, option, tokens)) return moveTo(cur, option, 'fallback')
  }
  return keep(cur, 'fallback unavailable')
}

/** `wanted` ranks above `cur`: upgrade, under the switch and the cap. */
function upgradeCall(
  st: State,
  cur: string,
  wanted: string,
  tokens: number | undefined,
): Call {
  if (!st.cfg.mainUpgrade) return keep(cur, 'switch off')
  const block = capBlock(st, tokens)
  if (block !== undefined) {
    const why = `upgrade skipped: ${block}`
    const call = keep(cur, why, `model-router: ${why}`)
    return { ...call, logKey: 'upgrade-skipped' }
  }
  if (!fits(st, wanted, tokens)) return keep(cur, 'no fit', noFit(wanted))
  return moveTo(cur, wanted, 'upgrade')
}

/** `wanted` is cheaper (or unranked): only with the downgrade switch on. */
function downgradeCall(
  st: State,
  cur: string,
  wanted: string,
  tokens: number | undefined,
): Call {
  if (!st.cfg.mainModelSwitch) return keep(cur, 'switch off')
  if (!fits(st, wanted, tokens)) return keep(cur, 'no fit', noFit(wanted))
  return moveTo(cur, wanted, 'downgrade')
}

/** A model the table does not rank is never switched; said once. */
function unknownCall(cur: string, id: string): Call {
  const call = keep(cur, 'model unknown to the table')
  if (id === '') return call
  const once = `model-router: ${id} unknown to the models table; no switch`
  return { ...call, once }
}

/**
 * The one decision of the main loop's model, in this order: router off, a
 * model the table does not rank (never touched), `cur` down (leave it,
 * always), no or same wanted model, a better one (upgrade), a cheaper one
 * (downgrade). Used by the step AND by every text, so they agree.
 */
function decideMain(
  st: State,
  cur: string,
  wanted: string | undefined,
  tokens: number | undefined,
): Call {
  const id = canonical(st.cfg, cur)
  if (st.off) return keep(cur)
  if (modelRank(st.cfg, id) === undefined) return unknownCall(cur, id)
  if (st.down.has(id)) return leaveDown(st, cur, wanted, tokens)
  if (wanted === undefined) return keep(cur)
  if (aliasOf(st.cfg, wanted) === aliasOf(st.cfg, id)) return keep(cur)
  return ranksAbove(st, wanted, id)
    ? upgradeCall(st, cur, wanted, tokens)
    : downgradeCall(st, cur, wanted, tokens)
}

/** Model axis: sticky, turn route, run slot, then the floor's own model. */
const mainModel = (st: State): string | undefined =>
  routeName(st.userMain?.route) ??
  routeName(st.turnMain?.route) ??
  routeName(st.runMain?.route) ??
  routeName(st.turnFloor?.route)

async function readTokens($: Api): Promise<number | undefined> {
  try {
    return (await $.session.usage()).context.tokens
  } catch {
    return undefined
  }
}

type Verdict = { call: Call; wanted: string | undefined }

/** What the main loop would run on from `cur`: wanted model + decision. */
async function decideFor($: Api, st: State, cur: string): Promise<Verdict> {
  const name = mainModel(st)
  const wanted = name === undefined
    ? undefined
    : resolveName(st, name, canonical(st.cfg, cur))
  const needsTokens = wanted !== undefined || st.down.size > 0
  const tokens = needsTokens ? await readTokens($) : undefined
  return { call: decideMain(st, cur, wanted, tokens), wanted }
}

function logCall($: Api, st: State, call: Call): void {
  const key = call.logKey ?? call.log
  if (call.log !== undefined && key !== undefined && !st.turnLogged.has(key)) {
    st.turnLogged.add(key)
    $.ui.log(call.log)
  }
  if (call.once !== undefined && !st.logged.has(call.once)) {
    st.logged.add(call.once)
    $.ui.log(call.once)
  }
}

/** The main loop's effective route: user /route > turn route > run slot. */
const mainRoute = (st: State): Routed | null =>
  st.userMain ?? st.turnMain ?? st.runMain

const rank = (l: Level | undefined): number =>
  l === undefined ? -1 : LEVELS.indexOf(l)

/** Lifts `effort` to `floor`; a lower level, a number or none is replaced. */
function floored(effort: Effort, floor: Level | undefined): Effort {
  if (floor === undefined) return effort
  return isLevel(effort) && rank(effort) >= rank(floor) ? effort : floor
}

/** Two floors in one turn: the higher level stays (a tie takes the new). */
function higherFloor(cur: Routed | null, next: Routed): Routed {
  return cur && rank(cur.route.effort) > rank(next.route.effort) ? cur : next
}

/**
 * The one decision of the main loop's effort. The user's floor is the turn's
 * default (no sticky or turn route names an effort) and its minimum.
 * `by` names who set the value: the floor when it raised or supplied it.
 */
function mainEffort(st: State, engine: Effort): Decision {
  const sticky = st.userMain?.route.effort
  const named = sticky ?? st.turnMain?.route.effort ??
    st.runMain?.route.effort
  const floor = st.turnFloor?.route.effort
  const base = named ?? floor ?? engine
  const effort = floored(base, floor)
  if (floor !== undefined && (named === undefined || effort !== base)) {
    return { effort, by: 'floor' }
  }
  if (named === undefined) return { effort, by: 'engine' }
  return { effort, by: sticky === undefined ? 'turn' : 'sticky' }
}

const floorWord = (f: Routed): string =>
  `user floor ${f.route.effort ?? '-'} (prompt rule ${f.phase})`

/**
 * Why main will not run at `asked`, or '' when it will. Truthful tail of
 * every answer that records an effort for the main loop.
 */
function mainNote(st: State, asked: Level | undefined): string {
  const d = mainEffort(st, undefined)
  if (d.by === 'floor') {
    if (!st.turnFloor || asked === undefined || d.effort === asked) return ''
    return `${floorWord(st.turnFloor)} keeps main at ${String(d.effort)}; ` +
      '/route clear to drop it'
  }
  return d.by === 'sticky' && st.userMain
    ? `a sticky /route ${st.userMain.phase} is in force and wins until ` +
      '/route clear'
    : ''
}

function loopOf(st: State, agentId: string): Loop {
  const known = st.loops.get(agentId)
  if (known) return known
  const fresh: Loop = {
    explicitEffort: false,
  }
  st.loops.set(agentId, fresh)
  return fresh
}

/** Writes a route on an agent loop, never on an axis given explicitly. */
function writeLoop(loop: Loop, route: Route): void {
  if (!loop.explicitEffort) loop.effort = route.effort
}

function clearRoutes(st: State): void {
  st.userMain = null
  st.turnMain = null
  st.runMain = null
  st.turnFloor = null
  st.pendingPrompt = null
}

/** Config `enabled: false` switches the router off; true lifts only that. */
function applyEnabled(st: State, enabled: boolean): void {
  if (!enabled) {
    st.off = true
    st.offConfig = true
  } else if (st.offConfig) {
    st.off = false
    st.offConfig = false
  }
}

const routerWord = (st: State): string =>
  st.off ? (st.offConfig ? 'off (config)' : 'off') : 'on'

// ---- text ------------------------------------------------------------

/** The floor's level when it carries one and the router is on. */
function liveFloor(st: State): { f: Routed; level: Level } | undefined {
  const f = st.turnFloor
  const level = f?.route.effort
  return st.off || !f || level === undefined ? undefined : { f, level }
}

/** An id the table knows, else "session model": '' and foreign ids alike. */
function idWord(st: State, model: string): string {
  const known = aliasOf(st.cfg, canonical(st.cfg, model)) !== undefined
  return known ? model : 'session model'
}

/** The router left a down model, or wanted to and found nowhere to go. */
const isFallback = (call: Call): boolean => call.why.startsWith('fallback')

/** Model words of the main line, from the decision a step would take. */
function modelWord(st: State, v: Verdict): string {
  const id = idWord(st, v.call.model)
  if (v.call.moved) return `${id} (${v.call.why})`
  if (v.wanted === undefined) {
    return isFallback(v.call) ? `${id} (${v.call.why})` : '-'
  }
  if (canonical(st.cfg, v.call.model) === v.wanted) return id
  return `asked ${v.wanted}, keeps ${id} (${v.call.why})`
}

/** The tier a route names, shown beside the model it resolved to. */
function tierWord(st: State, word: string): string {
  const name = mainModel(st)
  const tier = name !== undefined && hasKey(st.cfg.tiers, name)
  return tier ? `${word} [tier ${name}]` : word
}

/** Haiku takes no effort: the main line says so when it will run there. */
function effortWord(st: State, v: Verdict): string {
  if (v.call.model.startsWith(HAIKU)) return '- (haiku takes none)'
  return String(mainEffort(st, undefined).effort ?? '-')
}

function mainText(st: State, v: Verdict): string {
  const r = mainRoute(st)
  const live = liveFloor(st)
  const floor = live ? ` · floor ${live.level} (${live.f.phase})` : ''
  if (!r) {
    const left = v.call.moved || isFallback(v.call)
      ? ` · model ${modelWord(st, v)}`
      : ''
    return 'main: session defaults' + left + floor
  }
  const model = tierWord(st, modelWord(st, v))
  return `main: ${r.source} ${r.phase} · model ${model} · effort ${
    effortWord(st, v)}${floor}`
}

/** `name=<tier or model>→<resolved id>/<effort>` for every phase. */
function phasesText(st: State): string {
  const entries = Object.entries(st.cfg.phases).map(([name, r]) => {
    const asked = routeName(r)
    const id = asked === undefined ? undefined : resolveName(st, asked)
    const model = asked === undefined
      ? 'session'
      : asked === id ? asked : `${asked}→${id ?? '-'}`
    return `${name}=${model}/${r.effort ?? 'session'}`
  })
  return `phases: ${entries.join(' ')}`
}

function downText(st: State, now: number): string {
  const held = [...st.down].map(([id, h]) =>
    `${id} ${holdWord(h.until, now)} (${h.reason})`)
  return `down: ${held.length > 0 ? held.join(', ') : 'none'}`
}

/** The verdict a text reports: what the next main step would decide. */
async function snapshot($: Api, st: State) {
  const now = await prune($, st)
  const cur = st.turnModel ?? st.sessionModel
  return { now, ...(await decideFor($, st, cur)) }
}

async function show($: Api, st: State): Promise<string> {
  const c = st.cfg
  const flag = (b: boolean) => (b ? 'on' : 'off')
  const s = await snapshot($, st)
  return [
    mainText(st, s),
    `router: ${routerWord(st)} · switch: ${flag(c.mainModelSwitch)} ` +
      `(downgrade) · upgrade: ${flag(c.mainUpgrade)} · verbose: ${
        flag(c.verbose)} · spinner: ${flag(c.spinner)}`,
    downText(st, s.now),
    `live loops: ${st.loops.size}`,
    phasesText(st),
    `config: ${st.source}`,
  ].join('\n')
}

function statusLine(st: State): string {
  const r = mainRoute(st)
  const now = st.off
    ? routerWord(st)
    : r ? `${r.source} ${r.phase}` : 'session defaults'
  const floor = liveFloor(st)
  return `route: ${now}${floor ? ` · floor ${floor.level}` : ''}${
    st.cfg.mainModelSwitch ? ' · switch on' : ''}`
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

async function toggle(
  $: Api,
  st: State,
  what: string,
  arg: string | undefined,
): Promise<string> {
  if (arg !== 'on' && arg !== 'off') return `usage: /route ${what} on|off`
  if (what === 'switch') st.cfg.mainModelSwitch = arg === 'on'
  else st.cfg.verbose = arg === 'on'
  return show($, st)
}

async function setUserRoute($: Api, st: State, args: string) {
  const parsed = parseRoute(st.cfg, args)
  if (typeof parsed === 'string') return parsed
  st.userMain = parsed
  refresh($, st)
  return show($, st)
}

/**
 * (Re)loads the config into the state and re-registers the route tool.
 * An unusable override keeps the previous config: the kill switch fails
 * closed, never back to the defaults.
 */
async function reloadConfig($: Api, st: State): Promise<void> {
  const loaded = await loadConfig($, text => $.ui.log(text))
  if (loaded) {
    st.cfg = loaded.cfg
    st.rules = compileRules(loaded.cfg, text => $.ui.log(text))
    st.source = loaded.source
    applyEnabled(st, loaded.cfg.enabled)
  } else {
    $.ui.log('model-router: override unreadable; keeping the previous config')
  }
  await registerTool($, st)
}

/** The breaker is cleared first, whatever the config read then does. */
async function reloadCommand($: Api, st: State): Promise<string> {
  clearBreaker(st)
  await reloadConfig($, st)
  refresh($, st)
  return 'config reloaded\n' + (await show($, st))
}

async function handleCommand($: Api, st: State, args: string): Promise<string> {
  const [head = '', ...rest] = args.trim().split(/\s+/)
  switch (head) {
    case '':
    case 'show':
      return show($, st)
    case 'clear': {
      const run = st.runMain !== null
      clearRoutes(st)
      refresh($, st)
      return 'route cleared' + (run ? '; run slot dropped' : '') +
        '\n' + (await show($, st))
    }
    case 'on':
    case 'off':
      st.off = head === 'off'
      st.offConfig = false
      if (st.off) st.runMain = null
      refresh($, st)
      return show($, st)
    case 'reload':
      return reloadCommand($, st)
    case 'switch':
    case 'verbose':
      return toggle($, st, head, rest[0])
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
        'Declare the phase of the work ahead so the next requests of THIS ' +
        'loop run at the right effort and model. Call it before a span of ' +
        'work changes nature (planning, orchestrating, mechanical work). ' +
        'The main loop moves up to a phase\'s tier by itself (below the ' +
        'context cap), down only with the switch on; a sub-agent\'s model ' +
        'is fixed at spawn. ' +
        `Phases: ${Object.keys(st.cfg.phases).join(', ')}.`,
      inputSchema: {
        type: 'object',
        properties: {
          phase: { type: 'string', enum: Object.keys(st.cfg.phases) },
          effort: { type: 'string', enum: [...LEVELS] },
          clear: { type: 'boolean', description: 'drop this loop\'s route' },
        },
        additionalProperties: false,
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
    const f = st.turnFloor
    const held = f && f.route.effort !== undefined
      ? `; ${floorWord(f)} still holds, /route clear drops it`
      : ''
    const run = st.runMain
      ? `; run ${st.runMain.phase} still holds`
      : ''
    return 'route cleared for main' + held + run
  }
  const loop = st.loops.get(agentId)
  if (loop) writeLoop(loop, {})
  return 'route cleared for this agent'
}

/** The id the next main step runs on, with the decision's reason. */
async function mainAnswer($: Api, st: State): Promise<string> {
  const { call } = await snapshot($, st)
  return `${idWord(st, call.model)} (${call.why})`
}

/** Main's answer: effort and model asked, the sticky/floor note appended. */
async function mainRoutedText($: Api, st: State, p: Picked) {
  const base = `routed main to ${p.phase}: effort ${
    p.route.effort ?? 'unchanged'}, model ${await mainAnswer($, st)}`
  const note = mainNote(st, p.route.effort)
  return note ? `${base}; but ${note}` : base
}

/** Truthful answer: states what the calling loop will actually do. */
async function routedText(
  $: Api,
  st: State,
  agentId: string | undefined,
  p: Picked,
): Promise<string> {
  if (agentId === undefined) return mainRoutedText($, st, p)
  const explicit = st.loops.get(agentId)?.explicitEffort
  const model = routeName(p.route) ? 'unchanged (fixed at spawn)' : 'unchanged'
  return `routed this agent to ${p.phase}: effort ${
    explicit ? 'unchanged' : p.route.effort ?? 'unchanged'}, model ${model}`
}

async function handleRouteTool($: Api, st: State, e: RouteInput) {
  if (st.off) {
    return {
      result: 'model-router is off (/route on to resume); nothing routed',
    }
  }
  if (e.clear === true) return { result: clearLoop(st, e.agentId) }
  const picked = pickRoute(st.cfg, e.phase, e.effort)
  if (typeof picked === 'string') return { deny: picked }
  applyRoute(st, e.agentId, picked)
  return { result: await routedText($, st, e.agentId, picked) }
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
    const note = mainNote(st, level)
    return skillResult(skill, note
      ? `model-router: ${skill} recorded, but ${note}; the ${skill} skill ` +
        'text was not loaded.'
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

/** A skill's table row: its phase and that phase's route, if both exist. */
function skillRow(st: State, skill: string): Picked | undefined {
  const phase = hasKey(st.cfg.skills, skill) ? st.cfg.skills[skill] : undefined
  const route = phase === undefined ? undefined : phaseRoute(st.cfg, phase)
  return phase !== undefined && route ? { phase, route } : undefined
}

/**
 * A rowed skill on main sets the turn route; a best-tier row also holds the
 * run slot. A typed non-best row drops the run; one the model loads (a
 * helper skill inside a run) leaves it.
 */
function routeMainBySkill(st: State, row: Picked, typed: boolean): void {
  const turn: Routed = { phase: row.phase, route: { ...row.route },
    source: 'skill' }
  st.turnMain = turn
  if (row.route.tier === BEST) st.runMain = { ...turn, source: 'run' }
  else if (typed) st.runMain = null
}

/** A model-loaded skill: its row applies; an unrowed one changes nothing. */
function onSkillLoad(st: State, skill: string, agentId: string | undefined) {
  const row = skillRow(st, skill)
  if (agentId === undefined) {
    if (row) routeMainBySkill(st, row, false)
    return
  }
  if (row) writeLoop(loopOf(st, agentId), row.route)
}

type TypedPath = 'typed-marker' | 'typed-fallback'

/**
 * Whether a skill.prompt on main is the user's own typing. The marker from
 * prompt.submit names the skill; failing that, an allowed-origin prompt with
 * no live or spawning sub-agent (a preload fires inside one) still counts.
 */
function typedPath(st: State, skill: string): TypedPath | undefined {
  if (st.typedSlash === skill) {
    st.typedSlash = null
    return 'typed-marker'
  }
  const idle = st.loops.size === 0 && st.spawning === 0
  return st.promptAllowed && idle ? 'typed-fallback' : undefined
}

function applyTypedSkill($: Api, st: State, skill: string): void {
  const row = skillRow(st, skill)
  const path = typedPath(st, skill)
  if (row === undefined || path === undefined) return
  routeMainBySkill(st, row, true)
  refresh($, st)
  vlog($, st, `skill ${skill}: ${path} → ${row.phase}`)
}

// ---- agents ----------------------------------------------------------

type SpawnIn = {
  tool_use_id: string
  subagentType: string
  model?: string
  fork: boolean
  workflow?: unknown
}

/**
 * The table row of an agent, for every provider. Skipped for a fork, a
 * workflow agent, and an agent whose definition came from the project (a
 * foreign repo's own verifier.md). Known limit: the source is recorded by
 * name only, so an offer fired inside a sub-agent with another cwd
 * overwrites it; no record = the row applies (fail-open on routing).
 */
function spawnRoute(st: State, e: SpawnIn, frozen: boolean) {
  if (frozen || !hasKey(st.cfg.agents, e.subagentType)) return undefined
  if (PROJECT_SOURCES.has(st.offers.get(e.subagentType) ?? '')) {
    return undefined
  }
  const phase = st.cfg.agents[e.subagentType]
  return phase === undefined ? undefined : phaseRoute(st.cfg, phase)
}

/** Once per turn: a spawn whose tier has nothing at or above its head. */
function tierDownLog($: Api, st: State, agent: string, tier: string): void {
  const text = `model-router: ${agent} tier ${tier} down, ` +
    'frontmatter model kept'
  const key = `spawn-down:${agent}:${tier}`
  if (st.turnLogged.has(key)) return
  st.turnLogged.add(key)
  $.ui.log(text)
}

/**
 * The first model of the route's tier that is not down, only when it ranks
 * at or above the tier's head: an agent moves UP from its frontmatter alias,
 * never below. Nothing qualifies: no write, the frontmatter model runs.
 */
function inTier($: Api, st: State, agent: string, tier: string) {
  const aliases = hasKey(st.cfg.tiers, tier) ? st.cfg.tiers[tier] : undefined
  const head = aliases?.[0]
  const headId = head === undefined ? undefined : st.cfg.models[head]
  if (aliases === undefined || headId === undefined) return undefined
  const id = availableIn(st, aliases)
  if (id !== undefined && (id === headId || ranksAbove(st, id, headId))) {
    return id
  }
  tierDownLog($, st, agent, tier)
  return undefined
}

/** The model a spawn is rewritten to; an explicit `model` param wins. */
function spawnTarget($: Api, st: State, e: SpawnIn, route: Route | undefined) {
  if (e.model !== undefined || route === undefined) return undefined
  if (route.tier === undefined) return resolveRoute(st, route)
  return inTier($, st, e.subagentType, route.tier)
}

function trackLoop(st: State, e: SpawnIn, started: {
  agentId?: string
}, route: Route | undefined): void {
  const given = st.explicitEffort.get(e.tool_use_id)
  st.explicitEffort.delete(e.tool_use_id)
  if (started.agentId === undefined) return
  st.loops.set(started.agentId, {
    explicitEffort: given !== undefined,
    effort: given ? undefined : route?.effort,
  })
}

/** The breaker's target for an agent's failure; oldest entries dropped. */
function rememberAgent(st: State, agentId: string, model: string): void {
  st.agentModels.set(agentId, model.replace(ONE_M, ''))
  if (st.agentModels.size <= MAX_AGENT_MODELS) return
  const oldest = st.agentModels.keys().next().value
  if (oldest !== undefined) st.agentModels.delete(oldest)
}

// ---- derived orchestrate ---------------------------------------------

/**
 * A main Agent dispatch is orchestration: the turn's route becomes
 * `orchestrate` until the spawned agents end. A route the model or a skill
 * declared is never replaced.
 */
function pushOrchestrate(st: State): void {
  const src = st.turnMain?.source
  const route = phaseRoute(st.cfg, 'orchestrate')
  if (st.pushed !== null || !route) return
  if (src === 'model' || src === 'skill') return
  st.pushed = { prev: st.turnMain, spawnIds: new Set() }
  st.turnMain = { phase: 'orchestrate', route: { ...route }, source: 'derived' }
}

/** Restores the route from before the dispatch, unless one replaced it. */
function popOrchestrate(st: State): void {
  if (st.pushed && st.turnMain?.source === 'derived') {
    st.turnMain = st.pushed.prev
  }
  st.pushed = null
}

/** The agent id of a background launch, from the Agent tool's result. */
function launchedId(result: unknown): string | undefined {
  if (!isRecord(result) || result.status !== 'async_launched') return undefined
  return typeof result.agentId === 'string' ? result.agentId : undefined
}

/** After the Agent call: wait for a background agent, else pop at once. */
function afterDispatch(st: State, result: unknown): void {
  const id = launchedId(result)
  if (id !== undefined) {
    pushOrchestrate(st)
    st.pushed?.spawnIds.add(id)
  } else if (st.pushed && st.pushed.spawnIds.size === 0) {
    popOrchestrate(st)
  }
}

/** An agent's loop ended: forget it, pop when it was the last awaited. */
function endAgent(st: State, agentId: string): void {
  st.loops.delete(agentId)
  const awaited = st.pushed?.spawnIds
  if (awaited?.delete(agentId) && awaited.size === 0) popOrchestrate(st)
}

// ---- turn steps ------------------------------------------------------

function agentPlan(st: State, e: StepIn): Plan {
  const loop = e.agentId === undefined ? undefined : st.loops.get(e.agentId)
  return { model: e.model, effort: loop?.effort ?? e.effort }
}

/**
 * The main loop's plan: effort from the floor/sticky/turn decision, model
 * from `decideMain`. `cur` is the model the router moved this turn, else
 * the engine's own (verbatim: an engine fallback is respected).
 */
async function mainPlan($: Api, st: State, e: StepIn): Promise<Plan> {
  const { effort } = mainEffort(st, e.effort)
  await prune($, st)
  const cur = st.turnModel ?? e.model
  const { call } = await decideFor($, st, cur)
  logCall($, st, call)
  if (call.moved) st.turnModel = call.model
  return { model: call.model, effort }
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
  st.lastPlan = plan
  st.spinner = `${plan.model.replace(/^claude-/, '')}/${plan.effort ?? '-'}`
  refresh($, st)
}

function endMainTurn($: Api, st: State): void {
  st.turnFloor = st.pendingPrompt
  st.pendingPrompt = null
  st.turnMain = null
  st.pushed = null
  st.turnModel = undefined
  st.typedSlash = st.pendingSlash
  st.promptAllowed = st.pendingAllowed
  st.pendingSlash = null
  st.pendingAllowed = false
  st.explicitEffort.clear()
  st.spinner = ''
  st.turnLogged.clear()
  refresh($, st)
}

// ---- breaker inputs --------------------------------------------------

/** The exact id a failure is charged to: the agent's, else main's plan. */
function failureTarget(st: State, agentId: string | undefined) {
  if (agentId !== undefined) return st.agentModels.get(agentId)
  return st.lastPlan?.model.replace(ONE_M, '')
}

/** An engine StopFailure of an availability kind marks its model down. */
async function onStopFailure(
  $: Api,
  st: State,
  e: { error: string; agent_id?: string },
): Promise<void> {
  if (st.off || !UNAVAILABLE.has(e.error)) return
  const sent = failureTarget(st, e.agent_id)
  if (sent === undefined) return
  if (e.error === 'model_not_found' && aliasOf(st.cfg, sent) === undefined) {
    $.ui.log(`model-router: model_not_found for ${sent}: not a table id; ` +
      'no mark')
    return
  }
  await prune($, st)
  markDown($, st, canonical(st.cfg, sent), e.error, await $.clock.now())
}

type SwitchIn = {
  from_model: string
  to_model: string
  requested_model: string | null
  source: string
}

/**
 * The engine switched the model by itself. The model it left is marked, one
 * strike, unless it landed where the router already was; the mark targets
 * the model actually sent, else the model reported as left.
 */
async function onAutoSwitch($: Api, st: State, e: SwitchIn): Promise<void> {
  const cfg = st.cfg
  const from = canonical(cfg, e.from_model)
  const to = canonical(cfg, e.to_model)
  $.ui.log(`model-router: engine switched ${from} → ${to} ` +
    `(requested ${e.requested_model ?? '-'})`)
  const sent = st.lastPlan ? canonical(cfg, st.lastPlan.model) : undefined
  if (to === sent) return
  const target = sent !== undefined && aliasOf(cfg, sent) ? sent : from
  await prune($, st)
  markDown($, st, target, 'engine fallback', await $.clock.now())
}

/** Any model change: keeps `sessionModel`; a user choice clears its mark. */
async function onModelSwitch($: Api, st: State, e: SwitchIn): Promise<void> {
  st.sessionModel = e.to_model
  if (USER_SWITCH.has(e.source)) st.runMain = null
  if (st.off || e.source === 'resume') return
  if (e.source === 'auto') await onAutoSwitch($, st, e)
  else clearBreaker(st, canonical(st.cfg, e.to_model))
}

// ---- registration ----------------------------------------------------

async function readSessionModel($: Api): Promise<string> {
  try {
    return await $.session.model()
  } catch {
    return ''
  }
}

function registerSession(on: On, st: State): void {
  on('session.start', async ($, e, next) => {
    await reloadConfig($, st)
    st.sessionModel = await readSessionModel($)
    await registerCommand($)
    refresh($, st)
    return next(e)
  }).catch(($, e, next) => {
    warnOnce(st, $, 'session.start', next.error.kind)
    return next(e)
  })
  on('session.end', async ($, e, next) => {
    resetSession(st)
    // session.start never fires after /clear: re-apply the config's
    // `enabled` so a config-disabled router (offConfig) stays off.
    applyEnabled(st, st.cfg.enabled)
    return next(e)
  }).catch(($, e, next) => {
    warnOnce(st, $, 'session.end', next.error.kind)
    return next(e)
  })
}

function registerBreaker(on: On, st: State): void {
  on('classic.StopFailure', async ($, e, next) => {
    await onStopFailure($, st, e)
    return next(e)
  }).catch(($, e, next) => {
    warnOnce(st, $, 'StopFailure', next.error.kind)
    return next(e)
  })
  on('classic.PostModelSwitch', async ($, e, next) => {
    await onModelSwitch($, st, e)
    return next(e)
  }).catch(($, e, next) => {
    warnOnce(st, $, 'PostModelSwitch', next.error.kind)
    return next(e)
  })
}

function registerCommandHook(on: On, st: State): void {
  on('command.run', { command: 'route' }, async ($, e) => {
    if (e.origin.kind !== 'composer') {
      return { text: 'route: user-only command' }
    }
    return { text: await handleCommand($, st, e.args) }
  }).catch(($, e, next) => {
    warnOnce(st, $, 'command.run', next.error.kind)
    return { text: `route failed (${next.error.kind})` }
  })
}

function registerRouteTool(on: On, st: State): void {
  on('tool.call', { tool: TOOL }, async ($, e) => {
    const out = await handleRouteTool($, st, e)
    refresh($, st)
    vlog($, st, `route ${e.agentId ?? 'main'}: ${JSON.stringify(out)}`)
    return out
  }).catch(($, e, next) => {
    warnOnce(st, $, 'route tool', next.error.kind)
    return { result: `route failed (${next.error.kind}); nothing routed` }
  })
}

function registerSkills(on: On, st: State): void {
  on('tool.call', { tool: 'Skill' }, async ($, e, next) => {
    const skill = typeof e.skill === 'string' ? e.skill : undefined
    if (st.off || skill === undefined) return next(e)
    const level = EFFORT_SKILL.exec(skill)?.[1]
    if (isLevel(level)) return effortBridge(st, e.agentId, skill, level)
    st.skillCalls += 1
    try {
      safely(st, $, 'Skill', () => onSkillLoad(st, skill, e.agentId))
      return await next(e)
    } finally {
      st.skillCalls -= 1
    }
  }).catch(($, e, next) => {
    warnOnce(st, $, 'Skill', next.error.kind)
    return next(e)
  })
  on('skill.prompt', async ($, e, next) => {
    if (st.off || st.skillCalls > 0) return next(e)
    safely(st, $, 'skill.prompt', () => applyTypedSkill($, st, e.skill))
    return next(e)
  }).catch(($, e, next) => {
    warnOnce(st, $, 'skill.prompt', next.error.kind)
    return next(e)
  })
}

function registerAgents(on: On, st: State): void {
  on('tool.call', { tool: 'Agent' }, async ($, e, next) => {
    if (st.off) return next(e)
    if (isLevel(e.effort) && typeof e.tool_use_id === 'string') {
      st.explicitEffort.set(e.tool_use_id, e.effort)
    }
    if (e.agentId !== undefined) return next(e)
    pushOrchestrate(st)
    const out = await next(e)
    safely(st, $, 'Agent', () => afterDispatch(st, out.result))
    return out
  }).catch(($, e, next) => {
    warnOnce(st, $, 'Agent', next.error.kind)
    return next(e)
  })
}

/** Bookkeeping once the agent started: its loop, its model, a log line. */
function afterSpawn(
  $: Api,
  st: State,
  e: SpawnIn,
  started: { agentId?: unknown; model: string },
  route: Route | undefined,
): void {
  if (typeof started.agentId !== 'string') return
  const agentId = started.agentId
  safely(st, $, 'agent.spawn', () => {
    trackLoop(st, e, { agentId }, route)
    rememberAgent(st, agentId, started.model)
    vlog($, st,
      `spawn ${e.subagentType}: ${e.model ?? '-'} → ${started.model}`)
  })
}

function registerSpawn(on: On, st: State): void {
  on('agent.offer', async ($, e, next) => {
    if (!st.off) st.offers.set(e.agent, e.source)
    return next(e)
  }).catch(($, e, next) => {
    warnOnce(st, $, 'agent.offer', next.error.kind)
    return next(e)
  })
  on('agent.spawn', async ($, e, next) => {
    if (st.off) return next(e)
    st.spawning += 1
    try {
      await prune($, st)
      const route = spawnRoute(st, e, e.fork || e.workflow !== undefined)
      const wanted = spawnTarget($, st, e, route)
      const started = await next(wanted === undefined
        ? e
        : { ...e, model: wanted })
      afterSpawn($, st, e, started, route)
      return started
    } finally {
      st.spawning = Math.max(0, st.spawning - 1)
    }
  }).catch(($, e, next) => {
    warnOnce(st, $, 'agent.spawn', next.error.kind)
    return next(e)
  })
}

function registerTurns(on: On, st: State): void {
  on('turn.step', async function* ($, e, next) {
    if (st.off) return yield* next(e)
    const plan = await planStep($, st, e)
    const changed = plan.model !== e.model || plan.effort !== e.effort
    if (e.agentId === undefined) noteMain($, st, plan)
    vlog($, st, stepLog(e, plan))
    const result = yield* next(changed ? withPlan(e, plan) : e)
    safely(st, $, 'turn.step', () => vlog($, st,
      `step ${e.index} answered by ${result.usage?.model ?? '?'}`))
    return result
  }).catch(async function* ($, e, next) {
    warnOnce(st, $, 'turn.step', next.error.kind)
    return yield* next(e)
  })
  on('turn.complete', async ($, e, next) => {
    const agentId = e.agentId
    if (agentId !== undefined) safely(st, $, 'turn.complete', () =>
      endAgent(st, agentId))
    else endMainTurn($, st)
    return next(e)
  }).catch(($, e, next) => {
    warnOnce(st, $, 'turn.complete', next.error.kind)
    return next(e)
  })
}

/**
 * A prompt's level is a floor now; typed mid-turn (`wait` is ignored, the
 * engine queues either way) it is also kept for the next turn.
 */
function floorFromPrompt(st: State, midTurn: boolean, routed: Routed): void {
  st.turnFloor = higherFloor(st.turnFloor, routed)
  if (midTurn) st.pendingPrompt = higherFloor(st.pendingPrompt, routed)
}

const firstRule = (st: State, mode: PromptMode, text: string) =>
  st.rules.find(r => r.mode === mode && r.re.test(text))

/** A default rule sets the idle turn's route; routes and skills override. */
function defaultFromPrompt(st: State, scanned: string): void {
  const rule = firstRule(st, 'default', scanned)
  const route = rule ? phaseRoute(st.cfg, rule.phase) : undefined
  if (rule && route) {
    st.turnMain = { phase: rule.phase, route: { ...route }, source: 'prompt' }
  }
}

/**
 * Floor rules first (the user's explicit minimum). Default rules run only
 * on an idle, plain prompt: not mid-turn, not a slash command or skill
 * (they route themselves), not one that already carries a floor.
 */
function routeFromPrompt(st: State, text: string, midTurn: boolean): void {
  const scanned = text.slice(0, MAX_PROMPT_SCAN)
  const floor = firstRule(st, 'floor', scanned)
  const route = floor ? phaseRoute(st.cfg, floor.phase) : undefined
  if (floor && route) {
    const routed: Routed = { phase: floor.phase, route, source: 'prompt' }
    floorFromPrompt(st, midTurn, routed)
  }
  const slash = text.trimStart().startsWith('/')
  if (!midTurn && !slash && !floor) defaultFromPrompt(st, scanned)
}

/** The rowed skill a slash prompt names, else null. */
function typedSkill(st: State, text: string): string | null {
  const typed = text.trimStart()
  if (!typed.startsWith('/')) return null
  const name = typed.slice(1).split(/\s/, 1)[0] ?? ''
  return hasKey(st.cfg.skills, name) ? name : null
}

/**
 * Records what skill.prompt needs to tell a typed slash from a preload: the
 * skill named and whether a person typed it. A mid-turn prompt waits in the
 * pending slots for the turn end; a foreign one leaves them alone. A later
 * queued prompt replaces an earlier one (a shortcut: one pending slot).
 */
function noteTyped(st: State, kind: string, text: string, midTurn: boolean) {
  const allowed = TYPED_ORIGINS.has(kind)
  const slash = allowed ? typedSkill(st, text) : null
  if (!midTurn) {
    st.typedSlash = slash
    st.promptAllowed = allowed
  } else if (allowed) {
    st.pendingSlash = slash
    st.pendingAllowed = true
  }
}

function registerPrompt(on: On, st: State): void {
  on('prompt.submit', async ($, e, next) => {
    if (st.off) return next(e)
    const midTurn = e.turnId !== undefined
    noteTyped(st, e.origin.kind, e.text, midTurn)
    if (e.origin.kind === 'composer') routeFromPrompt(st, e.text, midTurn)
    refresh($, st)
    return next(e)
  }).catch(($, e, next) => {
    warnOnce(st, $, 'prompt.submit', next.error.kind)
    return next(e)
  })
  on('ui.render', { component: 'Spinner' }, async ($, e, next) => {
    if (st.off || !st.cfg.spinner || !st.spinner) return next(e)
    const suffix = ` · ${st.spinner}…`
    return next({ ...e, props: { ...e.props, suffix } })
  }).catch(($, e, next) => {
    warnOnce(st, $, 'ui.render', next.error.kind)
    return next(e)
  })
}

export const register: Register = on => {
  const st = newState(mergeConfig(undefined, () => undefined), 'defaults')
  registerSession(on, st)
  registerBreaker(on, st)
  registerCommandHook(on, st)
  registerRouteTool(on, st)
  registerSkills(on, st)
  registerAgents(on, st)
  registerSpawn(on, st)
  registerTurns(on, st)
  registerPrompt(on, st)
}
