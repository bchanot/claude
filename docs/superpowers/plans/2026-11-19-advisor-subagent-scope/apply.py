#!/usr/bin/env python3
"""Exact-once applier for docs/superpowers/plans/2026-11-19-advisor-subagent-scope.md.

Usage: apply.py test | rest   (run from the repo root, or pass ROOT as argv[2])
Every replacement asserts its `old` occurs exactly once and its `new` is
absent, so a second run refuses instead of doubling text.
"""
import os, re, stat, sys

ROOT = sys.argv[2] if len(sys.argv) > 2 else '.'
PLAN = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                    '..', '2026-11-19-advisor-subagent-scope.md')
B = dict(re.findall(r'### Block (\S+)[^\n]*\n```\n(.*?)```\n',
                    open(PLAN, encoding='utf-8').read(), re.S))

ROWS = ['skills/init-project/SKILL.md', 'skills/code-clean/SKILL.md',
        'skills/onboard/SKILL.md', 'skills/audit-delta/SKILL.md',
        'skills/ship-feature/SKILL.md', 'skills/harden/SKILL.md',
        'skills/pack-seo/skills/seo/SKILL.md',
        'skills/pack-seo/skills/geo/SKILL.md',
        'skills/pack-web-validate/skills/web-validate/SKILL.md']
H1 = {'plugin-advisor': '# PLUGIN ADVISOR',
      'seo-analyzer': '# SEO — Classical Search Engines audit, fix & strategy',
      'geo-analyzer': '# GEO — Generative Engine Optimization audit, fix & strategy',
      'doc-syncer': '# DOC SYNCER',
      'commit-changer': '# Git Smart Commit',
      'handover-doc-writer': '# HANDOVER DOC WRITER'}
ONBOARD = [('  ', 'code-clean audit only (read-only, opus)'),
           ('    ', 'security audit fallback (archetype-adaptive)'),
           ('  ', 'static design review fallback'),
           ('  ', 'static perf audit'),
           ('  ', 'static a11y audit'),
           ('  ', 'synthèse vers .claude/audits/')]


PENDING = []


def edit(rel, old, new):
    """Queue an exact-once replacement; nothing is written until flush()."""
    PENDING.append((rel, old, new))


def flush():
    """Check every queued edit against the cumulative text, then write."""
    texts = {}
    for rel, old, new in PENDING:
        s = texts.get(rel)
        if s is None:
            s = open(os.path.join(ROOT, rel), encoding='utf-8').read()
        if s.count(old) != 1:
            sys.exit(f'{rel}: old found {s.count(old)}x, nothing written')
        if s.count(new) != 0:
            sys.exit(f'{rel}: new already present, nothing written')
        texts[rel] = s.replace(old, new)
    for rel, s in texts.items():
        open(os.path.join(ROOT, rel), 'w', encoding='utf-8').write(s)


def create(rel, body, mode=0o644):
    path = os.path.join(ROOT, rel)
    if os.path.exists(path):
        sys.exit(f'{rel}: exists, nothing written')
    open(path, 'w', encoding='utf-8').write(body)
    os.chmod(path, mode)


def rest():
    if os.path.exists(os.path.join(ROOT, 'hooks/subagent-advisor.sh')):
        sys.exit('hooks/subagent-advisor.sh: exists, nothing written')
    edit('settings.json', B['settings-old'], B['settings-new'])
    edit('CLAUDE.global.md', B['global-workflow-old'], B['global-workflow-new'])
    edit('CLAUDE.global.md', B['global-sdd-old'], B['global-sdd-new'])
    edit('lib/effort-shift.md', B['effort-old'], B['effort-new'])
    edit('lib/challenge-plan.md', B['advfirst-old'], B['advfirst-new'])
    edit('lib/challenge-plan.md', B['challenge-old'], B['challenge-new'])
    for rel in ROWS:
        edit(rel, B['row-old'].rstrip('\n'), B['row-new'].rstrip('\n'))
    for name, h1 in H1.items():
        edit(f'agents/{name}.md', h1 + '\n', h1 + '\n' + B['agent-line'])
    edit('agents/client-handover-writer.md', B['handover-old'], B['handover-new'])
    line = B['onboard-line'].lstrip(' ')
    for ind, desc in ONBOARD:
        old = f'{ind}description="Onboard — {desc}",\n{ind}prompt="""\n'
        edit('skills/onboard/SKILL.md', old, old + ind + line)
    edit('skills/tour/SKILL.md', B['tour-old'], B['tour-new'])
    for rel in ('skills/ship-feature/SKILL.md', 'skills/init-project/SKILL.md'):
        edit(rel, B['review-old'], B['review-new'])
    flush()
    create('hooks/subagent-advisor.sh', B['new-hook'], 0o755)


def review1():
    allowed = ('plan-challenger', 'verifier', 'security-auditor', 'analyzer')
    for name in allowed:
        edit(f'agents/{name}.md', B['r1-allow-old'].rstrip('\n'),
             B['r1-allow-new'].rstrip('\n'))
    edit('CLAUDE.global.md', B['r1-global-old'], B['r1-global-new'])
    edit('agents/plan-challenger.md', B['r1-pc-old'], B['r1-pc-new'])
    edit('lib/effort-shift.md', B['r1-effort-old'], B['r1-effort-new'])
    for name in H1:
        edit(f'agents/{name}.md', B['r1-agent-old'], B['r1-agent-new'])
    test = 'lib/tests/subagent-advisor.test.sh'
    edit(test, B['r1-test-old'], B['r1-test-new'])
    edit(test, B['r1-t2c-old'], B['r1-t2c-new'])
    flush()


if __name__ == '__main__':
    what = sys.argv[1] if len(sys.argv) > 1 else ''
    if what == 'test':
        create('lib/tests/subagent-advisor.test.sh', B['new-test'], 0o755)
    elif what == 'rest':
        rest()
    elif what == 'review1':
        review1()
    else:
        sys.exit('usage: apply.py test | rest | review1 [ROOT]')
    print('applied', what)
