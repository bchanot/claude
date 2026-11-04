// memory: captures what fails in a session and offers it to the memory
// registries. This file is the frame: the off switch, the fail-open hooks
// and the per-session state. Every hook reads the session id and root at
// the point of use, never from a cache. A hook that fails passes the event
// through unchanged: the mod may never break a tool call or a prompt.
import type { EngineInterface, On, Register } from 'claude-code'

type Api = EngineInterface

type State = {
  enabled: boolean | null // null: not read yet this session
  warned: Set<string>
  pending: string[] // milestones not yet shown in a note
  writes: Promise<void> // the one chain every store write runs on
}

const SWITCH_FILE = '.claude/memory.json'
const MAX_SWITCH_BYTES = 65536
const TOOL = 'memory_pending'

const MAX_REGEX_INPUT = 65536
const PEM = '-----'
const PEM_KIND = '(?:[A-Z]+ )?PRIVATE KEY'

// Redaction patterns, applied in order. Repeats are bounded where the
// input is free text, so no pattern can run away on a 64 KiB input.
const REDACTIONS: [RegExp, string][] = [
  [/\b([A-Za-z_]*(?:TOKEN|API_KEY|SECRET|PASSWORD|PASSWD)[A-Za-z_]*)=\S+/gi,
    '$1=<redacted>'],
  [/sk_live_[0-9A-Za-z]{10,}/g, '<redacted:stripe>'],
  [/AKIA[0-9A-Z]{16}/g, '<redacted:aws>'],
  [/gh[pousr]_[A-Za-z0-9]{30,}/g, '<redacted:github>'],
  [/xox[abprs]-[A-Za-z0-9-]{10,}/g, '<redacted:slack>'],
  [/SG\.[A-Za-z0-9_-]{16,}\.[A-Za-z0-9_-]{16,}/g, '<redacted:sendgrid>'],
  [/sb_secret_[A-Za-z0-9_-]{10,}/g, '<redacted:supabase>'],
  [new RegExp(
    `${PEM}BEGIN ${PEM_KIND}${PEM}[\\s\\S]*?` +
      `(?:${PEM}END ${PEM_KIND}${PEM}|$)`,
    'g',
  ), '<redacted:private-key>'],
  [/\bBearer\s+[A-Za-z0-9._~+/=-]{8,}/g, 'Bearer <redacted>'],
  [/([a-z][a-z0-9+.-]{0,30}:\/\/)[^\s/@:]+:[^\s/@]+@/gi, '$1<redacted>@'],
]

const HEX_RUN = /\b[0-9a-f]{7,}\b/g
const PATH = /(?:\.{0,2}\/)?[\w.-]{1,200}(?:\/[\w.-]{1,200}){1,30}/g

/** The first `n` code units of `text` (input guard for regex work). */
export function cap(text: string, n: number): string {
  return text.slice(0, n)
}

/** The last `n` code units of `text` (the end of an output holds the error). */
export function tail(text: string, n: number): string {
  return n <= 0 ? '' : text.slice(-n)
}

/** Masks secret-shaped text; reads at most the first 64 KiB. */
export function redact(text: string): string {
  let out = cap(text, MAX_REGEX_INPUT)
  for (const [pattern, mask] of REDACTIONS) out = out.replace(pattern, mask)
  return out
}

/** A comparison key: volatile parts (hashes, paths, numbers) collapsed. */
export function normalize(line: string): string {
  return line
    .toLowerCase()
    .replace(HEX_RUN, '<hex>')
    .replace(PATH, '<path>')
    .replace(/\d+/g, '#')
    .replace(/\s+/g, ' ')
    .trim()
}

function newState(): State {
  return {
    enabled: null,
    warned: new Set(),
    pending: [],
    writes: Promise.resolve(),
  }
}

/** Logs a hook's fail-open once per session; never throws itself. */
function warnOnce(st: State, $: Api, hook: string, kind: string): void {
  if (st.warned.has(hook)) return
  st.warned.add(hook)
  try {
    $.ui.log(`memory: ${hook} hook failed (${kind}); passed through`)
  } catch {
    // a failing log must not break the fail-open itself
  }
}

/** True unless the user's switch file says `enabled: false`. */
async function loadEnabled($: Api): Promise<boolean> {
  try {
    const home = await $.env.get('HOME')
    if (!home) return true
    const path = `${home}/${SWITCH_FILE}`
    const info = await $.fs.stat(path)
    if (info.kind !== 'file' || info.size > MAX_SWITCH_BYTES) return true
    const data: unknown = JSON.parse(await $.fs.read(path))
    if (typeof data !== 'object' || data === null) return true
    return (data as { enabled?: unknown }).enabled !== false
  } catch {
    return true
  }
}

/** The tool the model calls to list the pending captures (body: later). */
async function registerTool($: Api): Promise<void> {
  try {
    await $.tool.register({
      name: TOOL,
      description:
        'List the failures and milestones captured in this project and ' +
        'not yet written to the memory registries.',
      inputSchema: { type: 'object', additionalProperties: false },
    })
  } catch {
    $.ui.log('memory: tool not registered')
  }
}

/**
 * Reads the switch on the first event of a session and caches it; each
 * read of `enabled: true` registers the tool again (a name registered
 * twice is replaced).
 */
async function ensureEnabled($: Api, st: State): Promise<boolean> {
  if (st.enabled !== null) return st.enabled
  st.enabled = await loadEnabled($)
  if (st.enabled) await registerTool($)
  return st.enabled
}

function registerSession(on: On, st: State): void {
  on('session.start', async ($, e, next) => {
    await ensureEnabled($, st)
    return next(e)
  }).catch(($, e, next) => {
    warnOnce(st, $, 'session.start', next.error.kind)
    return next(e)
  })
  on('session.end', async ($, e, next) => {
    st.enabled = null
    st.pending = []
    return next(e)
  }).catch(($, e, next) => {
    warnOnce(st, $, 'session.end', next.error.kind)
    return next(e)
  })
}

function registerBash(on: On, st: State): void {
  on('tool.call', { tool: 'Bash' }, async ($, e, next) => {
    if (!(await ensureEnabled($, st))) return next(e)
    // read before next: a failure here must not run the tool twice
    const root = await $.session.root()
    if (root === '') return next(e)
    return next(e) // capture comes with the store
  }).catch(($, e, next) => {
    warnOnce(st, $, 'Bash', next.error.kind)
    return next(e)
  })
}

function registerPrompt(on: On, st: State): void {
  on('prompt.submit', async ($, e, next) => {
    await ensureEnabled($, st)
    return next(e)
  }).catch(($, e, next) => {
    warnOnce(st, $, 'prompt.submit', next.error.kind)
    return next(e)
  })
}

export const register: Register = on => {
  const st = newState()
  registerSession(on, st)
  registerBash(on, st)
  registerPrompt(on, st)
}
