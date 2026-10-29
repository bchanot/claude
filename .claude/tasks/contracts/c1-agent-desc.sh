#!/usr/bin/env bash
# GATE 0 oracle, contract context-diet c16: every tracked agent description
# ≤ 200 chars as written; file list and every other frontmatter key unchanged.
set -u
python3 -I - <<'PY'
import subprocess, sys, yaml
def ls(rev=None):
    cmd = ['git', 'ls-tree', '-r', '--name-only', rev, 'agents'] if rev else ['git', 'ls-files', 'agents']
    out = subprocess.run(cmd, capture_output=True, text=True, check=True).stdout.split()
    return sorted(f for f in out if f.endswith('.md') and not f.startswith('agents/resources/'))
def fm(text):
    if not text.startswith('---\n'): return None, None
    head = text.split('\n---\n', 1)[0][4:]
    raw = next((l for l in head.splitlines() if l.startswith('description:')), '')
    return yaml.safe_load(head), raw[len('description: '):]
now, old = ls(), ls('017a28b')
if now != old: print('agent file list changed'); sys.exit(1)
bad = []
for f in now:
    meta, raw = fm(open(f, encoding='utf-8').read())
    prev, _ = fm(subprocess.run(['git', 'show', '017a28b:' + f], capture_output=True, text=True).stdout)
    if not isinstance(meta.get('description'), str) or len(raw) > 200: bad.append(f'{f}: {len(raw)} chars')
    if {k: v for k, v in meta.items() if k != 'description'} != {k: v for k, v in prev.items() if k != 'description'}:
        bad.append(f'{f}: other keys changed')
if bad: print('\n'.join(bad)); sys.exit(1)
print(f'AGENT-DESC-OK ({len(now)} agents)')
PY
