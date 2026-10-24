import type { EngineInterface, Register } from 'claude-code'

const OUT = '/tmp/ctxprobe-out.json' // change per run
const log: Record<string, unknown>[] = []

async function save($: EngineInterface, row: Record<string, unknown>): Promise<void> {
  log.push(row)
  await $.fs.write(OUT, JSON.stringify(log, null, 1))
}

export const register: Register = (on) => {
  on('prompt.context', async ($, e, next) => {
    const files = e.instructionFiles ?? []
    await save($, { ev: 'context.in', blocks: e.blocks.map(b => ({ name: b.name, len: b.text.length })),
      files: files.map(f => ({ path: f.path, kind: f.kind, len: f.content.length })) })
    const kept = files.filter(f => !f.path.endsWith('rules/default-language.md'))
    const res = await next({ ...e, instructionFiles: kept })
    const blocks = [...res.blocks, { name: 'probe', text: 'PROBE-CTX-CANARY: zebra-417' }]
    await save($, { ev: 'context.out', dropped: files.length - kept.length,
      blocks: blocks.map(b => ({ name: b.name, len: b.text.length })) })
    return { ...res, blocks }
  })

  on('prompt.compose', async ($, e, next) => {
    const res = await next(e)
    await save($, { ev: 'compose', traits: e.traits,
      sections: res.sections.map(s => ({ id: s.id, scope: s.scope, len: s.text.length })) })
    return { sections: [...res.sections, { id: 'ctxprobe:canary', text: 'PROBE-SYS-CANARY: lynx-902', scope: 'session' as const }] }
  })

  on('prompt.attachment', async ($, e, next) => {
    await save($, { ev: 'attachment', type: e.type, origin: e.origin.kind, len: e.text.length, head: e.text.slice(0, 90) })
    if (e.type !== 'skill_listing') return next(e)
    const text = e.text.split('\n').filter(l => !l.startsWith('- scrape')).join('\n')
    await save($, { ev: 'skill_listing.rewritten', before: e.text.length, after: text.length })
    return next({ ...e, text })
  })

  on('prompt.submit', async ($, e, next) =>
    next({ ...e, context: [...(e.context ?? []), 'PROBE-SUBMIT-CANARY: otter-233'] }))

  on('tool.call', { tool: 'Read' }, async ($, e, next) => {
    const res = await next(e)
    if ('deny' in res && res.deny) return res
    return { ...res, context: [...(res.context ?? []), 'PROBE-TOOL-CANARY: heron-781'] }
  })

  on('command.describe', { command: 'scrape' }, async ($, e, next) => ({ ...(await next(e)), isHidden: true }))
  on('agent.offer', { agent: 'interviewer' }, async () => ({ isOffered: false }))
  on('prompt.section', { name: 'memory' }, async () => ({ text: null }))
}
