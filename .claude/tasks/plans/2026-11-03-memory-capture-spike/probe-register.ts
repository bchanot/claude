import type { Register } from 'claude-code'

const LOG = '/home/bchanot/.claude/jobs/8573ce6f/tmp/probe4b/log.jsonl'

function cut(v: any, n: number): any {
  return v === undefined || v === null ? v : String(v).slice(0, n)
}

async function append($: any, obj: any): Promise<void> {
  try {
    const prev = (await $.fs.exists(LOG)) ? await $.fs.read(LOG) : ''
    const text = typeof prev === 'string' ? prev : (prev?.text ?? '')
    await $.fs.write(LOG, text + JSON.stringify(obj) + '\n')
  } catch (err) {
    // fail open
  }
}

async function classic($: any, name: string, e: any): Promise<void> {
  if (name === 'classic.PostToolUse' && e.tool_name !== 'Bash') return
  await append($, {
    ev: name,
    keys: Object.keys(e),
    tool_name: e.tool_name,
    error: cut(e.error, 120),
    reason: cut(e.reason, 120),
    is_interrupt: e.is_interrupt,
  })
}

async function toolRow($: any, e: any, out: any): Promise<void> {
  const r = out.result
  const row: any = {
    ev: 'tool.call',
    command: cut(e.command, 80),
    agentId: e.agentId !== undefined,
    keys: Object.keys(out),
    isError: out.isError,
    deny: cut(out.deny, 120),
    resultType: typeof r,
    text: cut(out.text, 120),
  }
  if (r && typeof r === 'object' && !out.isError) {
    row.stdout = cut(r.stdout, 80)
    row.stderr = cut(r.stderr, 80)
    row.interrupted = r.interrupted
    row.rci = r.returnCodeInterpretation
    row.gitOperation = r.gitOperation
  } else if (r && typeof r === 'object') {
    row.resultKeys = Object.keys(r)
  }
  await append($, row)
}

export const register: Register = on => {
  on('tool.call', { tool: 'Bash' }, async ($, e, next) => {
    const out: any = await next(e)
    await toolRow($, e, out).catch(() => {})
    return out
  }).catch(($, e, next) => next(e))

  on('classic.PostToolUseFailure', ($, e, next) =>
    classic($, 'classic.PostToolUseFailure', e).catch(() => {}).then(() => next(e))).catch(($, e, next) => next(e))

  on('classic.PermissionDenied', ($, e, next) =>
    classic($, 'classic.PermissionDenied', e).catch(() => {}).then(() => next(e))).catch(($, e, next) => next(e))

  on('classic.PostToolUse', ($, e, next) =>
    classic($, 'classic.PostToolUse', e).catch(() => {}).then(() => next(e))).catch(($, e, next) => next(e))
}
