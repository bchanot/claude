#!/usr/bin/env bash
# GATE 0 oracle, contract w3b: every routing.json phase carries a 1-120 char `about`.
set -u
python3 -I - <<'PY'
import json,sys
r=json.load(open('mods/model-router/routing.json'))
ok=all(isinstance(v.get('about'),str) and 0<len(v['about'])<=120 for v in r['phases'].values())
print('W3B-ABOUT' if ok else 'W3B-ABOUT-MISSING'); sys.exit(0 if ok else 1)
PY
