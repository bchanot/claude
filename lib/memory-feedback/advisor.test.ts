import { afterAll, expect, test } from 'bun:test'
import * as fs from 'node:fs'
import * as os from 'node:os'
import * as path from 'node:path'
import {
  MAIN, UNKNOWN_AGENT, advisorSection, advisorUsage, callerOf, compact,
  renderAdvisor, type Tally,
} from './advisor.ts'

const dirs: string[] = []
afterAll(() => dirs.forEach(d => fs.rmSync(d, { recursive: true })))
const mk = () => {
  const d = fs.mkdtempSync(path.join(os.tmpdir(), 'mf-adv-'))
  dirs.push(d)
  return d
}
const DAY = 86400000
const FROM = Date.parse('2026-01-01T00:00:00Z')
const TO = FROM + 10 * DAY
const SLUG = '-home-secret-slug'
const iso = (ms: number) => new Date(FROM + ms).toISOString()
const adv = (input: number, model = 'claude-fable-5-2') =>
  ({ type: 'advisor_message', model, input_tokens: input })
const row = (ms: number, id: string, its: object[], type = 'assistant') =>
  ({ type, timestamp: iso(ms), message: { id, usage: { iterations: its } } })
const lines = (recs: object[]) =>
  recs.map(r => JSON.stringify(r)).join('\n') + '\n'

/** A projects dir with one project dir; returns both paths. */
function fixture() {
  const projects = mk()
  const proj = path.join(projects, SLUG)
  fs.mkdirSync(proj)
  return { projects, proj }
}
const put = (file: string, recs: object[]) =>
  fs.writeFileSync(file, lines(recs))
const subDir = (proj: string, session = 's1') => {
  const d = path.join(proj, session, 'subagents')
  fs.mkdirSync(d, { recursive: true })
  return d
}
const only = (t: Tally) => t.uses.map(u =>
  [u.caller, u.model, u.calls, u.input])

test('1: one main row, duplicate rows deduped by message.id', () => {
  const { projects, proj } = fixture()
  put(path.join(proj, 's1.jsonl'), [
    row(10, 'm1', [adv(1500)]), row(10, 'm1', [adv(1500)])])
  expect(only(advisorUsage(projects, FROM, TO)))
    .toEqual([[MAIN, 'claude-fable-5-2', 1, 1500]])
})

test('2: rows outside (from, to] are not counted', () => {
  const { projects, proj } = fixture()
  put(path.join(proj, 's1.jsonl'), [row(0, 'a', [adv(1)]),
    row(-5, 'b', [adv(1)]), row(11 * DAY, 'c', [adv(1)]),
    row(1000, 'd', [adv(7)])])
  expect(only(advisorUsage(projects, FROM, TO))[0]?.[3]).toBe(7)
})

test('3: a user record and a torn line are ignored', () => {
  const { projects, proj } = fixture()
  fs.writeFileSync(path.join(proj, 's1.jsonl'),
    lines([row(10, 'u', [adv(5)], 'user')]) + '{"torn advisor_message\n')
  const t = advisorUsage(projects, FROM, TO)
  expect(t.uses).toEqual([])
  expect(t.unparsed).toBe(0)
})

test('4: two advisor iterations in one message are two calls', () => {
  const { projects, proj } = fixture()
  put(path.join(proj, 's1.jsonl'), [row(10, 'm', [adv(1), adv(2)])])
  expect(only(advisorUsage(projects, FROM, TO)))
    .toEqual([[MAIN, 'claude-fable-5-2', 2, 3]])
})

test('5: an iteration without model is `unknown`', () => {
  const { projects, proj } = fixture()
  const bare = { type: 'advisor_message', input_tokens: 4 }
  put(path.join(proj, 's1.jsonl'), [row(10, 'm', [bare])])
  expect(advisorUsage(projects, FROM, TO).uses[0]?.model).toBe('unknown')
})

/** One sub-agent transcript per entry; its meta file only when given. */
function putAgents(sub: string, metas: Record<string, string | undefined>) {
  for (const [id, meta] of Object.entries(metas)) {
    put(path.join(sub, `agent-${id}.jsonl`), [row(10, id, [adv(1)])])
    if (meta) fs.writeFileSync(path.join(sub, `agent-${id}.meta.json`), meta)
  }
}

test('6: sub-agent callers come from the meta agentType', () => {
  const { projects, proj } = fixture()
  putAgents(subDir(proj), {
    a1: '{"agentType":"verifier"}', a2: undefined,
    a3: '{"agentType":"../x"}' })
  const t = advisorUsage(projects, FROM, TO)
  expect(t.uses.map(u => [u.caller, u.calls]).sort())
    .toEqual([['verifier', 1], [UNKNOWN_AGENT, 2]].sort())
})

test('7: a transcript with mtime <= from is skipped', () => {
  const { projects, proj } = fixture()
  const f = path.join(proj, 's1.jsonl')
  put(f, [row(10, 'm', [adv(1)])])
  fs.utimesSync(f, new Date(FROM - 1000), new Date(FROM - 1000))
  const t = advisorUsage(projects, FROM, TO)
  expect(t.uses).toEqual([])
  expect(t.files).toBe(0)
})

test('8: missing projects dir, and a window with no advisor row', () => {
  const none = path.join(mk(), 'absent')
  expect(advisorUsage(none, FROM, TO))
    .toEqual({ uses: [], unparsed: 0, files: 0 })
  const s = advisorSection(none, FROM, TO)
  expect(s).toContain('## Advisor usage (2026-01-01 → 2026-01-11)')
  expect(s).toContain('No transcript modified since 2026-01-01')
  expect(s).toContain('check the path.')
  const { projects, proj } = fixture()
  put(path.join(proj, 's1.jsonl'), [row(10, 'm', [])])
  expect(advisorSection(projects, FROM, TO))
    .toContain('No advisor call in the window.')
})

test('9: render: all on disk, compact, total row, sort order', () => {
  expect([999, 1500, 999950, 2500000].map(compact))
    .toEqual(['999', '1.5k', '1.0M', '2.5M'])
  const uses = [
    { caller: 'verifier', model: 'm', calls: 9, input: 1000 },
    { caller: MAIN, model: 'm', calls: 2, input: 1500 },
    { caller: 'planner', model: 'm', calls: 3, input: 500 }]
  const t = { uses: [...uses].sort((a, b) =>
    Number(b.caller === MAIN) - Number(a.caller === MAIN) ||
    b.calls - a.calls), unparsed: 0, files: 3 }
  const s = renderAdvisor(t, 0, TO)
  expect(s.startsWith('## Advisor usage (all on disk → 2026-01-11)\n'))
    .toBe(true)
  expect(s).toContain('| total | | 14 | 3.0k |')
  expect(s.indexOf('| main loop')).toBeLessThan(s.indexOf('| verifier'))
  expect(s.indexOf('| verifier')).toBeLessThan(s.indexOf('| planner'))
  expect(s.endsWith('\n')).toBe(true)
})

test('9b: advisorUsage sorts main loop first, then calls desc', () => {
  const { projects, proj } = fixture()
  put(path.join(proj, 's1.jsonl'), [row(10, 'm', [adv(1)])])
  const sub = subDir(proj)
  put(path.join(sub, 'agent-a.jsonl'),
    [row(10, 'x', [adv(1)]), row(20, 'y', [adv(1)])])
  fs.writeFileSync(path.join(sub, 'agent-a.meta.json'),
    '{"agentType":"verifier"}')
  expect(advisorUsage(projects, FROM, TO).uses.map(u => u.caller))
    .toEqual([MAIN, 'verifier'])
})

test('10: the section holds no project slug or path', () => {
  const { projects, proj } = fixture()
  put(path.join(proj, 's1.jsonl'), [row(10, 'm', [adv(1)])])
  const s = advisorSection(projects, FROM, TO)
  expect(s).toContain('| main loop |')
  expect(s).not.toContain('secret-slug')
  expect(s).not.toContain(projects)
})

test('11: an advisor block with no iteration is not a call', () => {
  const { projects, proj } = fixture()
  const blockOnly = { type: 'assistant', timestamp: iso(10), message: {
    id: 'm', content: [{ type: 'server_tool_use', name: 'advisor' }],
    usage: { iterations: [] } } }
  fs.writeFileSync(path.join(proj, 's1.jsonl'), lines([blockOnly]) +
    '{"type":"assistant","note":"advisor_message"}\n')
  const t = advisorUsage(projects, FROM, TO)
  expect(t.uses).toEqual([])
  expect(t.unparsed).toBe(0)
})

const drift = { type: 'assistant', timestamp: iso(10), message: {
  id: 'd', usage: { advisor_message: { input_tokens: 1 } } } }

test('12: shape drift is counted and replaces the plain zero', () => {
  const { projects, proj } = fixture()
  put(path.join(proj, 's1.jsonl'), [drift])
  const t = advisorUsage(projects, FROM, TO)
  expect(t.unparsed).toBe(1)
  const s = renderAdvisor(t, FROM, TO)
  expect(s).toContain('1 transcript lines mention advisor_message, none ' +
    'parsed: check the transcript shape.')
  expect(s).not.toContain('No advisor call')
})

test('13: the retention note appears past 7 calendar days only', () => {
  const t: Tally = { uses: [], unparsed: 0, files: 1 }
  expect(renderAdvisor(t, TO - 10 * DAY, TO)).toContain(
    'Transcripts kept 7 d: calls before 2026-01-04 may be missing.')
  expect(renderAdvisor(t, TO - 3 * DAY, TO)).not.toContain('Transcripts kept')
  expect(renderAdvisor(t, 0, TO)).not.toContain('Transcripts kept')
  const to = TO + 17 * 3600000 // a weekly run lands mid-day, not at 00:00
  expect(renderAdvisor(t, to - 7 * DAY - 5 * 3600000, to))
    .not.toContain('Transcripts kept')
})

test('14: an unreadable sub-directory is skipped, the rest counts', () => {
  const { projects, proj } = fixture()
  put(path.join(proj, 's1.jsonl'), [row(10, 'm', [adv(1)])])
  const sub = subDir(proj, 's2')
  put(path.join(sub, 'agent-a.jsonl'), [row(10, 'z', [adv(1)])])
  const locked = path.join(proj, 's2')
  fs.chmodSync(locked, 0o000)
  try {
    const t = advisorUsage(projects, FROM, TO)
    if (process.getuid?.() !== 0) expect(only(t))
      .toEqual([[MAIN, 'claude-fable-5-2', 1, 1]])
  } finally {
    fs.chmodSync(locked, 0o700)
  }
})

test('15: a hand-edited from never throws', () => {
  const none = path.join(mk(), 'absent')
  for (const bad of [Infinity, 1e17, NaN]) {
    expect(advisorSection(none, bad, TO)).toContain('(all on disk → ')
  }
})

test('16: drift under a table prints the table then the drift line', () => {
  const { projects, proj } = fixture()
  put(path.join(proj, 's1.jsonl'), [row(10, 'm', [adv(1)]), drift])
  const s = advisorSection(projects, FROM, TO)
  expect(s.indexOf('| total |')).toBeGreaterThan(0)
  expect(s.indexOf('none parsed')).toBeGreaterThan(s.indexOf('| total |'))
})

test('17: a symlinked meta file is not trusted', () => {
  const { proj } = fixture()
  const sub = subDir(proj)
  const real = path.join(mk(), 'meta.json')
  fs.writeFileSync(real, '{"agentType":"verifier"}')
  fs.symlinkSync(real, path.join(sub, 'agent-a.meta.json'))
  expect(callerOf(path.join(sub, 'agent-a.jsonl'))).toBe(UNKNOWN_AGENT)
})
