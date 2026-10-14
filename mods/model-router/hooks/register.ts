// model-router: routes each model request (main loop and sub-agents) to the
// model and effort its phase deserves. Phases name a TIER (an ordered list of
// aliases, the first available wins); a circuit breaker fed by the engine's
// own failure events marks a model down for a while. Phases, skill and agent
// rows come from routing.json (tracked next to this mod; the first use of a
// row asks the user once, see "first use" below), the rest from
// DEFAULT_CONFIG; ~/.claude/model-router.json overrides both per machine.
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
  upgradeMaxTokens: number // max cold read an upgrade may cost (LRN-204)
  downgradeMaxTokens: number // max cold read a downgrade may cost (LRN-204)
  mainModelSwitch: boolean // gates DOWNGRADES only
  verbose: boolean
  classify: boolean // a small-model guess of the typed prompt's phase
  probe: boolean // a move target is tried once before main is sent to it
  spinner: boolean
  enabled: boolean // false: every hook passes through (per machine)
}
type Rule = { re: RegExp; phase: string; mode: PromptMode }
type Source =
  | 'user' | 'model' | 'skill' | 'prompt' | 'run' | 'derived' | 'classifier'
type Routed = {
  phase: string
  route: Route
  source: Source
  label?: string // the skill a skill route came from, for the logs
  explicitEffort?: boolean // the effort was asked for, not the phase's own
}
type Served = { at: number; tokens: number } // ms, context tokens
type Hold = { until: number; reason: string } // until: ms, Infinity = reload
type Pushed = { prev: Routed | null; spawnIds: Set<string> }
type Loop = {
  effort?: Level // an agent's model is fixed at spawn: effort is its only axis
  explicitEffort: boolean // Agent call gave an effort: axis frozen
  type?: string // subagentType, for the log lines
  last?: Plan // the plan this loop last ran, once it was told
  cause?: string // who set the effort in force, for the log lines
}
/** A submitted prompt's size where `session.usage` may not count it yet. */
type Estimate = {
  tokens: number
  usage: number | undefined // context size read when the first entry came
  unknown: boolean // carries a non-text item: the size cannot be guessed
}
type State = {
  cfg: Config
  rules: Rule[]
  source: string // 'defaults' or the override path
  userMain: Routed | null // /route by the user, sticky until /route clear
  turnMain: Routed | null // model route tool, skill table row, prompt
  // default rule, derived orchestrate; dropped at turn end
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
  descs: Map<string, string> // subagentType -> cleaned one-sentence offer line
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
  verified: Set<string> // canonical ids a probe saw answer (account-wide)
  agentModels: Map<string, string> // agentId -> exact id sent at spawn
  pushed: Pushed | null // derived orchestrate in force (background dispatch)
  logged: Set<string> // session-once log lines
  turnLogged: Set<string> // turn-once log lines
  warned: Set<string> // hooks whose fail-open was already logged
  mem: Memory // what routing.json says about decisions, as last read
  override: Rec | undefined // the machine override's data, if it loaded
  loaded: boolean // the layers were read once (else: lazily, on first use)
  rebuildDue: boolean // /clear: re-read the layers at the next prompt
  toggles: Partial<Record<Toggle, boolean>> // session toggles
  engineBase: NonNullable<Effort> | null // engine effort of the last turn's
  // first main step
  turnEngine: NonNullable<Effort> | null // same, for this turn
  served: Map<string, Served> // canonical id -> main's last step on it
  capSaid: boolean // the downgrade skip was logged for this cap crossing
  cacheTtlMs: number // the prompt-cache TTL a cold read is measured against
  promptEstimate: Estimate | null // the submitted prompt, not in usage yet
  pendingEstimate: Estimate | null // same, typed mid-turn: next turn's
  classifyFails: number // classifier failures in a row
  classifyUntil: number // classifier paused until (ms); 0 = running
  asking: string | null // key of the one first-use dialog in flight
  asked: Set<string> // keys answered (or failed) this session
  writes: Promise<unknown> // the serialized routing.json write chain
}
type Log = (text: string) => void
type StepIn = Readonly<TurnStepInput>
type PromptIn = {
  text: string
  attachments?: readonly { type: string }[]
  context?: readonly string[]
  turnId?: string
  origin: { kind: string }
}
type Plan = { model: string; effort: StepIn['effort'] }
type RouteInput = {
  phase?: unknown
  effort?: unknown
  clear?: unknown
  agentId?: string
}
type Picked = { phase: string; route: Route; explicitEffort?: boolean }
type Effort = StepIn['effort']
type Toggle = 'switch' | 'verbose' | 'classify'
type EffortBy = 'floor' | 'sticky' | 'turn' | 'engine'
type Decision = { effort: Effort; by: EffortBy }
type Rec = Record<string, unknown>
type Table = Record<string, string>
type Row = 'skills' | 'agents' // a table of rows in routing.json
type Kind = Row | 'phases' // what a first-use decision is about
/** What routing.json says about decisions, as last read. */
type Memory = {
  ok: boolean // the file was read: false = no dialog, no write
  ask: boolean // dialogs on (the machine override wins over the file)
  askLocal: boolean | undefined // the machine override's own `ask`
  base: Record<Row, Table> // the file's rows, before any project layer
  confirmed: Record<Kind, Table> // name -> the phase a Keep endorsed
  about: Table // phase -> its one-line meaning, shown in the dialog only
  filePhases: Record<string, Route> // the shipped phases: defaults + the file
  local: Record<Row, Set<string>> // rows of projects[key] or the override
  key: string | undefined // normalized repo key; undefined = no project layer
}

const LEVELS: readonly Level[] = ['low', 'medium', 'high', 'xhigh', 'max']
const MODEL_ID = /^claude-[a-z0-9.-]+$/
const TOOL = 'mcp__model-router__route'
const BEST = 'best' // the tier whose skill rows hold for a whole run
// Origins that are a person typing: only these arm a typed slash.
const TYPED_ORIGINS: ReadonlySet<string> = new Set([
  'composer', 'sdk', 'bridge',
])
// Definition sources of a foreign repo's own agent: its row is skipped.
const PROJECT_SOURCES: ReadonlySet<string> = new Set([
  'projectSettings', 'localSettings',
])
// Built-in agent types with no frontmatter model: an undefined `model` makes
// them inherit the spawning loop's model.
// shortcut: the frontmatter model of other types is invisible to the hook;
// widen the set when the engine exposes it on agent.offer.
const INHERITING_AGENTS: ReadonlySet<string> = new Set(['general-purpose'])
// PostModelSwitch sources a person chose (auto and resume are not).
const USER_SWITCH: ReadonlySet<string> = new Set([
  'command', 'picker', 'sdk',
])
const OVERRIDE = '.claude/model-router.json'
const ROUTING = 'routing.json' // next to plugin.json: the tracked source
// Key order of a written routing.json; other keys follow, untouched.
const ROUTING_ORDER: readonly string[] = [
  'phases', 'skills', 'agents', 'projects', 'confirmed', 'changed', 'ask',
]
// First-use dialog: the answers, and what a question may carry of the outside.
const LATER = 'Later'
const KEEP = 'Keep'
const CHANGE = 'Change'
const EVERYWHERE = 'Everywhere'
const THIS_PROJECT = 'This project only'
const CHOICE_ALIASES: readonly string[] = ['fable', 'opus', 'sonnet', 'haiku']
const MAX_DESC = 140 // chars of a skill or agent description in a question
const MAX_ABOUT = 120 // chars of a phase `about`
const MAX_DESCS = 256 // agent descriptions kept (oldest dropped)
const SKILL_NAME = /^[A-Za-z0-9][A-Za-z0-9._:-]*$/
const ROWS: readonly Row[] = ['skills', 'agents']
const KINDS: readonly Kind[] = ['skills', 'agents', 'phases']
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
// A model alias key, and the shape a key must have to be echoed in a log.
const KEY_NAME = /^[A-Za-z0-9][A-Za-z0-9_.:-]{0,63}$/
// Own keys that would shadow Object.prototype: never read, never written.
const BAD_KEYS: ReadonlySet<string> = new Set([
  '__proto__', 'constructor', 'prototype',
])
// A quantified group holding a quantifier, the shape behind catastrophic
// backtracking ((a+)+$): rejected before compiling.
const NESTED_QUANT = /\((?:[^()\\]|\\.)*[+*}](?:[^()\\]|\\.)*\)[+*{]/
// Prompt classifier: label -> the phase whose route the turn takes (effort,
// and a model below the session's under the switch and the cold-read cap).
// `chat` (and any label not here) routes nothing.
const CLASSIFY_LABELS: readonly string[] =
  ['design', 'analysis', 'coding', 'bookkeeping', 'chat']
const LABEL_PHASE: Readonly<Record<string, string>> = {
  design: 'plan',
  analysis: 'reflect',
  coding: 'implement',
  bookkeeping: 'apply',
}
const CLASSIFY_MIN = 12 // code points of a typed prompt worth a call
const CLASSIFY_MS = 3000 // the call is abandoned after this
const PROBE_MS = 8000 // a move target that has not answered by then is down
const PROBE_TOKENS = 16 // the probe's reply cap
const CLASSIFY_MAX = 2000 // code points sent whole; longer: head + tail
const CLASSIFY_HEAD = 500
const CLASSIFY_TAIL = 1500
const CLASSIFY_FAILS = 3 // failures in a row that pause the classifier
// The account's prompt-cache TTL: a model that served main within it is
// warm. 1 h default; replaced by the engine's `cache_ttl` at the first
// model-switch event.
const CACHE_TTL_MS = 60 * 60000
// The engine's two `cache_ttl` values (a closed enum), in ms.
const CACHE_TTLS: Readonly<Record<string, number>> = {
  '5m': 5 * 60000,
  '1h': 60 * 60000,
}
const ESTIMATE_DIVISOR = 3 // code points per token, conservative
const TIMEOUT: unique symbol = Symbol('timeout')

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
  upgradeMaxTokens: 200000, // max cold read an upgrade may cost
  downgradeMaxTokens: 120000, // max cold read a downgrade may cost (LRN-204)
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
  // Rows (skill/agent -> phase) live in routing.json, the tracked source;
  // a project-level agent of the same name shadows its row (see spawnRoute).
  agents: {},
  skills: {},
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
  mainModelSwitch: true,
  verbose: false,
  classify: true,
  probe: true,
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
/** A row or phase key fit to read and write: never a prototype name. */
const goodKey = (key: string): boolean => !BAD_KEYS.has(key)
/** A key in a log line: short and printable, or a placeholder. */
const keyWord = (key: string): string => KEY_NAME.test(key) ? key : '<key>'
/** An error in a log line: its kind only; a message may quote the file. */
function errWord(err: unknown): string {
  if (!(err instanceof Error)) return typeof err
  const code = (err as { code?: unknown }).code
  return typeof code === 'string' && KEY_NAME.test(code)
    ? `${err.name} ${code}`
    : err.name
}
/** A log on the step path: a failing ui.log must not unroute the step. */
function tryLog($: Api, text: string): void {
  try {
    $.ui.log(text)
  } catch {
    // the step matters more than its line
  }
}

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
    const ok = goodKey(key) ? accept(key, value) : undefined
    if (ok === undefined) {
      log(`model-router: config ${name}.${keyWord(key)} ignored`)
    }
    else out[key] = ok
  }
  return out
}

/** An alias is a short printable name; its value a full id. */
const acceptModel = (key: string, v: unknown): string | undefined =>
  KEY_NAME.test(key) && isFullId(v) ? v : undefined

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
    log(`model-router: config fallback lacks ${
      missing.map(keyWord).join(', ')}; appended`)
  }
  return [...chain, ...missing]
}

/** The fallback chain: deduplicated aliases of `models`, else the default;
 * either way every alias ends up ranked. */
function pickFallback(
  user: unknown,
  base: string[],
  models: Record<string, string>,
  log: Log,
): string[] {
  if (user === undefined) return withEveryAlias(base, models, log)
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
  if (pattern.length > MAX_PATTERN || NESTED_QUANT.test(pattern)) {
    return undefined
  }
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

/** A switch key: a non-boolean is dropped, and `warning` is logged. */
function pickSwitch(
  warning: string,
  v: unknown,
  fallback: boolean,
  log: Log,
): boolean {
  if (v !== undefined && typeof v !== 'boolean') {
    log(warning)
  }
  return pickBool(v, fallback)
}

/** The kill switch fails closed: a value that is not a boolean reads off. */
function pickEnabled(v: unknown, fallback: boolean, log: Log): boolean {
  if (v === undefined) return fallback
  if (typeof v === 'boolean') return v
  log('model-router: config "enabled" is not a boolean; router off (fail closed)')
  return false
}

/** The model switch fails closed: a non-boolean override reads off. */
function pickModelSwitch(v: unknown, fallback: boolean, log: Log): boolean {
  if (v === undefined) return fallback
  if (typeof v === 'boolean') return v
  log('model-router: config "mainModelSwitch" is not a boolean; ' +
    'switch off')
  return false
}

type Routing = Pick<Config, 'tiers' | 'fallback' | 'cooldownMinutes' |
  'mainUpgrade' | 'upgradeMaxTokens' | 'downgradeMaxTokens'>

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
    downgradeMaxTokens: pickPositive(
      user.downgradeMaxTokens, base.downgradeMaxTokens, 'downgradeMaxTokens',
      log),
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
    if (value === null && goodKey(key)) delete rows[key]
  }
  return rows
}

/** `seed` (the defaults) overlaid with the user's entries, each validated. */
function mergeConfig(
  user: unknown,
  log: Log,
  seed: Config = DEFAULT_CONFIG,
): Config {
  const base = structuredClone(seed)
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
    mainModelSwitch: pickModelSwitch(
      user.mainModelSwitch, base.mainModelSwitch, log),
    verbose: pickSwitch(
      'config "verbose" is not a boolean; ignored', user.verbose, base.verbose, log),
    classify: pickSwitch(
      'model-router: config "classify" is not a boolean; ignored',
      user.classify, base.classify, log),
    probe: pickSwitch(
      'model-router: config "probe" is not a boolean; ignored',
      user.probe, base.probe, log),
    spinner: pickBool(user.spinner, base.spinner),
    enabled: pickEnabled(user.enabled, base.enabled, log),
  }
}

/** The file's text, or undefined (logged) when it exceeds the cap. */
async function readCapped(
  $: Api,
  path: string,
  label: string,
  log: Log,
): Promise<string | undefined> {
  const tooBig = `model-router: ${label} over ${MAX_CONFIG_BYTES} bytes`
  const info = await $.fs.stat(path)
  if (info.kind !== 'file') {
    log(`model-router: ${label} is not a regular file`)
    return undefined
  }
  if (info.size > MAX_CONFIG_BYTES) {
    log(tooBig)
    return undefined
  }
  const text = await $.fs.read(path)
  if (text.length <= MAX_CONFIG_BYTES) return text
  log(tooBig)
  return undefined
}

type Layer = { path: string; data: Rec } | 'absent' | 'failed'

/** 'absent': no file (defaults apply). 'failed': present but unusable. */
async function readLayer(
  $: Api,
  path: string,
  label: string,
  log: Log,
): Promise<Layer> {
  try {
    if (!(await $.fs.exists(path))) return 'absent'
    const text = await readCapped($, path, label, log)
    if (text === undefined) return 'failed'
    const data: unknown = JSON.parse(text)
    if (isRecord(data)) return { path, data }
    log(`model-router: ${label} is not an object`)
    return 'failed'
  } catch (err) {
    log(`model-router: ${label} unreadable (${errWord(err)})`)
    return 'failed'
  }
}

const readRouting = ($: Api, log: Log): Promise<Layer> =>
  readLayer($, `${$.plugin.root}/${ROUTING}`, ROUTING, log)

async function readOverride($: Api, log: Log): Promise<Layer> {
  try {
    const home = await $.env.get('HOME')
    if (!home) return 'absent'
    return await readLayer($, `${home}/${OVERRIDE}`, OVERRIDE, log)
  } catch (err) {
    log(`model-router: ${OVERRIDE} unreadable (${errWord(err)})`)
    return 'failed'
  }
}

// ---- routing.json: decision memory and project exceptions --------------

const strTable = (v: unknown): Table =>
  isRecord(v)
    ? Object.fromEntries(Object.entries(v).filter(
      (entry): entry is [string, string] => typeof entry[1] === 'string'))
    : {}

const subRec = (v: unknown, key: string): Rec => {
  const found = isRecord(v) && hasKey(v, key) ? v[key] : undefined
  return isRecord(found) ? found : {}
}

/** The rows of `projects[key]`: this repo's exceptions. */
function projectRows(file: Rec, key: string | undefined): Record<Row, Table> {
  const mine = key === undefined ? {} : subRec(file.projects, key)
  return { skills: strTable(mine.skills), agents: strTable(mine.agents) }
}

function emptyMemory(): Memory {
  return {
    ok: false,
    ask: true,
    askLocal: undefined,
    base: { skills: {}, agents: {} },
    confirmed: { skills: {}, agents: {}, phases: {} },
    about: {},
    filePhases: {},
    local: { skills: new Set(), agents: new Set() },
    key: undefined,
  }
}

/** The phases' `about` lines; a non-string or overlong one is dropped, said. */
function aboutOf(phases: unknown, log: Log): Table {
  const out: Table = {}
  if (!isRecord(phases)) return out
  for (const [name, phase] of Object.entries(phases)) {
    const about = isRecord(phase) ? phase.about : undefined
    if (about === undefined || !goodKey(name)) continue
    if (typeof about === 'string' && about.length <= MAX_ABOUT) {
      out[name] = about
    } else {
      log(`model-router: ${ROUTING} phases.${name}.about ignored`)
    }
  }
  return out
}

/** What the file and the machine override say about decisions. */
function buildMemory(
  file: Rec,
  key: string | undefined,
  override: Rec | undefined,
  log: Log,
): Memory {
  const project = projectRows(file, key)
  const flag = override?.ask
  const askLocal = typeof flag === 'boolean' ? flag : undefined
  const sure = subRec(file, 'confirmed')
  const local = (row: Row): Set<string> => new Set([
    ...Object.keys(project[row]), ...Object.keys(strTable(override?.[row])),
  ])
  return {
    ok: true,
    ask: askLocal ?? file.ask !== false,
    askLocal,
    base: { skills: strTable(file.skills), agents: strTable(file.agents) },
    confirmed: {
      skills: strTable(sure.skills),
      agents: strTable(sure.agents),
      phases: strTable(sure.phases),
    },
    about: aboutOf(file.phases, log),
    filePhases: mergeConfig({ phases: file.phases }, () => undefined).phases,
    local: { skills: local('skills'), agents: local('agents') },
    key,
  }
}

const SCP_REMOTE = /^[A-Za-z0-9._-]+@([A-Za-z0-9.-]+):([^:@]+)$/
const URL_REMOTE = /^[a-z][a-z0-9+.-]*:\/\//i

/** [host, path] of a remote, userinfo never read; undefined if unclear. */
function remoteParts(url: string): [string, string] | undefined {
  const scp = SCP_REMOTE.exec(url)
  if (scp) return [scp[1] as string, scp[2] as string]
  if (!URL_REMOTE.test(url)) return undefined
  // a second `@` in the authority hides a secret in the userinfo
  const authority = url.replace(URL_REMOTE, '').split('/')[0] ?? ''
  if (authority.split('@').length > 2) return undefined
  try {
    const u = new URL(url)
    return [u.host, u.pathname]
  } catch {
    return undefined
  }
}

/**
 * A repo's identity across clones and machines: its origin remote reduced to
 * `host/path` (scheme, userinfo, `.git` and trailing slash dropped, host
 * lowercased). A remote that cannot be read with certainty, or that leaves
 * an `@` or `:` in the host or an `@` in the path, gives undefined: no
 * credential ever reaches the tracked file.
 */
function normalizeRemote(url: string): string | undefined {
  const parts = remoteParts(url.trim())
  if (parts === undefined) return undefined
  const host = parts[0].toLowerCase()
  const path = parts[1].replace(/^\/+/, '').replace(/\/+$/, '')
    .replace(/\.git$/i, '')
  if (host === '' || path === '' || path.includes('@')) return undefined
  return /[@:]/.test(host.replace(/:\d+$/, '')) ? undefined : `${host}/${path}`
}

async function projectKey($: Api): Promise<string | undefined> {
  try {
    const repo = await $.session.repo()
    return repo?.remote ? normalizeRemote(repo.remote) : undefined
  } catch {
    return undefined
  }
}

/** routing.json's phases and rows as a user table, this repo's rows last. */
function routingTables(file: Rec, key: string | undefined): Rec {
  const project = projectRows(file, key)
  return {
    phases: file.phases,
    skills: { ...strTable(file.skills), ...project.skills },
    agents: { ...strTable(file.agents), ...project.agents },
  }
}

type Loaded = {
  cfg: Config
  source: string
  mem: Memory
  override: Rec | undefined
}

function sourceWord(file: Layer, over: Layer): string {
  const fileWord = typeof file === 'string' ? undefined : ROUTING
  const overWord = typeof over === 'string' ? undefined : over.path
  if (fileWord && overWord) return `${fileWord} + ${overWord}`
  return fileWord ?? overWord ?? 'defaults'
}

/** A phase routing.json lacks keeps the code default: one line names them. */
function logMissingPhases(phases: unknown, log: Log): void {
  if (phases !== undefined && !isRecord(phases)) return // mergeTable says it
  const missing = Object.keys(DEFAULT_CONFIG.phases)
    .filter(name => !isRecord(phases) || !hasKey(phases, name))
  if (missing.length === 0) return
  log(`model-router: ${ROUTING} lacks phases ${missing.join(', ')}; ` +
    'code defaults kept')
}

/**
 * Defaults < routing.json < the machine override. The phases of both files
 * merge first; every layer's rows then validate against that final table,
 * so a routing.json row may name a phase only the override defines.
 */
function layerConfig(
  tables: Rec | undefined,
  override: Rec | undefined,
  log: Log,
): Config {
  const seeded = mergeConfig(tables && { phases: tables.phases }, log)
  const cfg = mergeConfig(
    override && { ...override, skills: undefined, agents: undefined },
    log, seeded)
  const ref = acceptPhaseRef(cfg.phases)
  for (const row of ROWS) {
    const base = mergeRows(cfg[row], tables?.[row], row, ref, log)
    cfg[row] = mergeRows(base, override?.[row], row, ref, log)
  }
  return cfg
}

/** Defaults < routing.json (phases, rows, this repo's rows) < override. */
async function assemble(
  $: Api,
  file: Layer,
  over: Layer,
  log: Log,
): Promise<Loaded> {
  const fileData = typeof file === 'string' ? undefined : file.data
  const override = typeof over === 'string' ? undefined : over.data
  if (file === 'absent') {
    log(`model-router: ${ROUTING} missing; default phases, no rows, no asks`)
  }
  const key = fileData === undefined ? undefined : await projectKey($)
  if (fileData !== undefined) logMissingPhases(fileData.phases, log)
  const cfg = layerConfig(
    fileData && routingTables(fileData, key), override, log)
  const mem = fileData === undefined
    ? emptyMemory()
    : buildMemory(fileData, key, override, log)
  return { cfg, source: sourceWord(file, over), mem, override }
}

/**
 * Reads the layers. At the first load a failed routing.json is skipped
 * (logged) and a failed override turns the router off (the kill switch it
 * may hold is unknown); in every later read any failure, or a routing.json
 * gone missing, returns undefined so the caller keeps the previous config.
 */
async function loadLayers(
  $: Api,
  first: boolean,
  log: Log,
): Promise<Loaded | undefined> {
  const file = await readRouting($, log)
  const over = await readOverride($, log)
  const broken = file === 'failed' || file === 'absent' || over === 'failed'
  if (broken && !first) return undefined
  const loaded = await assemble($, file, over, log)
  if (over === 'failed') {
    log(`model-router: ${OVERRIDE} unreadable at first load; ` +
      'router off (fail closed) until a `/route reload` reads it')
    loaded.cfg = { ...loaded.cfg, enabled: false }
  }
  return loaded
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
    descs: new Map(),
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
    verified: new Set(),
    agentModels: new Map(),
    pushed: null,
    logged: new Set(),
    turnLogged: new Set(),
    warned: new Set(),
    mem: emptyMemory(),
    override: undefined,
    loaded: false,
    rebuildDue: false,
    toggles: {},
    engineBase: null,
    turnEngine: null,
    served: new Map(),
    capSaid: false,
    cacheTtlMs: CACHE_TTL_MS,
    promptEstimate: null,
    pendingEstimate: null,
    classifyFails: 0,
    classifyUntil: 0,
    asking: null,
    asked: new Set(),
    writes: Promise.resolve(),
  }
}

/**
 * /clear rebuilds the state but keeps what is account- or process-wide:
 * the breaker and the models a probe verified, the classifier's pause and
 * effort baseline (a model's quota and the user's own /effort outlive the
 * conversation), the model, the agent definitions' sources (the listing is
 * not offered again), the config with its session toggles and the dialog in
 * flight. The layers are read again at the next prompt; the config is
 * swapped only if that read works.
 */
function resetSession(st: State): void {
  const kept = {
    down: st.down,
    strikes: st.strikes,
    verified: st.verified,
    agentModels: st.agentModels,
    sessionModel: st.sessionModel,
    offers: st.offers,
    descs: st.descs,
    mem: st.mem,
    override: st.override,
    loaded: st.loaded,
    toggles: st.toggles,
    engineBase: st.engineBase,
    cacheTtlMs: st.cacheTtlMs,
    classifyFails: st.classifyFails,
    classifyUntil: st.classifyUntil,
    asking: st.asking,
    writes: st.writes,
  }
  Object.assign(st, newState(st.cfg, st.source), kept)
  st.rebuildDue = st.loaded
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
    known => bare === known || bare.startsWith(`${known}-`))
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
  st.verified.delete(id)
  tryLog($, `model-router: ${id} unavailable (${reason}) ${
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

/** The move keeps the `[1m]` tier of `cur` or the session; haiku has none. */
function moveTo(
  cur: string,
  target: string,
  why: string,
  session: string,
): Call {
  const long = ONE_M.test(cur) || ONE_M.test(session)
  const carried = long && !target.startsWith(HAIKU)
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

/**
 * Tokens a switch INTO `id` re-reads cold (LRN-204): the context minus what
 * `id`'s cache holds, i.e. its last main step within the TTL. A context
 * smaller than that step (compaction) drops the stale record.
 */
function coldRead(
  st: State,
  id: string,
  tokens: number,
  now: number,
): number {
  const key = canonical(st.cfg, id)
  const hit = st.served.get(key)
  if (hit === undefined || now - hit.at > st.cacheTtlMs) return tokens
  if (tokens < hit.tokens) {
    st.served.delete(key)
    return tokens
  }
  return tokens - hit.tokens
}

/** Why a cap blocks a move onto `id`, or undefined. Unknown size = blocked. */
function coldBlock(
  st: State,
  id: string,
  tokens: number | undefined,
  max: number,
  now: number,
): string | undefined {
  if (tokens === undefined) return 'context size unknown'
  const cold = coldRead(st, id, tokens, now)
  return cold > max ? `cold read ${cold} tokens over ${max}` : undefined
}

/** True when `wanted` ranks above `id` in the fallback chain. */
function ranksAbove(st: State, wanted: string, id: string): boolean {
  const rw = modelRank(st.cfg, wanted)
  const rc = modelRank(st.cfg, id)
  return rw !== undefined && rc !== undefined && rw < rc
}

/** Main keeps its model: a cap said no, once per turn under its own key. */
function skipped(cur: string, kind: string, block: string): Call {
  const why = `${kind} skipped: ${block}`
  const call = keep(cur, why, `model-router: ${why}`)
  return { ...call, logKey: `${kind}-skipped` }
}

/** The state a decision reads besides the model: context size and clock. */
type Reading = { tokens: number | undefined; now: number }

/**
 * `cur` is down: `wanted`, else the next model of the chain that fits. A
 * better `wanted` is an upgrade and passes the same switch and cap.
 */
function leaveDown(
  st: State,
  cur: string,
  wanted: string | undefined,
  read: Reading,
): Call {
  const id = canonical(st.cfg, cur)
  const max = st.cfg.upgradeMaxTokens
  const upOk = (o: string): boolean => st.cfg.mainUpgrade &&
    coldBlock(st, o, read.tokens, max, read.now) === undefined
  for (const option of [wanted, nextAvailable(st, id)]) {
    if (option === undefined || st.down.has(option)) continue
    if (aliasOf(st.cfg, option) === undefined) continue
    if (option === wanted && ranksAbove(st, option, id) && !upOk(option)) {
      continue
    }
    if (fits(st, option, read.tokens)) {
      return moveTo(cur, option, 'fallback', st.sessionModel)
    }
  }
  return keep(cur, 'fallback unavailable')
}

/** `wanted` ranks above `cur`: upgrade, under the switch and the cap. */
function upgradeCall(
  st: State,
  cur: string,
  wanted: string,
  read: Reading,
): Call {
  if (!st.cfg.mainUpgrade) return keep(cur, 'switch off')
  const block = coldBlock(
    st, wanted, read.tokens, st.cfg.upgradeMaxTokens, read.now)
  if (block !== undefined) return skipped(cur, 'upgrade', block)
  if (!fits(st, wanted, read.tokens)) {
    return keep(cur, 'no fit', noFit(wanted))
  }
  return moveTo(cur, wanted, 'upgrade', st.sessionModel)
}

/** `wanted` is cheaper (or unranked): the switch and the cold-read cap. */
function downgradeCall(
  st: State,
  cur: string,
  wanted: string,
  read: Reading,
): Call {
  if (!st.cfg.mainModelSwitch) return keep(cur, 'switch off')
  const block = coldBlock(
    st, wanted, read.tokens, st.cfg.downgradeMaxTokens, read.now)
  if (block !== undefined) return skipped(cur, 'downgrade', block)
  if (!fits(st, wanted, read.tokens)) {
    return keep(cur, 'no fit', noFit(wanted))
  }
  return moveTo(cur, wanted, 'downgrade', st.sessionModel)
}

/** A model the table does not rank is never switched; said once. */
function unknownCall(cur: string, id: string): Call {
  const call = keep(cur, 'model unknown to the table')
  if (id === '') return call
  const once = `model-router: ${id} unknown to the models table; no switch`
  return { ...call, once }
}

/**
 * Main sits on a model the router moved it to and whose known window the
 * context outgrew (haiku): back to the session model, when that is a known,
 * ranked, available, non-haiku model. Otherwise undefined: the normal
 * decision runs.
 */
function windowReturn(
  st: State,
  cur: string,
  tokens: number | undefined,
): Call | undefined {
  const id = canonical(st.cfg, cur)
  const home = canonical(st.cfg, st.sessionModel)
  if (st.turnModel === undefined || tokens === undefined) return undefined
  if (fits(st, id, tokens)) return undefined
  const usable = modelRank(st.cfg, home) !== undefined &&
    !st.down.has(home) && !isHaiku(st.cfg, home)
  if (!usable) return undefined
  const call = moveTo(cur, home, 'window', st.sessionModel)
  const once = `model-router: context outgrew ${id}: back to ${home}`
  return { ...call, once }
}

/**
 * The one decision of the main loop's model, in this order: router off, a
 * model the table does not rank (never touched), a model whose window the
 * context outgrew (back to the session model), `cur` down (leave it,
 * always), no or same wanted model, a better one (upgrade), a cheaper one
 * (downgrade). Used by the step AND by every text, so they agree.
 */
function decideMain(
  st: State,
  cur: string,
  wanted: string | undefined,
  read: Reading,
): Call {
  const id = canonical(st.cfg, cur)
  if (st.off) return keep(cur)
  if (modelRank(st.cfg, id) === undefined) return unknownCall(cur, id)
  const back = windowReturn(st, cur, read.tokens)
  if (back !== undefined) return back
  if (st.down.has(id)) return leaveDown(st, cur, wanted, read)
  if (wanted === undefined) return keep(cur)
  if (aliasOf(st.cfg, wanted) === aliasOf(st.cfg, id)) return keep(cur)
  return ranksAbove(st, wanted, id)
    ? upgradeCall(st, cur, wanted, read)
    : downgradeCall(st, cur, wanted, read)
}

/**
 * The slot that names main's model: sticky, turn route, run slot, then the
 * floor's own model. A floor with a model beats a classifier's guess.
 */
function mainModelSlot(st: State): Routed | null {
  const slots = [st.userMain, st.turnMain, st.runMain, st.turnFloor]
  const slot = slots.find(s => routeName(s?.route) !== undefined) ?? null
  const floor = st.turnFloor
  if (slot?.source === 'classifier' && routeName(floor?.route) !== undefined) {
    return floor
  }
  return slot
}

const mainModel = (st: State): string | undefined =>
  routeName(mainModelSlot(st)?.route)

async function readTokens($: Api): Promise<number | undefined> {
  try {
    return (await $.session.usage()).context.tokens
  } catch {
    return undefined
  }
}

/**
 * The context size a cap reads: `raw` plus the pending prompt's estimate,
 * unless usage already grew by half of it (the prompt was counted). Pure:
 * the step and every text read the same figure. Unknown = blocked.
 */
function withEstimate(st: State, raw: number | undefined) {
  const est = st.promptEstimate
  if (raw === undefined || est === null) return raw
  if (est.unknown) return undefined
  const counted = est.usage !== undefined &&
    raw - est.usage >= est.tokens / 2
  return counted ? raw : raw + est.tokens
}

/** Sums an entry into a pending estimate; the first baseline is kept. */
function sumEstimate(
  cur: Estimate | null,
  tokens: number,
  usage: number | undefined,
  unknown: boolean,
): Estimate {
  return {
    tokens: (cur?.tokens ?? 0) + tokens,
    usage: cur === null ? usage : cur.usage,
    unknown: (cur?.unknown ?? false) || unknown,
  }
}

/**
 * Adds a submitted text (and a flag for a non-text item) to the pending
 * estimate. A mid-turn entry waits for the next turn, where its baseline is
 * reset; the first entry of a turn reads the usage as its baseline.
 */
async function addEstimate(
  $: Api,
  st: State,
  size: { points: number; unknown: boolean },
  midTurn: boolean,
): Promise<void> {
  const tokens = Math.ceil(size.points / ESTIMATE_DIVISOR)
  if (midTurn) {
    st.pendingEstimate = sumEstimate(
      st.pendingEstimate, tokens, undefined, size.unknown)
    return
  }
  const usage = st.promptEstimate === null ? await readTokens($) : undefined
  st.promptEstimate = sumEstimate(
    st.promptEstimate, tokens, usage, size.unknown)
}

/** Code points of a text, as the estimate counts them. */
const pointsOf = (texts: readonly string[]): number =>
  texts.reduce((n, t) => n + Array.from(t).length, 0)

type Verdict = {
  call: Call
  wanted: string | undefined
  standIn: boolean // a lower model runs where the tier's held head would
}

/**
 * The model main is asked to run on from `cur`. A classifier's guess never
 * ranks above the session model: it moves main down, never above the
 * user's baseline.
 */
function wantedModel(st: State, cur: string): string | undefined {
  const slot = mainModelSlot(st)
  const name = routeName(slot?.route)
  if (name === undefined) return undefined
  const wanted = resolveName(st, name, canonical(st.cfg, cur))
  const above = wanted !== undefined && slot?.source === 'classifier' &&
    ranksAbove(st, wanted, canonical(st.cfg, st.sessionModel))
  return above ? undefined : wanted
}

/** Reads the usage and the clock when a decision may need them. */
async function readingFor(
  $: Api,
  st: State,
  wanted: string | undefined,
): Promise<Reading> {
  const needs = wanted !== undefined || st.down.size > 0 ||
    st.turnModel !== undefined
  if (!needs) return { tokens: undefined, now: 0 }
  const raw = await readTokens($)
  return { tokens: withEstimate(st, raw), now: await $.clock.now() }
}

/**
 * The race of a call against the clock: its value, or TIMEOUT. With a
 * `signal` the wait rejects when the dispatch aborts.
 */
function raceTimeout<T>(
  $: Api,
  call: Promise<T>,
  ms: number,
  signal?: AbortSignal,
): Promise<T | typeof TIMEOUT> {
  return Promise.race([
    call,
    $.clock.sleep(ms, signal === undefined ? {} : { signal })
      .then((): typeof TIMEOUT => TIMEOUT),
  ])
}

/** True when `id` answered a tiny completion in time; no hook signal. */
async function probeAnswers($: Api, id: string): Promise<boolean> {
  try {
    const ask = { model: id, prompt: 'ok', maxTokens: PROBE_TOKENS }
    return (await raceTimeout($, $.model.complete(ask), PROBE_MS)) !== TIMEOUT
  } catch {
    return false
  }
}

/**
 * Tries a move target before main is sent to it. An answer verifies it,
 * unless a failure landed meanwhile (the hold wins); a timeout or a
 * rejection marks it down. True when the move may go ahead.
 */
async function probeModel($: Api, st: State, id: string): Promise<boolean> {
  if (await probeAnswers($, id)) {
    if (!st.down.has(id)) st.verified.add(id)
  } else {
    markDown($, st, id, 'probe', await $.clock.now())
  }
  return !st.down.has(id)
}

/** The table id a move lands on that still wants a probe, else undefined. */
function unprobed(st: State, call: Call): string | undefined {
  if (!call.moved || !st.cfg.probe || st.off) return undefined
  const id = canonical(st.cfg, call.model)
  const fresh = !st.verified.has(id) && !st.down.has(id)
  return aliasOf(st.cfg, id) !== undefined && fresh ? id : undefined
}

type Decided = { call: Call; wanted: string | undefined }

/** The decision, probing a move target once; a failed probe: decide again. */
async function decideProbed(
  $: Api,
  st: State,
  cur: string,
  read: Reading,
): Promise<Decided> {
  const wanted = wantedModel(st, cur)
  const call = decideMain(st, cur, wanted, read)
  const id = unprobed(st, call)
  if (id === undefined || await probeModel($, st, id)) return { call, wanted }
  const after = wantedModel(st, cur)
  return { call: decideMain(st, cur, after, read), wanted: after }
}

/** The held head of the tier the main model slot names, or undefined. */
function heldHead(st: State): string | undefined {
  const tier = mainModelSlot(st)?.route.tier
  const list = tier !== undefined && hasKey(st.cfg.tiers, tier)
    ? st.cfg.tiers[tier]
    : undefined
  const alias = list?.[0]
  const id = alias === undefined ? undefined : st.cfg.models[alias]
  return id !== undefined && st.down.has(id) ? id : undefined
}

/**
 * With `head` available, the router would run it: the classifier ceiling
 * does not refuse it and the decision lands on it (switch, caps, window).
 */
function wouldRunHead(
  st: State,
  cur: string,
  head: string,
  read: Reading,
): boolean {
  const capped = mainModelSlot(st)?.source === 'classifier' &&
    ranksAbove(st, head, canonical(st.cfg, st.sessionModel))
  if (capped) return false
  const held = new Map([...st.down].filter(([id]) => id !== head))
  const open: State = { ...st, down: held }
  return canonical(st.cfg, decideMain(open, cur, head, read).model) === head
}

/**
 * A lower model runs where the tier's head, held down, would have: the
 * decision is that tier's resolution, ranked below the head, and the head
 * would have been run. Pure; the step and every text read this one value.
 */
function isStandIn(
  st: State,
  cur: string,
  d: Decided,
  read: Reading,
): boolean {
  const head = heldHead(st)
  if (st.off || head === undefined || d.wanted === undefined) return false
  const id = canonical(st.cfg, d.call.model)
  return id === d.wanted && ranksAbove(st, head, id) &&
    wouldRunHead(st, cur, head, read)
}

/**
 * What the main loop would run on from `cur`: wanted model + decision. The
 * step passes the `known` reading it took; a text reads for itself. A move
 * target is probed here, after the decision (see `decideProbed`).
 */
async function decideFor(
  $: Api,
  st: State,
  cur: string,
  known?: Reading,
): Promise<Verdict> {
  const read = known ?? await readingFor($, st, wantedModel(st, cur))
  const decided = await decideProbed($, st, cur, read)
  return { ...decided, standIn: isStandIn(st, cur, decided, read) }
}

function logCall($: Api, st: State, call: Call): void {
  const key = call.logKey ?? call.log
  if (call.log !== undefined && key !== undefined && !st.turnLogged.has(key)) {
    st.turnLogged.add(key)
    tryLog($, call.log)
  }
  if (call.once !== undefined && !st.logged.has(call.once)) {
    st.logged.add(call.once)
    tryLog($, call.once)
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
  const turn = st.turnMain?.route.effort
  const named = sticky ?? turn ?? st.runMain?.route.effort
  const floor = st.turnFloor?.route.effort
  const base = named ?? floor ?? engine
  const effort = floored(base, floor)
  if (floor !== undefined && (named === undefined || effort !== base)) {
    return { effort, by: 'floor' }
  }
  if (named === undefined) return { effort, by: 'engine' }
  return { effort, by: sticky === undefined ? 'turn' : 'sticky' }
}

/** The route slot that supplied a sticky or turn effort, else null. */
function effortSlot(st: State, by: EffortBy): Routed | null {
  if (by === 'sticky') return st.userMain
  if (by !== 'turn') return null
  return st.turnMain?.route.effort === undefined ? st.runMain : st.turnMain
}

/** One notch up on LEVELS; `max` stays. */
const notchUp = (level: Level): Level =>
  LEVELS[Math.min(rank(level) + 1, LEVELS.length - 1)] ?? level

type Lifted = Decision & { standIn: boolean }

/**
 * A stand-in model runs the tier one notch up: only the effort the slot
 * that names the tier supplied, never an explicit one, a floor's or an
 * engine number. `standIn` is true when the level really moved.
 */
function standInEffort(st: State, d: Decision, v: Verdict): Lifted {
  const level = d.effort
  const slot = effortSlot(st, d.by)
  const own = slot !== null && slot === mainModelSlot(st) &&
    slot.explicitEffort !== true
  if (!v.standIn || !own || !isLevel(level)) return { ...d, standIn: false }
  const lifted = notchUp(level)
  return { effort: lifted, by: d.by, standIn: lifted !== level }
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
function writeLoop(loop: Loop, route: Route, cause: string): void {
  if (loop.explicitEffort) return
  loop.effort = route.effort
  loop.cause = cause
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

/** "opus stands in for fable": the model that runs and the held head. */
function standInWord(st: State, v: Verdict): string {
  const head = aliasOf(st.cfg, heldHead(st) ?? '') ?? '?'
  const alias = aliasOf(st.cfg, canonical(st.cfg, v.call.model)) ?? '?'
  return `${alias} stands in for ${head}`
}

/** Haiku takes no effort: the main line says so when it will run there. */
function effortWord(st: State, v: Verdict): string {
  if (v.call.model.startsWith(HAIKU)) return '- (haiku takes none)'
  const d = standInEffort(st, mainEffort(st, undefined), v)
  const word = String(d.effort ?? '-')
  return d.standIn ? `${word} (${standInWord(st, v)})` : word
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

/** The downgrade switch and, when on, the cold read it is capped at. */
const switchWord = (st: State): string => st.cfg.mainModelSwitch
  ? `on (downgrade, cap ${st.cfg.downgradeMaxTokens} tokens cold, ttl ${
    Math.round(st.cacheTtlMs / 60000)} min)`
  : 'off (downgrade)'

async function show($: Api, st: State): Promise<string> {
  const c = st.cfg
  const flag = (b: boolean) => (b ? 'on' : 'off')
  const s = await snapshot($, st)
  return [
    mainText(st, s),
    `router: ${routerWord(st)} · switch: ${switchWord(st)} · upgrade: ${
      flag(c.mainUpgrade)} · verbose: ${
        flag(c.verbose)} · classify: ${flag(c.classify)} · probe: ${
        flag(c.probe)} · spinner: ${flag(c.spinner)}`,
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
  const paused = st.cfg.classify && st.classifyUntil !== 0
  return `route: ${now}${floor ? ` · floor ${floor.level}` : ''}${
    st.cfg.mainModelSwitch ? '' : ' · switch off'}${
    paused ? ' · classifier: paused' : ''}`
}

const refresh = ($: Api, st: State): void => $.ui.status(statusLine(st))

/** The one gate of the verbose lines, which say transitions only. */
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
  const explicitEffort = route.effort !== undefined
  return { phase: 'custom', route, source: 'user',
    ...(explicitEffort ? { explicitEffort } : {}) }
}

async function toggle(
  $: Api,
  st: State,
  what: Toggle,
  arg: string | undefined,
): Promise<string> {
  if (arg !== 'on' && arg !== 'off') return `usage: /route ${what} on|off`
  st.toggles[what] = arg === 'on'
  applyToggles(st)
  refresh($, st)
  return show($, st)
}

async function setUserRoute($: Api, st: State, args: string) {
  const parsed = parseRoute(st.cfg, args)
  if (typeof parsed === 'string') return parsed
  st.userMain = parsed
  refresh($, st)
  return show($, st)
}

/** Session toggles outlive any rebuild of the config. */
function applyToggles(st: State): void {
  const { switch: downgrade, verbose, classify } = st.toggles
  if (downgrade !== undefined) st.cfg.mainModelSwitch = downgrade
  if (verbose !== undefined) st.cfg.verbose = verbose
  if (classify !== undefined) st.cfg.classify = classify
}

function applyLoaded(st: State, loaded: Loaded, log: Log): void {
  st.cfg = loaded.cfg
  st.rules = compileRules(loaded.cfg, log)
  st.source = loaded.source
  st.mem = loaded.mem
  st.override = loaded.override
  st.loaded = true
  st.rebuildDue = false
  applyToggles(st)
  applyEnabled(st, loaded.cfg.enabled)
}

/**
 * (Re)loads the layers into the state and re-registers the route tool.
 * After the first load an unusable layer keeps the whole previous config:
 * the kill switch fails closed, never back to the defaults. True when the
 * new config was swapped in.
 */
async function reloadConfig($: Api, st: State): Promise<boolean> {
  const log = (text: string): void => $.ui.log(text)
  const loaded = await loadLayers($, !st.loaded, log)
  if (loaded) applyLoaded(st, loaded, log)
  else log('model-router: config unreadable; keeping the previous config')
  await registerTool($, st)
  return loaded !== undefined
}

/**
 * The layers are read at session.start; a state that never saw it (a
 * /reload-plugins re-runs register) loads on its first use. /clear leaves
 * a re-read due, taken by the next prompt only (`atPrompt`).
 */
async function ensureConfig($: Api, st: State, atPrompt = false) {
  if (st.loaded && !(atPrompt && st.rebuildDue)) return
  st.rebuildDue = false
  await reloadConfig($, st)
}

/** The breaker is cleared first, whatever the config read then does. */
async function reloadCommand($: Api, st: State): Promise<string> {
  clearBreaker(st)
  st.served.clear()
  st.capSaid = false
  st.classifyFails = 0
  st.classifyUntil = 0
  const swapped = await reloadConfig($, st)
  refresh($, st)
  const head = swapped
    ? 'config reloaded'
    : 'config unreadable; previous config kept (see the log)'
  return `${head}\n${await show($, st)}`
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
      st.lastPlan = null // the next step compares to the engine's input
      if (st.off) st.runMain = null
      refresh($, st)
      return show($, st)
    case 'reload':
      return reloadCommand($, st)
    case 'pending':
      return pendingText(st)
    case 'ask':
      return askCommand($, st, rest[0])
    case 'forget':
      return forgetCommand($, st, rest)
    case 'switch':
    case 'verbose':
    case 'classify':
      return toggle($, st, head, rest[0])
    default:
      return setUserRoute($, st, args)
  }
}

// ---- first use: one dialog per row, the answer kept in routing.json -----
// The first time a row routes (a typed skill, an agent spawn, a phase
// declared through the route tool) the user confirms it once, for every
// project; a change can be a project exception. Only a dialog answer,
// `/route ask` or `/route forget` writes; nothing is asked on the step path
// or in an agent.

const HEADER = 'model-router'
const UPDATED = 'routing.json updated: commit it from the config repo ' +
  '(chore branch)'

type Req = { kind: Kind; name: string; phase: string }
type RowReq = Req & { kind: Row }
type Answer =
  | { act: 'later' }
  | { act: 'keep' }
  | { act: 'change'; phase: string }
type Scope = 'everywhere' | 'project' | 'later'
type Patch = (file: Rec) => void

const keyOf = (req: { kind: Kind; name: string }): string =>
  `${req.kind}:${req.name}`
const isRowReq = (req: Req): req is RowReq => req.kind !== 'phases'
const own = (t: Table, name: string): string | undefined =>
  hasKey(t, name) ? t[name] : undefined

/** Decided: a Keep or change confirmed the row, or a layer set it. */
function isDecided(mem: Memory, kind: Kind, name: string): boolean {
  if (kind === 'phases') return own(mem.confirmed.phases, name) === name
  if (mem.local[kind].has(name)) return true
  const base = own(mem.base[kind], name)
  return base !== undefined && own(mem.confirmed[kind], name) === base
}

const wantsAsk = (st: State, req: Req): boolean =>
  !st.off && st.mem.ask && !st.asked.has(keyOf(req)) &&
  !isDecided(st.mem, req.kind, req.name)

/** The file as it is now: another live session may have decided since. */
async function refreshMemory($: Api, st: State): Promise<boolean> {
  const file = await readRouting($, text => $.ui.log(text))
  if (typeof file === 'string') return false
  st.mem = buildMemory(
    file.data, await projectKey($), st.override, () => undefined)
  return true
}

async function askOr(
  $: Api,
  text: string,
  options: readonly string[],
): Promise<string> {
  try {
    return await $.ui.ask(text, { options, header: HEADER })
  } catch {
    return LATER // dismissed, or no one to ask (-p run)
  }
}

// What a question says about its row. Everything read from outside (a
// SKILL.md, an agent's listing line, routing.json) is cleaned and capped.

/**
 * Text safe in a question: every whitespace folded to a space, then control
 * and format characters (bidi included) stripped, cut to `n` code points
 * with an ellipsis (total <= n).
 */
function clean(text: string, n: number): string {
  const flat = text.replace(/[\s\p{Z}]+/gu, ' ')
    .replace(/[\p{Cc}\p{Cf}]/gu, '').replace(/ {2,}/g, ' ').trim()
  const points = [...flat]
  return points.length <= n ? flat : `${points.slice(0, n - 1).join('')}…`
}

/** The first sentence of a description, cleaned; undefined when empty. */
function oneSentence(text: string): string | undefined {
  const end = /\.(?:\s|$)/.exec(text)
  const line = clean(end ? text.slice(0, end.index) : text, MAX_DESC)
  return line === '' ? undefined : line
}

const FRONTMATTER = /^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)/
const BLOCK_HEAD = /^[|>][+-]?\d*$/

/** A YAML scalar without its quotes: `''` and JSON escapes resolved. */
function unquote(value: string): string {
  const quote = value[0]
  if (value.length < 2 || value[value.length - 1] !== quote) return value
  if (quote === "'") return value.slice(1, -1).replace(/''/g, "'")
  if (quote !== '"') return value
  try {
    const parsed: unknown = JSON.parse(value)
    return typeof parsed === 'string' ? parsed : value.slice(1, -1)
  } catch {
    return value.slice(1, -1)
  }
}

/** `description:` of a SKILL.md frontmatter: plain, block or quoted. */
function frontDescription(text: string): string | undefined {
  const front = FRONTMATTER.exec(text)?.[1]
  const lines = front === undefined ? [] : front.split(/\r?\n/)
  const at = lines.findIndex(line => line.startsWith('description:'))
  if (at < 0) return undefined
  const head = (lines[at] ?? '').slice('description:'.length).trim()
  const body: string[] = []
  for (const line of lines.slice(at + 1)) {
    if (line.trim() !== '' && !/^\s/.test(line)) break
    body.push(line.trim())
  }
  const first = BLOCK_HEAD.test(head) ? '' : head
  return unquote([first, ...body].filter(w => w !== '').join(' '))
}

/**
 * A skill's description from ${HOME}/.claude/skills/<name>/SKILL.md: a
 * regular file under the size cap, a name from the allowlist. Any failure
 * gives undefined: the question names the skill alone.
 */
async function skillDesc($: Api, name: string): Promise<string | undefined> {
  if (!SKILL_NAME.test(name)) return undefined
  try {
    const home = await $.env.get('HOME')
    if (!home) return undefined
    const path = `${home}/.claude/skills/${name}/SKILL.md`
    if ((await $.fs.stat(path)).kind !== 'file') return undefined
    const text = await readCapped($, path, 'SKILL.md', () => undefined)
    const raw = text === undefined ? undefined : frontDescription(text)
    return raw === undefined ? undefined : oneSentence(raw)
  } catch {
    return undefined
  }
}

/** The agent listing line, cleaned once at offer time; oldest dropped. */
function rememberOffer(
  st: State,
  e: { agent: string; source: string; description: string },
): void {
  st.offers.delete(e.agent)
  st.offers.set(e.agent, e.source)
  if (st.offers.size > MAX_DESCS) {
    const first = st.offers.keys().next().value
    if (first !== undefined) st.offers.delete(first)
  }
  const given: unknown = e.description
  const line = typeof given === 'string'
    ? oneSentence(given.slice(0, 4096))
    : undefined
  st.descs.delete(e.agent)
  if (line !== undefined) st.descs.set(e.agent, line)
  if (st.descs.size <= MAX_DESCS) return
  const oldest = st.descs.keys().next().value
  if (oldest !== undefined) st.descs.delete(oldest)
}

const plural = (n: number, word: string): string =>
  `${n} ${word}${n === 1 ? '' : 's'}`

const withDesc = (lead: string, desc: string | undefined): string =>
  desc === undefined ? lead : `${lead} — ${desc}`

function aboutLine(st: State, phase: string): string | undefined {
  const raw = own(st.mem.about, phase)
  const line = raw === undefined ? '' : clean(raw, MAX_ABOUT)
  return line === '' ? undefined : line
}

/** "Routed to <phase> (<about>)": the parenthesis only when about is set. */
function routedTo(st: State, phase: string): string {
  const about = aboutLine(st, phase)
  return `Routed to ${phase}${about === undefined ? '' : ` (${about})`}`
}

/** Who uses a phase: its rows, the derived dispatch route, prompt rules. */
function consumers(st: State, phase: string): string {
  const { skills, agents, prompt } = st.cfg
  const rows = [...Object.values(skills), ...Object.values(agents)]
    .filter(p => p === phase).length
  const rules = prompt.filter(r => r.phase === phase)
  const floors = rules.filter(r => r.mode !== 'default').length
  const parts = [plural(rows, 'row')]
  if (phase === 'orchestrate') parts.push('the derived route of dispatches')
  if (rules.length > floors) {
    parts.push(plural(rules.length - floors, 'prompt rule'))
  }
  if (floors > 0) parts.push(plural(floors, 'floor rule'))
  return `used by ${parts.join(', ')}`
}

// ---- the dialog's steps: ASK1 Later/Keep/Change, then model, effort, scope

const optionsFor = (req: Req): string[] =>
  isRowReq(req) ? [LATER, KEEP, CHANGE] : [LATER, KEEP]

/**
 * One step: the chosen label, or undefined (a Later). A dismissed or
 * headless dialog is silent; any other answer is toasted, never echoed.
 */
async function askStep(
  $: Api,
  text: string,
  labels: readonly string[],
): Promise<string | undefined> {
  const answer = await askOr($, text, labels)
  if (answer === LATER) return undefined
  if (labels.includes(answer)) return answer
  $.ui.toast('answer not recognised, default kept')
  return undefined
}

/** The alias a phase's route leads with: its tier's head, or its model. */
function headAlias(cfg: Config, route: Route): string | undefined {
  if (route.tier !== undefined) {
    const list = hasKey(cfg.tiers, route.tier) ? cfg.tiers[route.tier] : []
    return list?.[0]
  }
  if (route.model === undefined) return undefined
  return hasKey(cfg.models, route.model)
    ? route.model
    : aliasOf(cfg, canonical(cfg, route.model))
}

/** "fable (best)": the alias and the tier it heads ("custom" if none). */
function modelLabel(cfg: Config, alias: string): string {
  const tier = Object.keys(cfg.tiers).find(t => cfg.tiers[t]?.[0] === alias)
  return `${alias} (${tier ?? 'custom'})`
}

async function askModel($: Api, st: State, req: RowReq) {
  const labels = CHOICE_ALIASES.map(a => modelLabel(st.cfg, a))
  const label = await askStep($, `Which model for ${req.name}?`, labels)
  return label === undefined ? undefined : CHOICE_ALIASES[labels.indexOf(label)]
}

/**
 * The efforts of the shipped phases headed by `alias`, ascending, four at
 * most. A phase only the machine override defines is never offered: the
 * answer is written into the tracked file.
 */
function effortsOf(cfg: Config, shipped: Record<string, Route>, alias: string) {
  const found = Object.values(shipped)
    .filter(r => headAlias(cfg, r) === alias).map(r => r.effort)
  return LEVELS.filter(level => found.includes(level)).slice(0, 4)
}

/** One effort is no question; none is a Later, said. */
async function askEffort($: Api, st: State, alias: string) {
  const efforts = effortsOf(st.cfg, st.mem.filePhases, alias)
  if (efforts.length === 0) {
    $.ui.toast(`no shipped phase uses ${alias}: add one to ${ROUTING}`)
  }
  if (efforts.length < 2) return efforts[0]
  const label = await askStep($, `Which effort on ${alias}?`, efforts)
  return efforts.find(effort => effort === label)
}

/** The row's phase when it matches, else the first shipped one that does. */
function targetPhase(st: State, now: string, alias: string, effort: Level) {
  const shipped = st.mem.filePhases
  const fits = (name: string): boolean => {
    const route = hasKey(shipped, name) ? shipped[name] : undefined
    return route?.effort === effort && headAlias(st.cfg, route) === alias
  }
  return fits(now) ? now : Object.keys(shipped).find(fits)
}

/** Change: model, then effort, mapped to a phase of the table. */
async function changeRoute($: Api, st: State, req: RowReq): Promise<Answer> {
  const alias = await askModel($, st, req)
  const effort = alias === undefined ? undefined : await askEffort($, st, alias)
  if (alias === undefined || effort === undefined) return { act: 'later' }
  const phase = targetPhase(st, req.phase, alias, effort)
  if (phase === undefined) return { act: 'later' }
  return phase === req.phase ? { act: 'keep' } : { act: 'change', phase }
}

async function decide($: Api, st: State, req: Req, text: string) {
  const choice = await askStep($, text, optionsFor(req))
  if (choice === KEEP) return { act: 'keep' } as const
  if (choice === CHANGE && isRowReq(req)) return changeRoute($, st, req)
  return { act: 'later' } as const
}

async function askScope(
  $: Api,
  st: State,
  req: Req,
  to: string,
): Promise<Scope> {
  const key = st.mem.key
  const text = `Use ${to} for ${req.name} everywhere, or only in this project?`
  const choice = await askStep($, text,
    [EVERYWHERE, key === undefined ? LATER : THIS_PROJECT])
  if (choice === EVERYWHERE) return 'everywhere'
  return choice === THIS_PROJECT && key !== undefined ? 'project' : 'later'
}

function table(parent: Rec, key: string): Rec {
  const found = isRecord(parent[key]) ? parent[key] : undefined
  if (found) return found
  const fresh: Rec = {}
  parent[key] = fresh
  return fresh
}

function setKey(target: Rec, key: string, value: unknown): void {
  if (goodKey(key)) target[key] = value
}

const confirmIn = (file: Rec, kind: Kind, name: string, phase: string) =>
  setKey(table(table(file, 'confirmed'), kind), name, phase)

/** A Keep endorses the row and its phase (no second ask at the route tool). */
function keepPatch(req: Req): Patch {
  return file => {
    if (isRowReq(req)) confirmIn(file, req.kind, req.name, req.phase)
    confirmIn(file, 'phases', req.phase, req.phase)
  }
}

/**
 * Everywhere: the row moves, `changed` keeps the FIRST shipped phase for
 * the census. This project only: the row stays, the exception goes under
 * the repo key and the base row counts as confirmed (nobody else asks).
 */
function changePatch(req: RowReq, to: string, scope: Scope, key?: string) {
  return (file: Rec): void => {
    const rows = table(file, req.kind)
    const was = typeof rows[req.name] === 'string' ? rows[req.name] : req.phase
    if (scope === 'project' && key !== undefined) {
      const mine = table(table(file, 'projects'), key)
      setKey(table(mine, req.kind), req.name, to)
      confirmIn(file, req.kind, req.name, String(was))
      return
    }
    const changed = table(table(file, 'changed'), req.kind)
    const first = subRec(changed, req.name).from ?? was
    setKey(rows, req.name, to)
    setKey(changed, req.name, { from: first, to })
    confirmIn(file, req.kind, req.name, to)
  }
}

function serializeRouting(file: Rec): string {
  const known = ROUTING_ORDER.filter(k => hasKey(file, k))
  const extra = Object.keys(file).filter(k => !ROUTING_ORDER.includes(k))
  const ordered = Object.fromEntries(
    [...known, ...extra].map(k => [k, file[k]]))
  return JSON.stringify(ordered, null, 2) + '\n'
}

/** The write landed but the config could not be rebuilt from it. */
class RebuildFailed extends Error {}

/**
 * Read-modify-write of routing.json, one at a time (a chain). Refuses a
 * missing or unparsable file and never creates it; rebuilds the config
 * after, swapped only if the read works.
 */
async function writeNow($: Api, st: State, patch: Patch): Promise<boolean> {
  const file = await readRouting($, text => $.ui.log(text))
  if (typeof file === 'string') {
    $.ui.toast(`${ROUTING} is missing or unreadable: nothing saved`)
    return false
  }
  patch(file.data)
  const out = serializeRouting(file.data)
  if (out.length > MAX_CONFIG_BYTES) {
    $.ui.toast(`${ROUTING} would exceed ${MAX_CONFIG_BYTES} bytes: ` +
      'nothing saved')
    return false
  }
  await $.fs.write(file.path, out)
  const rebuilt = await reloadConfig($, st)
  $.ui.toast(UPDATED)
  if (!rebuilt) throw new RebuildFailed('rebuild failed after the write')
  return true
}

function writeRouting($: Api, st: State, patch: Patch): Promise<boolean> {
  const run = st.writes.then(() => writeNow($, st, patch))
  st.writes = run.catch(() => undefined)
  return run
}

/** A write that failed: the cause goes to the log, never to the answer. */
function failedWrite($: Api, cmd: string, err: unknown): string {
  $.ui.log(`${cmd} failed: ${errWord(err)}`)
  return `${cmd} not applied, see the log`
}

async function saveAnswer($: Api, st: State, req: Req, ans: Answer) {
  if (ans.act === 'keep') return writeRouting($, st, keepPatch(req))
  if (ans.act !== 'change' || !isRowReq(req)) return false
  const scope = await askScope($, st, req, ans.phase)
  if (scope === 'later') return false
  const patch = changePatch(req, ans.phase, scope, st.mem.key)
  return writeRouting($, st, patch)
}

/**
 * The dialog and what follows; true when routing.json was rewritten. A
 * failure before the user answered leaves the key unasked (the next use
 * asks again); one after it keeps the key asked, the answer being given.
 */
async function runDialog($: Api, st: State, req: Req, text: string) {
  st.asked.add(keyOf(req))
  let answer: Answer
  try {
    answer = await decide($, st, req, text)
  } catch (err) {
    st.asked.delete(keyOf(req))
    throw err
  }
  return saveAnswer($, st, req, answer)
}

function failOnce($: Api, st: State, err: unknown): void {
  const text = `model-router: first-use dialog failed (${errWord(err)}); ` +
    'default route kept'
  if (st.logged.has(text)) return
  st.logged.add(text)
  $.ui.log(text)
}

/**
 * Asks once whether `req.phase` is the right route for this row. At most
 * one dialog is open per session: any other use finds `asking` set and
 * routes unasked. The caller awaits it outside `safely` (it never throws).
 * `say` builds the question from the real decision, only if one is asked.
 * True when routing.json changed: the caller recomputes its route.
 */
async function confirmFirst(
  $: Api,
  st: State,
  req: Req,
  say: () => Promise<string>,
): Promise<boolean> {
  if (st.asking !== null || !wantsAsk(st, req)) return false
  st.asking = keyOf(req)
  try {
    if (!(await refreshMemory($, st)) || !wantsAsk(st, req)) return false
    return await runDialog($, st, req, await say())
  } catch (err) {
    failOnce($, st, err)
    return false
  } finally {
    st.asking = null
  }
}

/** First-use question text: the id and level the next step really gets. */
async function mainQuestion($: Api, st: State, lead: string) {
  const v = await snapshot($, st)
  return `${lead}: ${idWord(st, v.call.model)} at ${effortWord(st, v)}. OK?`
}

function spawnQuestion(
  $: Api,
  st: State,
  e: SpawnIn,
  req: Req,
  route: Route,
): string {
  const id = spawnTarget($, st, e, route) ?? 'its own model'
  const effort = st.explicitEffort.get(e.tool_use_id) ?? route.effort
  const lead = withDesc(`First dispatch of ${req.name}`,
    st.descs.get(req.name))
  return `${lead}. ${routedTo(st, req.phase)}: ${id} at ${
    effort ?? 'its own effort'}. OK?`
}

async function skillQuestion($: Api, st: State, skill: string, phase: string) {
  const head = withDesc(`First route for /${skill}`, await skillDesc($, skill))
  return mainQuestion($, st, `${head}. ${routedTo(st, phase)}`)
}

/** A downgrade the switch or the cold-read cap holds back, said. */
function downgradeHint(st: State, v: Verdict, cur: string): string {
  const { wanted, call } = v
  if (wanted === undefined) return ''
  if (ranksAbove(st, wanted, canonical(st.cfg, cur))) return ''
  if (call.why === 'switch off') {
    return ', main moves up only: /route switch on allows a downgrade'
  }
  return call.why.startsWith('downgrade skipped') ? `, held: ${call.why}` : ''
}

/** After a Change: what main will really run, and the switch hint. */
async function toastChange($: Api, st: State, skill: string) {
  const cur = st.turnModel ?? st.sessionModel
  const v = await decideFor($, st, cur)
  const hint = downgradeHint(st, v, cur)
  $.ui.toast(`/${skill} now runs ${idWord(st, v.call.model)} at ${
    effortWord(st, v)}${hint}`)
}

/** Typed skill: a changed row re-routes the turn at once. */
async function confirmSkill($: Api, st: State, skill: string, row: Picked) {
  const req: Req = { kind: 'skills', name: skill, phase: row.phase }
  const say = () => skillQuestion($, st, skill, row.phase)
  if (!(await confirmFirst($, st, req, say))) return
  const after = skillRow(st, skill)
  if (after === undefined) return
  routeMainBySkill(st, skill, after, true)
  refresh($, st)
  if (after.phase !== row.phase) await toastChange($, st, skill)
}

/** Rowed spawn: the route in force after the dialog (changed or not). */
async function routeSpawn($: Api, st: State, e: SpawnIn) {
  const frozen = e.fork || e.workflow !== undefined
  const route = spawnRoute(st, e, frozen)
  const phase = hasKey(st.cfg.agents, e.subagentType)
    ? st.cfg.agents[e.subagentType]
    : undefined
  const inside = e.parentAgentId !== undefined || e.model !== undefined
  if (!route || !phase || inside) return route
  const req: Req = { kind: 'agents', name: e.subagentType, phase }
  const say = async () => spawnQuestion($, st, e, req, route)
  return (await confirmFirst($, st, req, say))
    ? spawnRoute(st, e, frozen)
    : route
}

/** A phase declared through the route tool: confirm-only. */
async function confirmPhase($: Api, st: State, phase: string) {
  const req: Req = { kind: 'phases', name: phase, phase }
  const meaning = [aboutLine(st, phase), consumers(st, phase)]
    .filter(part => part !== undefined).join('; ')
  const lead = `First use of ${phase} on the main loop — ${meaning}`
  await confirmFirst($, st, req, () => mainQuestion($, st, lead))
}

// ---- first-use commands ----------------------------------------------

/** Rows and phases not confirmed yet, those asked this session first. */
function pendingText(st: State): string {
  const m = st.mem
  if (!m.ok) return `${ROUTING} missing or unreadable: nothing to confirm`
  const names = (kind: Kind): string[] => Object.keys(
    kind === 'phases' ? st.cfg.phases : m.base[kind])
    .filter(name => !isDecided(m, kind, name))
  const all = KINDS.flatMap(kind => names(kind).map(name => ({ kind, name })))
    .map(keyOf)
  const asked = all.filter(k => st.asked.has(k))
  const rest = all.filter(k => !st.asked.has(k))
  return [
    `pending confirmation: ${all.length}` +
      (m.ask ? '' : ' (asking is off: /route ask on)'),
    `asked this session: ${asked.join(' ') || 'none'}`,
    `not asked yet: ${rest.join(' ') || 'none'}`,
  ].join('\n')
}

async function askCommand($: Api, st: State, arg: string | undefined) {
  if (arg !== 'on' && arg !== 'off') return 'usage: /route ask on|off'
  const patch: Patch = file => { file.ask = arg === 'on' }
  try {
    if (!(await writeRouting($, st, patch))) {
      return `${ROUTING} missing or unreadable: ask unchanged`
    }
  } catch (err) {
    return err instanceof RebuildFailed
      ? 'ask saved, config not rebuilt: /route reload'
      : failedWrite($, 'ask', err)
  }
  const local = st.mem.askLocal
  const note = local === undefined ? '' : `; ~/${OVERRIDE} sets ask ${
    local ? 'on' : 'off'} and wins here`
  return `ask ${arg}${note}`
}

// ---- /route forget: the user takes decisions back -------------------------
// Removes `confirmed` and `projects` entries and restores a `changed` row to
// its shipped phase. The frontmatter floors are never touched. `all` and
// `projects` ask first. Reserved words: a row named like them is edited by
// hand.

type Target = { label: string; name?: string; only?: 'projects' }
type Restore = { kind: Kind; name: string; from: string; to: string }
type Kept = { kind: Kind; name: string; reason: string }
type ForgetPlan = {
  confirmed: [Kind, string][]
  restores: Restore[]
  kept: Kept[] // refused restores, with the reason
  projects: [string, Kind, string][] // repo key, kind, name
}

const REFUSED = 'forget refused: nothing saved'
const FORGET_USAGE = 'usage: /route forget <name|all|projects>'
const BUILTIN_AGENTS: ReadonlySet<string> = new Set(['Explore', 'Plan'])
const isKind = (v: string): v is Kind => KINDS.some(kind => kind === v)

function targetOf(arg: string): Target {
  if (arg === 'all') return { label: 'all' }
  if (arg === 'projects') return { label: 'projects', only: 'projects' }
  return { label: arg, name: arg }
}

/** The [kind, name, value] entries of a kind-keyed table the target picks. */
function decided(
  tables: unknown,
  t: Target,
  kinds: readonly Kind[] = KINDS,
): [Kind, string, unknown][] {
  if (!isRecord(tables)) return []
  return Object.entries(tables).filter(([kind]) => isKind(kind) &&
    kinds.includes(kind))
    .flatMap(([kind, rows]) => isRecord(rows) ? Object.keys(rows)
      .filter(name => t.name === undefined || name === t.name)
      .map(name => [kind as Kind, name, rows[name]] as [Kind, string, unknown])
      : [])
}

/** A fragment read from the file, as it may enter an answer. */
const shown = (text: string): string => clean(text, NAME_CAP)

const keptText = (k: Kept): string => `${k.kind}.${shown(k.name)}: ${k.reason}`
const keptList = (plan: ForgetPlan): string =>
  plan.kept.map(keptText).join('; ')

/** The restore a `changed` entry allows, or why it is refused. */
function restoreOf(
  file: Rec,
  kind: Kind,
  name: string,
  entry: unknown,
): Restore | string {
  const { from, to } = isRecord(entry) ? entry : ({} as Rec)
  if (!goodKey(name)) return 'reserved name, edit routing.json'
  if (typeof from !== 'string') return 'no phase recorded to return to'
  const rows = subRec(file, kind)
  if (typeof to !== 'string' || !hasKey(rows, name) || rows[name] !== to) {
    return 'the row differs from the recorded change, edit routing.json'
  }
  if (!hasKey(subRec(file, 'phases'), from) &&
      !hasKey(DEFAULT_CONFIG.phases, from)) {
    return `${shown(from)} is not a known phase`
  }
  return { kind, name, from, to }
}

/** What the target removes from this file, and what it must keep. */
function forgetPlan(file: Rec, t: Target): ForgetPlan {
  const plan: ForgetPlan = {
    confirmed: [], restores: [], kept: [], projects: [],
  }
  if (t.only !== 'projects') {
    for (const [kind, name] of decided(file.confirmed, t)) {
      plan.confirmed.push([kind, name])
    }
    for (const [kind, name, entry] of decided(file.changed, t, ROWS)) {
      const done = restoreOf(file, kind, name, entry)
      if (typeof done === 'string') plan.kept.push({ kind, name, reason: done })
      else plan.restores.push(done)
    }
  }
  const repos = isRecord(file.projects) ? file.projects : {}
  for (const [repo, tables] of Object.entries(repos)) {
    for (const [kind, name] of decided(tables, t)) {
      plan.projects.push([repo, kind, name])
    }
  }
  return plan
}

const removals = (plan: ForgetPlan): number =>
  plan.confirmed.length + plan.restores.length + plan.projects.length
const repoCount = (plan: ForgetPlan): number =>
  new Set(plan.projects.map(entry => entry[0])).size

/** Deletes one entry; an emptied kind table goes with it. */
function dropEntry(parent: Rec, kind: string, name: string): void {
  const rows = subRec(parent, kind)
  delete rows[name]
  if (Object.keys(rows).length === 0) delete parent[kind]
}

function applyPlan(file: Rec, plan: ForgetPlan): void {
  const changed = subRec(file, 'changed')
  const projects = subRec(file, 'projects')
  for (const [kind, name] of plan.confirmed) {
    dropEntry(subRec(file, 'confirmed'), kind, name)
  }
  for (const r of plan.restores) {
    setKey(subRec(file, r.kind), r.name, r.from)
    dropEntry(changed, r.kind, r.name)
  }
  for (const [repo, kind, name] of plan.projects) {
    const mine = subRec(projects, repo)
    dropEntry(mine, kind, name)
    if (Object.keys(mine).length === 0) delete projects[repo]
  }
}

/** Keys of this session's asked set the target covers. */
function askedKeys(st: State, t: Target): string[] {
  if (t.only === 'projects') return []
  if (t.name === undefined) return [...st.asked]
  const name = t.name
  return KINDS.map(kind => keyOf({ kind, name })).filter(k => st.asked.has(k))
}

/** The machine override still sets the row: no forget reaches it. */
function heldBy(st: State, t: Target): string | undefined {
  const name = t.name
  if (name === undefined) return undefined
  return ROWS.some(kind => hasKey(strTable(st.override?.[kind]), name))
    ? `~/${OVERRIDE}`
    : undefined
}

/** The answer when nothing is written, or undefined when there is work. */
function idleAnswer(
  st: State,
  t: Target,
  plan: ForgetPlan,
): string | undefined {
  if (removals(plan) > 0) return undefined
  if (plan.kept.length > 0) {
    return `nothing restored for ${t.label}: ${keptList(plan)}`
  }
  const keys = askedKeys(st, t)
  if (keys.length === 0) {
    return t.name === undefined ? 'nothing to forget'
      : `nothing to forget for ${t.name}`
  }
  keys.forEach(key => st.asked.delete(key))
  const held = heldBy(st, t)
  return `${t.label}: ${held === undefined
    ? 'asked again at the next use'
    : `still decided by ${held}`}, nothing was saved`
}

async function confirmForget($: Api, plan: ForgetPlan): Promise<boolean> {
  const text = `Forget ${plural(removals(plan), 'decision')}: ` +
    `${plan.restores.length} row(s) restored, ${plan.projects.length} ` +
    `project exception(s) in ${plural(repoCount(plan), 'repo')}?`
  return (await askOr($, text, ['Cancel', 'Forget'])) === 'Forget'
}

/** Where a restored row's frontmatter lives; none for a built-in agent. */
function floorFile(r: Restore): string | undefined {
  if (!SKILL_NAME.test(r.name)) return undefined
  if (r.kind === 'skills') return `skills/${r.name}/SKILL.md`
  return r.kind === 'agents' && !BUILTIN_AGENTS.has(r.name)
    ? `agents/${r.name}.md`
    : undefined
}

function restoreClause(st: State, r: Restore): string {
  const route = phaseRoute(st.cfg, r.from) ?? phaseRoute(DEFAULT_CONFIG, r.from)
  const alias = (route && headAlias(DEFAULT_CONFIG, route)) ?? 'its own model'
  const values = `${alias} at ${route?.effort ?? 'its own effort'}`
  const file = floorFile(r)
  const effort = route?.effort ?? '-'
  const realign = file === undefined ? '' : `; if ${file} was aligned to ${
    shown(r.to)}, set model: ${alias}, effort: ${effort} and its lock in ` +
    'lib/tests/model-routing.test.sh, then `make test`'
  const row = `${r.kind}.${shown(r.name)} → ${shown(r.from)}`
  return ` (${row}: ${values}${realign})`
}

/** Restored skill rows whose old phase the current run still holds. */
function runKeeps(st: State, plan: ForgetPlan): string {
  const live = [st.runMain, st.turnMain].filter(slot =>
    slot !== null && (slot.source === 'run' || slot.source === 'skill'))
  const kept = plan.restores.find(r => r.kind === 'skills' &&
    live.some(slot => slot?.phase === r.to))
  return kept === undefined ? '' :
    `; current run may keep ${shown(kept.to)}: /route clear to apply`
}

/** The one answer of every form, from the counts really applied. */
function forgetAnswer(st: State, t: Target, plan: ForgetPlan): string {
  const kept = plan.kept.length === 0 ? '' :
    `, ${plan.kept.length} restore(s) kept: ${keptList(plan)}`
  const name = t.name
  const wins = name !== undefined &&
    ROWS.some(kind => st.mem.local[kind].has(name))
    ? `; ~/${OVERRIDE} still sets ${name} and wins here`
    : ''
  return `forgot ${t.label}: ${plan.confirmed.length} confirmed, ${
    plan.restores.length} row(s) restored, ${plan.projects.length} project ` +
    `exception(s) removed${kept}` +
    plan.restores.map(r => restoreClause(st, r)).join('') + wins +
    runKeeps(st, plan) + '; other live sessions see it after /route reload'
}

/** One writer patch; the plan is recomputed on the file it really holds. */
async function forgetWrite($: Api, st: State, t: Target, seen: ForgetPlan) {
  const out: { plan?: ForgetPlan } = {}
  const patch: Patch = file => {
    out.plan = forgetPlan(file, t)
    applyPlan(file, out.plan)
  }
  try {
    if (!(await writeRouting($, st, patch))) return REFUSED
  } catch (err) {
    return err instanceof RebuildFailed
      ? 'saved, config not rebuilt: /route reload'
      : failedWrite($, 'forget', err)
  }
  askedKeys(st, t).forEach(key => st.asked.delete(key))
  return forgetAnswer(st, t, out.plan ?? seen)
}

/** A row or phase called `all` or `projects` cannot be reached by name. */
function reservedNote(file: Rec, t: Target): string {
  if (t.name !== undefined) return ''
  const clash = KINDS.some(kind => hasKey(subRec(file, kind), t.label))
  return clash ? `; a row or phase named ${t.label} is reserved here: ` +
    `edit ${ROUTING} by hand` : ''
}

async function forgetFlow($: Api, st: State, t: Target): Promise<string> {
  await st.writes
  const file = await readRouting($, text => $.ui.log(text))
  if (typeof file === 'string') {
    return `${ROUTING} is missing or unreadable: nothing saved`
  }
  const plan = forgetPlan(file.data, t)
  const idle = idleAnswer(st, t, plan)
  const note = reservedNote(file.data, t)
  if (idle !== undefined) return idle + note
  if (t.name === undefined && !(await confirmForget($, plan))) {
    return `forget ${t.label} cancelled, nothing written` + note
  }
  return (await forgetWrite($, st, t, plan)) + note
}

/** The forget holds the single-dialog slot: no first-use dialog under it. */
async function forgetCommand($: Api, st: State, args: string[]) {
  if (args.length !== 1) return FORGET_USAGE
  if (st.asking !== null) return 'answer the open dialog first'
  const target = targetOf(args[0] ?? '')
  st.asking = `forget:${target.label}`
  try {
    return await forgetFlow($, st, target)
  } finally {
    st.asking = null
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
        'The main loop moves up or down to a phase\'s tier while the cold ' +
        'read it costs fits the cap (down also needs the switch on); a ' +
        'sub-agent\'s model is fixed at spawn. ' +
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
    $.ui.log(`model-router: route tool not registered: ${errWord(err)}`)
  }
}

async function registerCommand($: Api): Promise<void> {
  try {
    await $.command.register({
      name: 'route',
      description: 'model-router: show or set the model and effort route',
      argumentHint:
        '[show|clear|off|on|reload|pending|ask on|off|' +
        'forget <name|all|projects>|<phase>|' +
        'model=<alias|id> effort=<level>|switch on|off|verbose on|off|' +
        'classify on|off]',
      immediate: true,
    })
  } catch (err) {
    $.ui.log(`model-router: /route not registered: ${errWord(err)}`)
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
  const explicit = isLevel(effort) ? { explicitEffort: true } : {}
  return { phase: name, route, ...explicit }
}

function applyRoute(st: State, agentId: string | undefined, p: Picked): void {
  if (agentId === undefined) {
    st.turnMain = { phase: p.phase, route: p.route, source: 'model',
      ...(p.explicitEffort ? { explicitEffort: true } : {}) }
  } else {
    writeLoop(loopOf(st, agentId), p.route, 'route tool')
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
  if (loop) writeLoop(loop, {}, 'route tool')
  return 'route cleared for this agent'
}

/** Main's answer: effort and model asked, the sticky/floor note appended. */
async function mainRoutedText($: Api, st: State, p: Picked) {
  const v = await snapshot($, st)
  const d = standInEffort(st, mainEffort(st, undefined), v)
  const effort = d.standIn
    ? `${String(d.effort)} (${standInWord(st, v)})`
    : p.route.effort ?? 'unchanged'
  const base = `routed main to ${p.phase}: effort ${effort}, model ${
    idWord(st, v.call.model)} (${v.call.why})`
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
  if (e.agentId === undefined && typeof e.phase === 'string') {
    await confirmPhase($, st, picked.phase)
  }
  return { result: await routedText($, st, e.agentId, picked) }
}

// ---- skills ----------------------------------------------------------

/** A skill's table row: its phase and that phase's route, if both exist. */
function skillRow(st: State, skill: string): Picked | undefined {
  const phase = hasKey(st.cfg.skills, skill) ? st.cfg.skills[skill] : undefined
  const route = phase === undefined ? undefined : phaseRoute(st.cfg, phase)
  return phase !== undefined && route ? { phase, route } : undefined
}

/** The run slot's model outranks the route's: a helper moves effort only. */
function belowRun(st: State, route: Route): boolean {
  const mine = resolveRoute(st, route)
  const run = resolveRoute(st, st.runMain?.route)
  return mine !== undefined && run !== undefined && ranksAbove(st, run, mine)
}

/**
 * A rowed skill on main sets the turn route; a best-tier row also holds the
 * run slot. A typed non-best row drops the run; one the model loads (a
 * helper skill inside a run) leaves it.
 */
function routeMainBySkill(
  st: State,
  skill: string,
  row: Picked,
  typed: boolean,
): void {
  const route = !typed && belowRun(st, row.route)
    ? { effort: row.route.effort }
    : { ...row.route }
  const turn: Routed = { phase: row.phase, route,
    source: 'skill', label: clean(skill, NAME_CAP) }
  st.turnMain = turn
  if (row.route.tier === BEST) st.runMain = { ...turn, source: 'run' }
  else if (typed) st.runMain = null
}

/** A model-loaded skill: its row applies; an unrowed one changes nothing. */
function onSkillLoad(st: State, skill: string, agentId: string | undefined) {
  const row = skillRow(st, skill)
  if (agentId === undefined) {
    if (row) routeMainBySkill(st, skill, row, false)
    return
  }
  if (row) writeLoop(loopOf(st, agentId), row.route, `skill ${clean(skill, NAME_CAP)}`)
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

type Armed = { row: Picked | undefined; typed: boolean }

/**
 * Routes main by the typed skill's row; the row, for the first-use ask, and
 * whether the user typed the skill (rowed or not: its body is theirs).
 */
function armTypedSkill($: Api, st: State, skill: string): Armed {
  const row = skillRow(st, skill)
  const typed = typedPath(st, skill) !== undefined
  if (row === undefined || !typed) return { row: undefined, typed }
  routeMainBySkill(st, skill, row, true)
  refresh($, st)
  return { row, typed }
}

/** Bookkeeping that may fail without breaking the hook: fail-open. */
function armed($: Api, st: State, skill: string): Armed {
  try {
    return armTypedSkill($, st, skill)
  } catch {
    warnOnce(st, $, 'skill.prompt', 'bookkeeping')
    return { row: undefined, typed: false }
  }
}

// ---- agents ----------------------------------------------------------

type SpawnIn = {
  tool_use_id: string
  subagentType: string
  model?: string
  parentAgentId?: string // set when the spawn happens inside an agent
  parentModel?: string // the model the spawning loop runs on
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
  const text = `model-router: ${keyWord(agent)} tier ${tier} down, ` +
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

/**
 * A built-in inheriting type spawned by main while main sits below the
 * session model (a demotion or a breaker fallback) would inherit that lower
 * model: it starts on the session model instead. Forks and workflows are
 * frozen, a nested spawn inherits an agent's model, never main's, and a
 * shadowing project or user definition may carry its own frontmatter model.
 */
function sessionPin(st: State, e: SpawnIn): string | undefined {
  const turn = st.turnModel
  const inherits = INHERITING_AGENTS.has(e.subagentType) &&
    st.offers.get(e.subagentType) === 'built-in'
  const main = !e.fork && e.workflow === undefined &&
    e.parentAgentId === undefined
  if (turn === undefined || st.sessionModel === '' || !inherits || !main) {
    return undefined
  }
  const session = canonical(st.cfg, st.sessionModel)
  const demoted = ranksAbove(st, session, canonical(st.cfg, turn))
  return demoted && !st.down.has(session) ? st.sessionModel : undefined
}

/** The model a spawn is rewritten to; an explicit `model` param wins. */
function spawnTarget($: Api, st: State, e: SpawnIn, route: Route | undefined) {
  if (e.model !== undefined) return undefined
  if (route === undefined) return sessionPin(st, e)
  if (route.tier === undefined) return resolveRoute(st, route)
  return inTier($, st, e.subagentType, route.tier)
}

/** Spawn facts the bookkeeping after the engine started the agent needs. */
type Spawned = {
  e: SpawnIn
  started: { agentId?: unknown; model: string }
  route: Route | undefined // the row's route in force, if any
  wanted: string | undefined // the model the hook asked for, if it did
}

/** Who set a new agent's effort: the Agent call, its row, or the engine. */
function spawnEffortCause(given: Level | undefined, route: Route | undefined) {
  if (given !== undefined) return 'explicit'
  return route?.effort === undefined ? 'engine' : 'row'
}

function trackLoop(
  st: State,
  sp: Spawned,
  agentId: string,
  given: Level | undefined,
): Loop {
  const loop: Loop = {
    explicitEffort: given !== undefined,
    effort: given ? undefined : sp.route?.effort,
    type: sp.e.subagentType,
    cause: spawnEffortCause(given, sp.route),
  }
  st.loops.set(agentId, loop)
  return loop
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
  for (const key of st.logged) {
    if (key.startsWith(`answered:${agentId}:`)) st.logged.delete(key)
  }
  const awaited = st.pushed?.spawnIds
  if (awaited?.delete(agentId) && awaited.size === 0) popOrchestrate(st)
}

// ---- transition logs -----------------------------------------------------
// `verbose` says WHEN a loop changes model or effort, with a few words of
// cause; a step that changes nothing logs nothing.

const NAME_CAP = 40 // code points of any name read from outside, in a line

const isHaiku = (cfg: Config, id: string): boolean =>
  canonical(cfg, id).startsWith(HAIKU)

/** The table alias of a model id (a `[1m]` marker kept), else the id. */
function nameOf(cfg: Config, id: string): string {
  const bare = canonical(cfg, id)
  const marker = ONE_M.test(id) ? '[1m]' : ''
  return clean((aliasOf(cfg, bare) ?? bare) + marker, NAME_CAP)
}

/** "alias/effort": a plan in a log line. */
const planWord = (cfg: Config, plan: Plan): string =>
  `${nameOf(cfg, plan.model)}/${String(plan.effort ?? '-')}`

/** Logged at `true` only, and once per turn per `key` (default: text). */
function turnLine($: Api, st: State, text: string, key = text): void {
  if (!st.cfg.verbose || st.turnLogged.has(key)) return
  st.turnLogged.add(key)
  vlog($, st, text)
}

const agentLabel = (st: State, agentId: string): string =>
  `agent ${clean(st.loops.get(agentId)?.type ?? agentId.slice(0, 8), NAME_CAP)}`

/** The route slot a main effort came from, in words. */
function slotWord(slot: Routed | null): string {
  const label = slot?.label === undefined ? '' : ` /${slot.label}`
  switch (slot?.source) {
    case 'model': return 'route tool'
    case 'prompt': return 'prompt rule'
    case 'derived': return 'dispatch'
    case 'classifier': return 'classifier'
    case 'skill':
    case 'run': return 'skill' + label
    default: return 'session'
  }
}

type Cause = { phase?: string; word: string }

/** Who supplied main's effort: the phase of that slot, and a few words. */
function effortCause(st: State, by: EffortBy): Cause {
  if (by === 'floor') {
    return { phase: st.turnFloor?.phase, word: 'prompt floor' }
  }
  if (by === 'sticky') {
    return { phase: st.userMain?.phase, word: 'sticky /route' }
  }
  if (by === 'engine') return { phase: mainRoute(st)?.phase, word: 'session' }
  const named = st.turnMain?.route.effort === undefined
    ? st.runMain
    : st.turnMain
  return { phase: named?.phase, word: slotWord(named) }
}

/** Why the model moved, when it did. */
function modelCause(st: State, why: Why): string | undefined {
  const { call, cur } = why
  if (!call.moved) return undefined
  if (call.why === 'upgrade') return 'upgrade'
  if (call.why === 'downgrade') return 'switch'
  if (call.why === 'window') return 'window'
  return `fallback: ${nameOf(st.cfg, cur)} down`
}

/** "main: a → b (phase: cause[, model cause])", or none when unchanged. */
function mainMove(
  st: State,
  from: Plan,
  step: Step,
): string | undefined {
  const [was, now] = [planWord(st.cfg, from), planWord(st.cfg, step.plan)]
  if (step.why === undefined || was === now) return undefined
  const { phase, word } = effortCause(st, step.why.by)
  const standIn = step.why.standIn ? 'stand-in' : undefined
  const causes = [word, standIn, modelCause(st, step.why)]
    .filter(c => c !== undefined)
  const lead = phase === undefined ? '' : `${clean(phase, NAME_CAP)}: `
  return `main: ${was} → ${now} (${lead}${causes.join(', ')})`
}

/** "agent x: a → b (cause)": a later move; the loop remembers `plan`. */
function agentMove(st: State, e: StepIn, plan: Plan): string | undefined {
  const id = e.agentId
  const loop = id === undefined ? undefined : st.loops.get(id)
  if (id === undefined) return undefined
  const from = loop?.last ?? { model: e.model, effort: e.effort }
  if (loop) loop.last = plan
  const [was, now] = [planWord(st.cfg, from), planWord(st.cfg, plan)]
  return was === now
    ? undefined
    : `${agentLabel(st, id)}: ${was} → ${now} (${
      loop?.cause ?? 'engine'})`
}

/** The step's transition line; `prev` is main's plan before this step. */
function logMove(
  $: Api,
  st: State,
  e: StepIn,
  prev: Plan | null,
  step: Step,
): void {
  const line = e.agentId === undefined
    ? mainMove(st, prev ?? { model: e.model, effort: e.effort }, step)
    : agentMove(st, e, step.plan)
  if (line !== undefined) turnLine($, st, line)
}

/** An agent answered on a model other than the planned one: said once. */
function logAnswer(
  $: Api,
  st: State,
  agentId: string | undefined,
  plan: Plan,
  usage: { model: string } | null | undefined,
): void {
  if (agentId === undefined || !st.cfg.verbose || !usage) return
  const got = canonical(st.cfg, usage.model)
  const key = `answered:${agentId}:${got}`
  if (got === canonical(st.cfg, plan.model) || st.logged.has(key)) return
  st.logged.add(key)
  vlog($, st, `${agentLabel(st, agentId)} answered by ${
    nameOf(st.cfg, got)} instead of ${nameOf(st.cfg, plan.model)}`)
}

type Handoff = { to: Plan; modelCause: string; effortCause: string }

/** Why an agent runs on the model it was sent to. */
function spawnModelCause(st: State, sp: Spawned): string {
  const { e, route, wanted } = sp
  if (e.model !== undefined) return 'explicit'
  if (route === undefined && wanted !== undefined) return 'session'
  if (route === undefined || wanted === undefined) return 'frontmatter'
  const head = headAlias(st.cfg, route)
  const lead = head === undefined ? undefined : st.cfg.models[head]
  const phase = clean(st.cfg.agents[e.subagentType] ?? '', NAME_CAP)
  return route.tier !== undefined && lead !== wanted
    ? `fallback: ${nameOf(st.cfg, head ?? '')} down`
    : `row ${phase}`
}

/** What a dispatch hands the agent, or undefined when nothing was given. */
function handoffOf(
  st: State,
  sp: Spawned,
  given: Level | undefined,
): Handoff | undefined {
  const { e, route, started } = sp
  const pinned = sp.wanted !== undefined
  if (route === undefined && e.model === undefined && given === undefined &&
    !pinned) {
    return undefined
  }
  const effort = isHaiku(st.cfg, started.model)
    ? undefined
    : given ?? route?.effort
  return {
    to: { model: started.model, effort },
    modelCause: spawnModelCause(st, sp),
    effortCause: spawnEffortCause(given, route),
  }
}

/** "main a → agent x b (model cause, effort cause)": the dispatch itself. */
function handoffLine(st: State, e: SpawnIn, hand: Handoff): string {
  const parent = e.parentAgentId
  const lead = parent === undefined ? 'main' : agentLabel(st, parent)
  const known = parent === undefined
    ? st.lastPlan
    : st.loops.get(parent)?.last
  const from = known ?? { model: e.parentModel ?? st.sessionModel,
    effort: undefined }
  return `${lead} ${planWord(st.cfg, from)} → agent ${
    clean(e.subagentType, NAME_CAP)} ${planWord(st.cfg, hand.to)} (${
    hand.modelCause}, ${hand.effortCause})`
}

// ---- turn steps ------------------------------------------------------

function agentPlan(st: State, e: StepIn): Plan {
  const loop = e.agentId === undefined ? undefined : st.loops.get(e.agentId)
  return { model: e.model, effort: loop?.effort ?? e.effort }
}

/** What a main plan was decided from: the log words are built from it. */
type Why = { by: EffortBy; call: Call; cur: string; standIn: boolean }
type Step = { plan: Plan; why?: Why; aborted?: boolean }

/** The engine effort of this turn's first main step: the user's default. */
function noteEngineBase(st: State, e: StepIn): void {
  if (st.turnEngine === null && e.effort !== undefined) {
    st.turnEngine = e.effort
  }
}

/**
 * A user /effort beats a guessed phase: this turn's engine effort differs
 * from the previous turn's, typed between the two.
 */
function userMovedEffort(st: State): boolean {
  return st.turnMain?.source === 'classifier' && st.turnEngine !== null &&
    st.engineBase !== null && st.turnEngine !== st.engineBase
}

/** Main ran `plan` at `read`: that model's cache holds this context now. */
function noteServed(st: State, plan: Plan, read: Reading): void {
  const id = canonical(st.cfg, plan.model)
  if (read.tokens === undefined || aliasOf(st.cfg, id) === undefined) return
  st.served.set(id, { at: read.now, tokens: read.tokens })
}

/**
 * The downgrade skip is said once per cap crossing: it stays quiet until a
 * downgrade succeeds. Returns the call the log line is taken from.
 */
function capLogged(st: State, call: Call): Call {
  if (call.why === 'downgrade') st.capSaid = false
  if (!call.why.startsWith('downgrade skipped')) return call
  const said = st.capSaid
  st.capSaid = true
  if (!said) return call
  const { log: _log, logKey: _key, ...quiet } = call
  return quiet
}

/**
 * The main loop's plan: effort from the floor/sticky/turn decision, model
 * from `decideMain`. `cur` is the model the router moved this turn, else
 * the engine's own (verbatim: an engine fallback is respected). Every step
 * reads the context and the clock and records the model it ran on.
 */
async function mainPlan(
  $: Api,
  st: State,
  e: StepIn,
  signal: AbortSignal,
): Promise<Step> {
  noteEngineBase(st, e)
  if (userMovedEffort(st)) st.turnMain = null
  const base = mainEffort(st, e.effort)
  await prune($, st)
  const cur = st.turnModel ?? e.model
  const raw = await readTokens($)
  const now = await $.clock.now()
  const v = await decideFor($, st, cur, { tokens: withEstimate(st, raw), now })
  const { call } = v
  const { effort, by, standIn } = standInEffort(st, base, v)
  logCall($, st, capLogged(st, call))
  const step = { plan: { model: call.model, effort },
    why: { by, call, cur, standIn } }
  // Esc during a probe: the mark stands, but the abandoned step records
  // nothing a later step would read as what main ran
  if (signal.aborted) return { ...step, aborted: true }
  if (call.moved) st.turnModel = call.model
  // the record stays raw: an estimate in it would trip the compaction path
  noteServed(st, { model: call.model, effort }, { tokens: raw, now })
  st.promptEstimate = null // consumed by the turn's first main step
  return step
}

async function planStep(
  $: Api,
  st: State,
  e: StepIn,
  signal: AbortSignal,
): Promise<Step> {
  const step: Step = e.agentId === undefined
    ? await mainPlan($, st, e, signal)
    : { plan: agentPlan(st, e) }
  // Haiku takes no effort: omit it rather than send a hook-set value.
  return step.plan.model.startsWith(HAIKU)
    ? { ...step, plan: { ...step.plan, effort: undefined } }
    : step
}

function withPlan(e: StepIn, plan: Plan): StepIn {
  const { effort: _replaced, ...rest } = e
  const base = { ...rest, model: plan.model }
  return plan.effort === undefined ? base : { ...base, effort: plan.effort }
}

function noteMain($: Api, st: State, plan: Plan): void {
  st.lastPlan = plan
  st.spinner = `${plan.model.replace(/^claude-/, '')}/${plan.effort ?? '-'}`
  safely(st, $, 'turn.step status', () => refresh($, st))
}

/**
 * An estimate no step consumed, and one typed mid-turn, carry to the next
 * turn with their baseline reset: added at its first step, never dropped.
 */
function carryEstimate(st: State): void {
  const left = [st.promptEstimate, st.pendingEstimate]
    .filter((x): x is Estimate => x !== null)
  const sum = left.reduce<Estimate | null>(
    (acc, x) => sumEstimate(acc, x.tokens, undefined, x.unknown), null)
  st.promptEstimate = sum
  st.pendingEstimate = null
}

function endMainTurn($: Api, st: State): void {
  carryEstimate(st)
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
  if (st.turnEngine !== null) st.engineBase = st.turnEngine
  st.turnEngine = null
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
  cache_ttl?: unknown
  agent_id?: unknown // set when a sub-agent's model switched
}

/** The engine's `cache_ttl` in ms, or undefined for any other value. */
const ttlOf = (v: unknown): number | undefined =>
  typeof v === 'string' && hasKey(CACHE_TTLS, v) ? CACHE_TTLS[v] : undefined

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

/**
 * Any model change: keeps `sessionModel` and the cache TTL (main's own
 * switches only); a user choice clears its mark.
 */
async function onModelSwitch($: Api, st: State, e: SwitchIn): Promise<void> {
  if (e.agent_id === undefined) {
    st.sessionModel = e.to_model
    st.cacheTtlMs = ttlOf(e.cache_ttl) ?? st.cacheTtlMs
  }
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

function registerCwd(on: On, st: State): void {
  on('classic.CwdChanged', async ($, e, next) => {
    // the repo key follows the directory: rebuild the layers
    if (st.loaded) await reloadConfig($, st)
    return next(e)
  }).catch(($, e, next) => {
    warnOnce(st, $, 'CwdChanged', next.error.kind)
    return next(e)
  })
}

function registerCommandHook(on: On, st: State): void {
  on('command.run', { command: 'route' }, async ($, e) => {
    if (e.origin.kind !== 'composer') {
      return { text: 'route: user-only command' }
    }
    await ensureConfig($, st)
    return { text: await handleCommand($, st, e.args) }
  }).catch(($, e, next) => {
    warnOnce(st, $, 'command.run', next.error.kind)
    return { text: `route failed (${next.error.kind})` }
  })
}

function registerRouteTool(on: On, st: State): void {
  on('tool.call', { tool: TOOL }, async ($, e) => {
    await ensureConfig($, st)
    const out = await handleRouteTool($, st, e)
    refresh($, st)
    return out
  }).catch(($, e, next) => {
    warnOnce(st, $, 'route tool', next.error.kind)
    return { result: `route failed (${next.error.kind}); ` +
      'the route may be partly applied, check /route show' }
  })
}

function registerSkills(on: On, st: State): void {
  on('tool.call', { tool: 'Skill' }, async ($, e, next) => {
    await ensureConfig($, st)
    const skill = typeof e.skill === 'string' ? e.skill : undefined
    if (st.off || skill === undefined) return next(e)
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
    await ensureConfig($, st)
    if (st.off || st.skillCalls > 0) return next(e)
    const { row, typed } = armed($, st, e.skill)
    if (typed) {
      const size = { points: pointsOf([e.text]), unknown: false }
      await addEstimate($, st, size, false)
    }
    if (row) await confirmSkill($, st, e.skill, row)
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
function afterSpawn($: Api, st: State, sp: Spawned): void {
  if (typeof sp.started.agentId !== 'string') return
  const agentId = sp.started.agentId
  safely(st, $, 'agent.spawn', () => {
    const given = st.explicitEffort.get(sp.e.tool_use_id)
    st.explicitEffort.delete(sp.e.tool_use_id)
    const loop = trackLoop(st, sp, agentId, given)
    rememberAgent(st, agentId, sp.started.model)
    const hand = handoffOf(st, sp, given)
    if (hand === undefined) return
    // an effort the engine picks is unknown here: the first step tells it
    if (hand.effortCause !== 'engine' || isHaiku(st.cfg, hand.to.model)) {
      loop.last = hand.to
    }
    if (!st.cfg.verbose) return
    const key = `handoff:${sp.e.subagentType}:${planWord(st.cfg, hand.to)}`
    turnLine($, st, handoffLine(st, sp.e, hand), key)
  })
}

function registerSpawn(on: On, st: State): void {
  on('agent.offer', async ($, e, next) => {
    if (!st.off) rememberOffer(st, e)
    return next(e)
  }).catch(($, e, next) => {
    warnOnce(st, $, 'agent.offer', next.error.kind)
    return next(e)
  })
  on('agent.spawn', async ($, e, next) => {
    await ensureConfig($, st)
    if (st.off) return next(e)
    st.spawning += 1
    try {
      await prune($, st)
      const route = await routeSpawn($, st, e)
      const wanted = spawnTarget($, st, e, route)
      const started = await next(wanted === undefined
        ? e
        : { ...e, model: wanted })
      afterSpawn($, st, { e, started, route, wanted })
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
    const step = await planStep($, st, e, next.signal)
    const plan = step.plan
    const changed = plan.model !== e.model || plan.effort !== e.effort
    const prev = st.lastPlan // main's last plan, before noteMain replaces it
    if (e.agentId === undefined && step.aborted !== true) {
      noteMain($, st, plan)
    }
    safely(st, $, 'turn.step log', () => logMove($, st, e, prev, step))
    const result = yield* next(changed ? withPlan(e, plan) : e)
    safely(st, $, 'turn.step', () =>
      logAnswer($, st, e.agentId, plan, result.usage))
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

// ---- prompt classifier -----------------------------------------------
// A typed prompt no rule, skill, route or floor covers is guessed by one
// small-model call: the phase's effort becomes the turn's default and its
// tier a model move DOWN only (under `mainModelSwitch` and the cold-read cap
// `downgradeMaxTokens`; never above the session model; never a dialog or a
// file write). The call is bounded and every failure leaves the prompt as
// it was.

/** The whole text up to CLASSIFY_MAX code points, else its head and tail. */
function sampleOf(text: string): string {
  const points = Array.from(text.trim())
  if (points.length <= CLASSIFY_MAX) return points.join('')
  return points.slice(0, CLASSIFY_HEAD).join('') +
    points.slice(-CLASSIFY_TAIL).join('')
}

/** No route in force on main and the classifier is on and not paused. */
const classifierIdle = (st: State): boolean =>
  !st.off && st.cfg.classify && st.classifyUntil === 0 &&
  mainRoute(st) === null && st.turnFloor === null

/** A lapsed pause ends here, before any other guard (no stale marker). */
async function expirePause($: Api, st: State): Promise<void> {
  if (st.classifyUntil === 0 || (await $.clock.now()) < st.classifyUntil) {
    return
  }
  st.classifyUntil = 0
  refresh($, st)
}

/**
 * Best effort: `$.model.classify` takes no model and runs on the engine's
 * small model, assumed to be the `haiku` alias (marked down, or main on it).
 */
async function smallModelBusy($: Api, st: State): Promise<boolean> {
  await prune($, st)
  const small = st.cfg.models.haiku
  const main = st.turnModel ?? st.sessionModel
  return (small !== undefined && st.down.has(small)) || isHaiku(st.cfg, main)
}

/** The guards of D8, in order; the text itself is checked last. */
async function classifierWanted($: Api, st: State, e: PromptIn) {
  if (!st.cfg.classify || e.origin.kind !== 'composer') return false
  if (e.turnId !== undefined) return false
  await expirePause($, st)
  const text = e.text.trim()
  if (text.startsWith('/') || Array.from(text).length < CLASSIFY_MIN) {
    return false
  }
  return classifierIdle(st) && !(await smallModelBusy($, st))
}

/** One failure; the third in a row pauses the classifier, said once. */
async function countFailure($: Api, st: State): Promise<void> {
  st.classifyFails += 1
  if (st.classifyFails < CLASSIFY_FAILS) return
  st.classifyFails = 0
  st.classifyUntil = (await $.clock.now()) + st.cfg.cooldownMinutes * 60000
  $.ui.toast(`classifier paused ${st.cfg.cooldownMinutes} min (${
    CLASSIFY_FAILS} failures)`)
  refresh($, st)
}

/** classify's own abort cause: a user interrupt, not a failure. */
const isAbort = (err: unknown): boolean =>
  err instanceof Error && (err.name === 'AbortError' ||
    /\baborted\b/i.test(err.message))

/** The label, or TIMEOUT; rejects like classify or when the dispatch aborts. */
function raceClassify($: Api, text: string, signal: AbortSignal) {
  const call = $.model.classify(sampleOf(text), CLASSIFY_LABELS)
  return raceTimeout($, call, CLASSIFY_MS, signal)
}

/** The label, or undefined: no answer, an interrupt or a counted failure. */
async function askClassifier(
  $: Api,
  st: State,
  text: string,
  signal: AbortSignal,
): Promise<string | undefined> {
  let label: string | undefined | typeof TIMEOUT
  try {
    label = await raceClassify($, text, signal)
  } catch (err) {
    if (!signal.aborted && !isAbort(err)) await countFailure($, st)
    return undefined
  }
  if (label === TIMEOUT) {
    await countFailure($, st)
    return undefined
  }
  st.classifyFails = 0
  return label
}

/** The turn route of a label: its phase's tier and effort; false = none. */
function routeFromLabel(st: State, label: string): boolean {
  const phase = hasKey(LABEL_PHASE, label) ? LABEL_PHASE[label] : undefined
  const route = phase === undefined ? undefined : phaseRoute(st.cfg, phase)
  if (phase === undefined || route?.effort === undefined) return false
  st.turnMain = { phase, route: { ...route }, source: 'classifier' }
  return true
}

/** Fills an empty route with the guessed phase's route; never throws on it. */
async function classifyPrompt(
  $: Api,
  st: State,
  e: PromptIn,
  signal: AbortSignal,
): Promise<void> {
  if (!(await classifierWanted($, st, e))) return
  const label = await askClassifier($, st, e.text, signal)
  // a route that landed meanwhile wins; a late answer never crosses turns
  if (label === undefined || signal.aborted || !classifierIdle(st)) return
  if (routeFromLabel(st, label)) refresh($, st)
}

/** What a prompt adds to the context: its text, context blocks, items. */
function promptSize(e: PromptIn): { points: number; unknown: boolean } {
  return {
    points: pointsOf([e.text, ...(e.context ?? [])]),
    unknown: (e.attachments ?? []).some(a => a.type === 'document'),
  }
}

function registerPrompt(on: On, st: State): void {
  on('prompt.submit', async ($, e, next) => {
    await ensureConfig($, st, true)
    if (st.off) return next(e)
    const midTurn = e.turnId !== undefined
    noteTyped(st, e.origin.kind, e.text, midTurn)
    await addEstimate($, st, promptSize(e), midTurn)
    if (e.origin.kind === 'composer') routeFromPrompt(st, e.text, midTurn)
    refresh($, st)
    await classifyPrompt($, st, e, next.signal)
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
  registerCwd(on, st)
  registerCommandHook(on, st)
  registerRouteTool(on, st)
  registerSkills(on, st)
  registerAgents(on, st)
  registerSpawn(on, st)
  registerTurns(on, st)
  registerPrompt(on, st)
}
