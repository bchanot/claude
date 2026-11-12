#!/usr/bin/env bash
# GATE 0 oracle, contract 2026-10-10-model-router-w3a-confirm: routing.json
# is the single source of phases + rows; register.ts rows are empty.
set -u
python3 - <<'PY'
import json,re,sys
r=json.load(open('mods/model-router/routing.json'))
src=open('mods/model-router/hooks/register.ts').read()
ph=set(re.findall(r"^\s+([a-z]+): \{ tier:", re.search(r"phases: \{(.*?)\n  \}", src, re.S).group(1), re.M))
jp=set(r.get('phases',{}).keys())
ok = jp==ph and len(r['skills'])==56 and len(r['agents'])==23
ok = ok and all(v in jp for v in list(r['skills'].values())+list(r['agents'].values()))
ok = ok and isinstance(r.get('confirmed'),dict) and isinstance(r.get('ask'),bool) and 'version' not in r
ok = ok and bool(re.search(r"\n  skills: \{\},", src)) and bool(re.search(r"\n  agents: \{\},", src))
print('W3A-ROUTING-FILE' if ok else 'W3A-ROUTING-BAD'); sys.exit(0 if ok else 1)
PY
