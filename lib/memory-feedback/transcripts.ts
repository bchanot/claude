// lib/memory-feedback/transcripts.ts: reads Claude Code transcripts and
// joins one injection-log record to the turn it served (phase 4d).
import * as fs from 'node:fs'
import * as path from 'node:path'
import type { LogRecord } from '../../mods/memory/hooks/register.ts'

export type Rec = Record<string, any>
export type Loaded = { recs: Rec[]; torn: number }
export const JOIN_MS = 10000 // attachment written at most this after `at`
const NEAR_MS = 60000 // composer prompt at most this far from the ask
const WRAPPERS = ['<command-', '<local-command', '<system-reminder']
const RECALL_HEAD = 'memory recall:'
const KNOWN_HEAD = 'memory: known '
const CONTEXT_SUFFIX = /-context$/ // tool.call attachments: <id>-context

/** The transcript folder name of a project root. */
export const slugOf = (root: string) => root.replace(/[^A-Za-z0-9]/g, '-')

const SAFE_ID = /^[A-Za-z0-9_-]+$/

/** The transcript of a session's main thread, or of one sub-agent
 * (`subagents/agent-<id>.jsonl`, the id the log keeps in `agent`). */
export function sessionFiles(
  projects: string, root: string, session: string, agent: string,
): string[] {
  if (!SAFE_ID.test(session) || !SAFE_ID.test(agent)) return []
  const dir = path.join(projects, slugOf(root))
  const file = agent === 'main'
    ? path.join(dir, `${session}.jsonl`)
    : path.join(dir, session, 'subagents', `agent-${agent}.jsonl`)
  return fs.existsSync(file) ? [file] : []
}

/** Parsed lines of a transcript; torn, partial or non-object lines
 * (`null`, a number, an array) are counted as torn. */
export function records(file: string): Loaded {
  const recs: Rec[] = []
  let torn = 0
  for (const raw of fs.readFileSync(file, 'utf8').split('\n')) {
    if (raw.trim() === '') continue
    try {
      const v = JSON.parse(raw)
      if (v === null || typeof v !== 'object' || Array.isArray(v)) {
        torn += 1
      } else recs.push(v)
    } catch { torn += 1 }
  }
  return { recs, torn }
}

const tsOf = (r: Rec) => Date.parse(String(r.timestamp ?? ''))

function blocksOf(r: Rec): Rec[] {
  const c = r.message?.content
  return Array.isArray(c) ? c.filter(b => b && typeof b === 'object') : []
}

/** A typed composer prompt (recall-bench's rule); else undefined. */
export function composerText(r: Rec): string | undefined {
  if (r.type !== 'user' || r.isSidechain === true) return undefined
  if (r.isMeta === true || r.isCompactSummary === true) return undefined
  const c = r.message?.content
  if (typeof c !== 'string' || r.origin?.kind !== 'human') return undefined
  const t = c.trim()
  if (t.startsWith('/')) return undefined
  return WRAPPERS.some(w => t.startsWith(w)) ? undefined : t
}

/** The joined text of a `hook` context attachment; else undefined. */
function hookText(r: Rec, hook: string): string | undefined {
  const a = r.attachment
  if (r.type !== 'attachment' || a?.type !== 'hook_additional_context') {
    return undefined
  }
  if (a.hookName !== hook) return undefined
  return Array.isArray(a.content) ? a.content.map(String).join('\n')
    : String(a.content ?? '')
}

/** The earliest `hook` attachment holding `needle` in [at, at+JOIN_MS]. */
function attachmentAfter(
  recs: Rec[], at: number, hook: string, needle: string,
): Rec | undefined {
  let best: Rec | undefined
  for (const r of recs) {
    const t = tsOf(r)
    if (!(t >= at && t <= at + JOIN_MS)) continue
    if (!hookText(r, hook)?.includes(needle)) continue
    if (best === undefined || t < tsOf(best)) best = r
  }
  return best
}

type Prompt = { t: number; text: string }

/** The composer prompt nearest `ts`, within NEAR_MS. */
function promptNear(recs: Rec[], ts: number): Prompt | undefined {
  let best: Prompt | undefined
  for (const r of recs) {
    const text = composerText(r)
    const t = tsOf(r)
    if (text === undefined || !Number.isFinite(t)) continue
    if (Math.abs(t - ts) > NEAR_MS) continue
    if (best === undefined || Math.abs(t - ts) < Math.abs(best.t - ts)) {
      best = { t, text }
    }
  }
  return best
}

/** The first composer prompt after `ts`; Infinity when none. */
function nextPromptAt(recs: Rec[], ts: number): number {
  let end = Infinity
  for (const r of recs) {
    const t = tsOf(r)
    if (t > ts && t < end && composerText(r) !== undefined) end = t
  }
  return end
}

/** The [dedupe key, text] of each text block of an assistant record. */
const textsOf = (r: Rec): [string, string][] => blocksOf(r)
  .filter(b => b.type === 'text')
  .map(b => [`${r.message?.id}:${b.text}`, String(b.text)]) // EVAL-037

/** Main-thread assistant text after `ts` up to the next prompt. */
function replyAfter(recs: Rec[], ts: number): string {
  const end = nextPromptAt(recs, ts)
  const seen = new Set<string>()
  return recs
    .filter(r => r.type === 'assistant' && r.isSidechain !== true)
    .filter(r => tsOf(r) > ts && tsOf(r) < end)
    .flatMap(textsOf)
    .filter(([key]) => !seen.has(key) && !!seen.add(key))
    .map(([, text]) => text)
    .join('\n')
}

export type PromptJoin = { prompt: string; injected: string; reply: string }

/** The turn a prompt-channel record served; undefined when lost. */
export function joinPrompt(
  recs: Rec[], rec: LogRecord,
): PromptJoin | undefined {
  if (rec.outcome !== 'injected') {
    const p = promptNear(recs, rec.at)
    return p && { prompt: p.text, injected: '', reply: '' }
  }
  const att = attachmentAfter(recs, rec.at, 'prompt.submit', RECALL_HEAD)
  if (att === undefined) return undefined
  const t = tsOf(att)
  const p = promptNear(recs, t)
  const text = hookText(att, 'prompt.submit') ?? ''
  return { prompt: p?.text ?? '',
    injected: text.slice(text.indexOf(RECALL_HEAD)),
    reply: replyAfter(recs, Math.max(t, p?.t ?? t)) }
}

/** Blocks of real calls and results: blob replays are skipped. */
const callBlocks = (recs: Rec[]) => recs
  .filter(r => r.type === 'assistant' || r.type === 'user')
  .flatMap(blocksOf)

/** The command of a Bash tool_use. */
function bashCommand(blocks: Rec[], useId: string): string {
  const b = blocks.find(x => x.type === 'tool_use' && x.id === useId)
  return String(b?.input?.command ?? '')
}

/** Whether each of the next 3 Bash results after `useId` failed. */
function nextResults(blocks: Rec[], useId: string): boolean[] {
  const bash = new Set<string>()
  const done = new Set<string>()
  const out: boolean[] = []
  let after = false
  for (const b of blocks) {
    if (b.type === 'tool_use' && b.name === 'Bash') bash.add(b.id)
    if (b.type !== 'tool_result' || !bash.has(b.tool_use_id)) continue
    if (done.has(b.tool_use_id)) continue
    done.add(b.tool_use_id)
    if (after && out.length < 3) out.push(b.is_error === true)
    if (b.tool_use_id === useId) after = true
  }
  return out
}

export type ToolJoin = { command: string; known: string; next: boolean[] }

/** The failure a known line answered and the next 3 Bash results. */
export function joinTool(recs: Rec[], rec: LogRecord): ToolJoin | undefined {
  const needle = `${KNOWN_HEAD}${rec.ids[0] ?? ''} ` // BLK-003 != BLK-0031
  const att = attachmentAfter(recs, rec.at, 'tool.call', needle)
  const raw = att?.attachment?.toolUseID
  if (att === undefined || typeof raw !== 'string') return undefined
  const useId = raw.replace(CONTEXT_SUFFIX, '')
  const blocks = callBlocks(recs)
  return { command: bashCommand(blocks, useId),
    known: hookText(att, 'tool.call') ?? '',
    next: nextResults(blocks, useId) }
}
