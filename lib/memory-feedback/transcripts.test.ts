import { afterAll, expect, test } from 'bun:test'
import * as fs from 'node:fs'
import * as os from 'node:os'
import * as path from 'node:path'
import type { LogRecord } from '../../mods/memory/hooks/register.ts'
import {
  composerText, joinPrompt, joinTool, records, sessionFiles, slugOf,
  type Rec,
} from './transcripts.ts'

const dirs: string[] = []
afterAll(() => dirs.forEach(d => fs.rmSync(d, { recursive: true })))
const T0 = Date.parse('2026-11-10T10:00:00.000Z')
const iso = (ms: number) => new Date(T0 + ms).toISOString()
const user = (ms: number, text: string): Rec => ({ type: 'user',
  timestamp: iso(ms), origin: { kind: 'human' }, message: { content: text } })
const said = (ms: number, id: string, text: string): Rec => ({
  type: 'assistant', timestamp: iso(ms),
  message: { id, content: [{ type: 'text', text }] } })
const hook = (ms: number, name: string, lines: string[], use?: string) => ({
  type: 'attachment', timestamp: iso(ms), attachment: {
    type: 'hook_additional_context', hookName: name, content: lines,
    ...(use ? { toolUseID: use } : {}) } })
const rec = (over: Partial<LogRecord>): LogRecord => ({ at: T0, session: 's',
  agent: 'main', channel: 'prompt', ids: ['BDR-001'], trigger: 'fresh',
  outcome: 'injected', ...over })
const JOIN_LATE = 10001 // one ms past JOIN_MS

test('X1: slug, the main or one sub-agent file, torn lines counted', () => {
  expect(slugOf('/home/a.b/c_d')).toBe('-home-a-b-c-d')
  const p = fs.mkdtempSync(path.join(os.tmpdir(), 'mf-'))
  dirs.push(p)
  const dir = path.join(p, slugOf('/r'))
  const sub = path.join(dir, 's', 'subagents')
  fs.mkdirSync(sub, { recursive: true })
  fs.writeFileSync(path.join(dir, 's.jsonl'), '{"a":1}\n{"torn')
  fs.writeFileSync(path.join(sub, 'agent-a1.jsonl'), '{"b":2}\n')
  fs.writeFileSync(path.join(sub, 'agent-a2.jsonl'), '{"c":3}\n')
  const main = sessionFiles(p, '/r', 's', 'main')
  expect(main.map(f => path.basename(f))).toEqual(['s.jsonl'])
  expect(sessionFiles(p, '/r', 's', 'a1').map(f => path.basename(f)))
    .toEqual(['agent-a1.jsonl'])
  expect(records(main[0]!)).toEqual({ recs: [{ a: 1 }], torn: 1 })
  expect(sessionFiles(p, '/r', 'gone', 'main')).toEqual([])
})

test('X2: composer prompts only', () => {
  expect(composerText(user(0, 'fix the gate'))).toBe('fix the gate')
  expect(composerText(user(0, '/close'))).toBeUndefined()
  expect(composerText(user(0, '<system-reminder>x'))).toBeUndefined()
  expect(composerText({ ...user(0, 'x'), origin: { kind: 'sdk' } }))
    .toBeUndefined()
  expect(composerText({ ...user(0, 'x'), isSidechain: true }))
    .toBeUndefined()
})

test('X3: an injected ask joins prompt, block and deduped reply', () => {
  const recs = [
    user(-100, 'design the gate'),
    hook(800, 'prompt.submit', ['memory: note', 'memory recall:\nBDR-001 x']),
    said(2000, 'm1', 'see BDR-001'), said(2000, 'm1', 'see BDR-001'),
    said(2100, 'm1', 'done'),
    user(9000, 'next ask'), said(9500, 'm2', 'later'),
  ]
  expect(joinPrompt(recs, rec({}))).toEqual({ prompt: 'design the gate',
    injected: 'memory recall:\nBDR-001 x', reply: 'see BDR-001\ndone' })
})

test('X4: a non-injected ask joins its prompt; a missing turn is lost',
  () => {
    const recs = [user(-3000, 'plan the reader')]
    expect(joinPrompt(recs, rec({ outcome: 'timeout', ids: [] })))
      .toEqual({ prompt: 'plan the reader', injected: '', reply: '' })
    expect(joinPrompt([], rec({ outcome: 'none', ids: [] })))
      .toBeUndefined()
    const late = [user(0, 'x'), hook(JOIN_LATE, 'prompt.submit',
      ['memory recall:\nBDR-001 x'])]
    expect(joinPrompt(late, rec({}))).toBeUndefined()
  })

test('X5: a tool record joins through the -context id, replays ignored',
  () => {
    const use = (ms: number, id: string, command?: string): Rec => ({
      type: 'assistant', timestamp: iso(ms), message: { id: `a${id}`,
        content: [{ type: 'tool_use', id, name: 'Bash',
          input: command ? { command } : {} }] } })
    const result = (ms: number, id: string, err: boolean, type = 'user') =>
      ({ type, timestamp: iso(ms), message: { content: [
        { type: 'tool_result', tool_use_id: id, is_error: err }] } })
    const recs: Rec[] = [
      use(0, 'u1', 'make test'), result(5, 'u1', true),
      hook(10, 'tool.call', ['memory: known BLK-003 — x'], 'u1-context'),
      result(15, 'u1', true, 'api-request-blob'), // a replay, not a call
      use(20, 'u2'), result(25, 'u2', false),
      result(30, 'u2', false), // a duplicate result of the same call
    ]
    const r = rec({ channel: 'tool', ids: ['BLK-003'], trigger: 'tool' })
    expect(joinTool(recs, r)).toEqual({ command: 'make test',
      known: 'memory: known BLK-003 — x', next: [false] })
    expect(joinTool(recs, { ...r, ids: ['BLK-009'] })).toBeUndefined()
  })
