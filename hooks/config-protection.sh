#!/usr/bin/env bash
# config-protection.sh
#
# PreToolUse hook (Edit|Write|MultiEdit). Blocks edits to this config's
# quality-gate files — the guardrails an agent must not silently weaken to make
# an error "pass" (permission/hook registry, gitflow enforcement, the git
# pre-commit guard, the hooks themselves, the test suite, the health diagnostic,
# lint config). Exit 2 blocks the tool call and feeds the message back to the
# model (Claude Code PreToolUse contract).
#
# It fires only on the model's Edit/Write tool calls — never on shell-level file
# ops (the cp/ln in install.sh, link.sh), so bootstrap/deploy is unaffected.
#
# One-shot escape hatch: create .claude/.config-edit-ok (CWD-relative) with a
# NON-EMPTY reason inside; the hook logs the reason, consumes (rm) the sentinel,
# and allows that single edit. It never persists — a lingering sentinel would be
# a footgun. Discipline, per CLAUDE.md "Root causes only. No temp fixes.": fix
# the code, don't loosen the gate. Fails OPEN (exit 0) on parse failure so it can
# never wedge editing.

set -euo pipefail

log="${HOME}/.claude/logs/config-protection.log"
sentinel="${PWD}/.claude/.config-edit-ok"

input="$(cat)"
path="$(printf '%s' "$input" \
  | python3 -c 'import sys, json; print(json.load(sys.stdin).get("tool_input", {}).get("file_path", ""))' \
  2>/dev/null || true)"
[ -z "$path" ] && exit 0

# Guardrail files, matched by path suffix (covers both the repo source and the
# deployed ~/.claude copy). Precise: lib/gitflow.sh only, not gitflow-migrate.sh.
case "$path" in
  */.claude/settings.json|*/.claude/settings.local.json|*/claude/settings.json) ;;
  */lib/gitflow.sh|*/.githooks/*|*/doctor.sh) ;;
  */hooks/*.sh|*/lib/tests/*) ;;
  */.shellcheckrc|*/.markdownlint.json|*/.editorconfig) ;;
  *) exit 0 ;;
esac

# One-shot sentinel bypass: non-empty reason required; consumed on sight.
if [ -f "$sentinel" ]; then
  reason="$(head -c 500 "$sentinel" 2>/dev/null | tr '\n\r\t' '   ' || true)"
  rm -f "$sentinel"
  if printf '%s' "$reason" | grep -q '[^[:space:]]'; then
    mkdir -p "$(dirname "$log")"
    printf '%s\tBYPASS\t%s\treason=%s\n' "$(date -Iseconds)" "$path" "$reason" >> "$log"
    exit 0
  fi
  printf '%s\n' "[config-protection] .claude/.config-edit-ok had an EMPTY reason -> refused (sentinel consumed). Recreate it with a non-empty reason." >&2
  exit 2
fi

cat >&2 <<EOF
[config-protection] BLOCKED edit to a quality-gate file:
  $path
This is a guardrail (permission/hook registry, gitflow enforcement, git
pre-commit guard, a hook, the test suite, health diagnostic, or lint config).
Don't weaken the gate to make an error pass — fix the root cause instead
(CLAUDE.md: "Root causes only. No temp fixes."). To make one intended edit,
create .claude/.config-edit-ok with a non-empty reason; it is logged and
consumed (one-shot).
EOF
exit 2
