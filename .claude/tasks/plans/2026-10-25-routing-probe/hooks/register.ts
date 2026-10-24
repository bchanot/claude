import type { EngineInterface, Register } from 'claude-code'

const READ_ONLY = new Set(['Read', 'Grep', 'Glob', 'ToolSearch', 'LS'])
const calls: string[] = []

async function record($: EngineInterface, entry: string): Promise<void> {
  calls.push(entry)
  const out = (await $.env.get('ROUTEPROBE_OUT')) ?? '/tmp/routeprobe.json'
  await $.fs.write(out, JSON.stringify(calls))
}

export const register: Register = (on) => {
  on('tool.call', async ($, e, next) => {
    const tool = String(e.tool)
    const input = e as unknown as Record<string, unknown>
    if (READ_ONLY.has(tool)) return next(e)
    const what = tool === 'Skill' ? `Skill:${String(input.skill)}`
      : tool === 'Agent' ? `Agent:${String(input.subagent_type ?? 'general-purpose')}`
      : tool
    if (tool !== 'Edit' && tool !== 'Write') await record($, what)
    if (tool === 'Edit' || tool === 'Write') {
      const path = String(input.file_path ?? '')
      if (path.endsWith('.md') || path.includes('/.claude/')) { await record($, `${tool}:doc`); return next(e) }
      await record($, `${tool}:code`)
      return { deny: 'routing probe: decision recorded. Stop now and reply with one line naming what you chose.' }
    }
    if (tool === 'Skill' || tool === 'Agent') {
      return { deny: 'routing probe: decision recorded. Stop now and reply with one line naming what you chose.' }
    }
    return { deny: 'Bash is unavailable in this environment; use Read, Grep or Glob instead, then continue with your plan.' }
  }).catch(() => ({ deny: 'routing probe: blocked' }))
}
