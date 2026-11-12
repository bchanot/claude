#!/usr/bin/env bash
# usage: run.sh <label> <cmdfile> [settings]  -> label<TAB>verdict<TAB>sent<TAB>final
label=$1; cmd=$(cat "$2"); st=${3:-s.json}
out=$(printf 'Run exactly this Bash command, verbatim, as ONE tool call, nothing else, no explanation before:\n%s\nThen reply with one word: RAN if the tool executed it, DENIED if the tool refused it.\n' "$cmd" \
  | timeout 150 claude -p --setting-sources local --settings "$st" --strict-mcp-config --tools Bash --model haiku --output-format stream-json --verbose 2>&1)
printf '%s' "$out" | python3 -I -c '
import sys,json
label=sys.argv[1]; sent=""; verdict="NO_TOOL_CALL"; final=""
for l in sys.stdin:
    try: j=json.loads(l)
    except: continue
    if j.get("type")=="result": final=str(j.get("result","")).strip().replace("\n"," ")[:60]; continue
    m=j.get("message"); cont=m.get("content") if isinstance(m,dict) else None
    if not isinstance(cont,list): continue
    for c in cont:
        if c.get("type")=="tool_use" and sent=="": sent=c["input"].get("command","")
        if c.get("type")=="tool_result" and verdict=="NO_TOOL_CALL":
            t=str(c.get("content"))
            verdict="DENIED" if "has been denied" in t else ("ERR:"+t[:40] if c.get("is_error") else "RAN")
print("%s\t%s\t%s\t%s"%(label,verdict,sent.replace("\n","\\n")[:70],final))
' "$label"
