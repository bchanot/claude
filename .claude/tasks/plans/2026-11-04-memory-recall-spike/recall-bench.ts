// Measurement harness of the phase 4c memory recall (read-only, stdout).
// Transcript walk follows noise.py (2026-11-03-memory-capture-spike):
// its find_files / pairs_of logic, ported to TS.
// Run: bun recall-bench.ts prompts [--seed N] [--n 20]
//      bun recall-bench.ts errors
import * as fs from 'node:fs'
import * as os from 'node:os'
import * as path from 'node:path'
import {
  IDLE_MS, RECALL_CAP, HAIKU, RERANK_MS, assembleEntries, bm25Rank,
  buildIndex, entriesOf, failureKey, isLive, isTrigger, matchOf, parseIds,
  parseIndex, recallBlock, recallLine, redact, rerankPrompt,
  type Entry, type StatusMap,
} from '../../../../mods/memory/hooks/register.ts'

const REPO = path.resolve(import.meta.dir, '../../../..')
const ROOT = path.join(
  os.homedir(), '.claude/projects/-home-bchanot-Documents-claude')
const DAYS = 14
const MAX_CANDS = 30
const MAX_PICKS = 3
const MIN_SAMPLE = 10
const MEMORY_DIR = path.join(REPO, '.claude/memory')

type Rec = Record<string, any>
type Found = { sid: string; agent: boolean; file: string }
type Composer = { sid: string; text: string; fresh: boolean; idle: number }

function findFiles(): Found[] {
  const cutoff = Date.now() - DAYS * 86400000
  const recent = (p: string) =>
    (fs.statSync(p, { throwIfNoEntry: false })?.mtimeMs ?? 0) >= cutoff
  const found: Found[] = []
  for (const name of fs.readdirSync(ROOT).sort()) {
    const full = path.join(ROOT, name)
    if (name.endsWith('.jsonl') && recent(full)) {
      found.push({ sid: name.slice(0, -6), agent: false, file: full })
    }
    if (name.endsWith('.jsonl')) continue
    const sub = path.join(full, 'subagents')
    if (!fs.statSync(sub, { throwIfNoEntry: false })?.isDirectory()) continue
    for (const f of fs.readdirSync(sub).sort()) {
      const p = path.join(sub, f)
      if (f.endsWith('.jsonl') && recent(p)) {
        found.push({ sid: name, agent: true, file: p })
      }
    }
  }
  return found
}

function records(file: string): Rec[] {
  const out: Rec[] = []
  for (const raw of fs.readFileSync(file, 'utf8').split('\n')) {
    try { out.push(JSON.parse(raw)) } catch { /* skip bad line */ }
  }
  return out
}

function blocksOf(r: Rec): Rec[] {
  const c = r.message?.content
  return Array.isArray(c) ? c.filter(b => b && typeof b === 'object') : []
}

function resultText(content: unknown): string {
  if (typeof content === 'string') return content
  if (!Array.isArray(content)) return ''
  return content.filter(b => b?.type === 'text').map(b => b.text).join('')
}

/** Bash failures: tool_use paired with its tool_result (is_error). */
function failuresOf(file: string): { text: string; command: string }[] {
  const calls = new Map<string, string>()
  const out: { text: string; command: string }[] = []
  for (const r of records(file)) {
    for (const b of blocksOf(r)) {
      if (b.type === 'tool_use' && b.name === 'Bash') {
        calls.set(b.id, String(b.input?.command ?? ''))
      } else if (b.type === 'tool_result' && calls.has(b.tool_use_id) &&
        b.is_error === true) {
        out.push({ text: resultText(b.content),
          command: calls.get(b.tool_use_id) ?? '' })
      }
    }
  }
  return out
}

const WRAPPERS = ['<command-', '<local-command', '<system-reminder']

const skipped = { noOrigin: 0 }

/** A typed prompt: origin.kind human, string content, not a command. */
function composerText(r: Rec): string | undefined {
  if (r.type !== 'user' || r.isSidechain === true) return undefined
  if (r.isMeta === true || r.isCompactSummary === true) return undefined
  if (r.entrypoint !== 'cli') return undefined
  const c = r.message?.content
  if (typeof c !== 'string') return undefined
  if (r.origin?.kind === undefined) {
    skipped.noOrigin += 1
    return undefined
  }
  const t = c.trim()
  if (r.origin.kind !== 'human' || t.startsWith('/')) return undefined
  return WRAPPERS.some(w => t.startsWith(w)) ? undefined : t
}

/** Trigger-meeting typed prompts; fresh = first after a summary or start. */
function triggerPrompts(files: Found[]): { all: number; hits: Composer[] } {
  const hits: Composer[] = []
  let all = 0
  for (const f of files.filter(x => !x.agent)) {
    let last: number | undefined
    let fresh = true
    for (const r of records(f.file)) {
      if (r.isCompactSummary === true) { fresh = true; continue }
      const text = composerText(r)
      if (text === undefined) continue
      all += 1
      const at = Date.parse(r.timestamp)
      const idle = last === undefined || Number.isNaN(at) ? 0 : at - last
      if (!Number.isNaN(at)) last = at
      if (isTrigger(text, fresh, idle)) {
        hits.push({ sid: f.sid, text, fresh, idle })
      }
      fresh = false
    }
  }
  return { all, hits }
}

function rng(seed: number): () => number {
  let a = seed >>> 0
  return () => {
    a = (a + 0x6d2b79f5) >>> 0
    let t = Math.imul(a ^ (a >>> 15), 1 | a)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

function sample<T>(items: T[], n: number, seed: number): T[] {
  const pool = [...items]
  const next = rng(seed)
  for (let i = pool.length - 1; i > 0; i--) {
    const j = Math.floor(next() * (i + 1));
    [pool[i], pool[j]] = [pool[j]!, pool[i]!]
  }
  return pool.slice(0, n)
}

function statuses(): StatusMap {
  const r = Bun.spawnSync(['bash', 'lib/memory.sh', '-C', '.', 'index'],
    { cwd: REPO })
  if (r.exitCode !== 0) throw new Error('memory.sh index failed')
  return parseIndex(r.stdout.toString())
}

function registryTexts(names: string[]): string[] {
  return names.map(n => fs.readFileSync(path.join(MEMORY_DIR, n), 'utf8'))
}

function haiku(prompt: string): { text: string; ms: number } | undefined {
  const dir = fs.mkdtempSync(os.tmpdir() + '/recall-')
  try {
    const r = Bun.spawnSync(['claude', '-p', '--model', HAIKU,
      '--output-format', 'json', '--setting-sources', 'local',
      '--tools', ''], { cwd: dir, stdin: new TextEncoder().encode(prompt) })
    const j = JSON.parse(r.stdout.toString())
    return { text: String(j.result ?? ''), ms: Number(j.duration_api_ms) }
  } catch {
    return undefined
  } finally {
    fs.rmSync(dir, { recursive: true, force: true })
  }
}

function argOf(name: string, fallback: number): number {
  const i = process.argv.indexOf(name)
  const v = i < 0 ? NaN : Number(process.argv[i + 1])
  return Number.isFinite(v) ? v : fallback
}

function share(k: number, n: number): string {
  return n < MIN_SAMPLE ? `${k}/${n} (insufficient sample, < ${MIN_SAMPLE})`
    : `${k}/${n}`
}

function oneLine(text: string, n: number): string {
  return redact(text).replace(/\s+/g, ' ').slice(0, n)
}

function runPrompts(): void {
  const status = statuses()
  const entries = assembleEntries(
    registryTexts(['decisions.md', 'learnings.md', 'blockers.md']), status)
  const live = entries.filter(e => isLive(status, e.id))
  const { all, hits } = triggerPrompts(findFiles())
  const picked = sample(hits, argOf('--n', 20), argOf('--seed', 1))
  console.log(`human prompts (cli): ${all}, skipped no origin: ${skipped.noOrigin}, meeting isTrigger: ` +
    `${hits.length}, sampled: ${picked.length}, live entries: ${live.length}`)
  let asks = 0, answered = 0, inj = 0, ids = 0, late = 0
  picked.forEach((p, i) => {
    asks += 1
    const cands = bm25Rank(live, p.text, MAX_CANDS)
    const a = haiku(rerankPrompt(p.text, cands))
    const got = parseIds(a?.text ?? '', cands, MAX_PICKS)
    const byId = new Map(cands.map(c => [c.id, c]))
    const block = recallBlock(
      got.flatMap(id => byId.get(id) ?? []).map(recallLine), RECALL_CAP)
    const slow = a !== undefined && a.ms > RERANK_MS
    if (a !== undefined) answered += 1
    if (slow) late += 1
    if (block !== '') { inj += 1; ids += got.length }
    console.log(`#${i} [${p.fresh ? 'fresh' : 'idle/rule'}] ` +
      `"${oneLine(p.text, 120)}"`)
    for (const id of got) console.log(`   ${id} ${byId.get(id)?.title}`)
    console.log(`   duration_api_ms=${a?.ms ?? 'n/a'} (upper bound) ` +
      `timeout(>${RERANK_MS})=${a === undefined ? 'failed' : slow ? 'yes' : 'no'}`)
  })
  console.log(`TOTAL asks=${asks} answered=${answered} injections=${inj} ` +
    `mean IDs per injection=${inj ? (ids / inj).toFixed(2) : 'n/a'} ` +
    `timeout share=${share(late, answered)} injection share=` +
    share(inj, asks))
}

function errorIndex(status: StatusMap): Map<string, string> {
  const texts = registryTexts(['blockers.md', 'learnings.md'])
  return buildIndex(assembleEntries(texts, status), status)
}

function runErrors(): void {
  const status = statuses()
  const index = errorIndex(status)
  const titles = new Map(
    registryTexts(['blockers.md', 'learnings.md']).flatMap(entriesOf)
      .map(p => [p.id, status.get(p.id)?.title ?? ''] as const))
  const seen = new Map<string, Set<string>>()
  const perSession = new Map<string, number>()
  let failures = 0
  for (const f of findFiles()) {
    const ledger = `${f.sid}|${f.agent}`
    for (const x of failuresOf(f.file)) {
      const key = failureKey(x.text, x.command)
      if (key === undefined) continue
      failures += 1
      const id = matchOf(index, key)
      const done = seen.get(ledger) ?? new Set<string>()
      if (id === undefined || done.has(id)) continue
      seen.set(ledger, done.add(id))
      perSession.set(f.sid, (perSession.get(f.sid) ?? 0) + 1)
      console.log(`${f.sid.slice(0, 8)}${f.agent ? ' sub' : ''}: ` +
        `"${oneLine(key, 120)}" -> ${id} ${titles.get(id) ?? ''}`)
    }
  }
  const total = [...perSession.values()].reduce((a, b) => a + b, 0)
  console.log('per session: ' + [...perSession]
    .map(([s, n]) => `${s.slice(0, 8)}=${n}`).join(' '))
  console.log(`TOTAL failures keyed=${failures} known-line injections=` +
    `${share(total, failures)} sessions with injection=` +
    `${perSession.size}`)
}

const mode = process.argv[2]
if (mode === 'prompts') runPrompts()
else if (mode === 'errors') runErrors()
else console.error('usage: recall-bench.ts prompts|errors')
