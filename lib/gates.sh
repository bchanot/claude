#!/usr/bin/env bash
# Deterministic floor under GATE 1: execute the acceptance criteria that the
# contract itself declares as oracles, fail-closed, and persist the evidence
# INTO the contract file.
#
#   bash ~/.claude/lib/gates.sh status <contract>   # parse only, never runs
#   bash ~/.claude/lib/gates.sh run    <contract>   # execute + write evidence
#
# rc 0 = MET       every runnable criterion passed, no abandonment standing
#    2 = UNMET     a runnable criterion failed, or the ledger is malformed
#    3 = ABANDONED runnable criteria all passed, an abandonment still stands
#
# WHY: GATE 1 (lib/verify-secure-loop.md) is an LLM dispatch, and the
# verifier's mandatory `PROOF:` line is a line the verifier WRITES — nothing
# structurally stops it from being produced without anything being executed.
# This runs what the contract declares BEFORE a verifier is ever spawned: a
# red floor sends the executor back for free. Adapted from the `unlazy` skill
# (Leonxlnx/unlazy) — its gate ledger, minus the machinery we do not need.
#
# `run` always re-executes every runnable criterion, including ones already
# recorded MET. Trusting written evidence is exactly the failure this closes,
# so there is no incremental mode to get it wrong with.
#
# TRUST BOUNDARY: `CHECK:` is shell code, run with this process's privileges
# and environment. That is safe here only because the contract is authored by
# our own orchestrator in our own repo — which is why there is no approval
# store (we never execute ledgers inherited from a foreign repo). NEVER build
# a `CHECK:` out of externally-supplied text; route such values through
# lib/url-guard.sh first.
set -uo pipefail

TIMEOUT="${GATES_TIMEOUT:-120}"
EVIDENCE_CAP=140

# Module-level parse tables, index-aligned. Bash has no record type; threading
# eight parallel arrays through every call would cost more readability than
# the explicit data flow buys.
_ID=(); _TEXT=(); _CHECK=(); _EXPECT=(); _EVLINE=(); _EVTEXT=()
_STATUS=(); _EVID=()
_ABANDON_ID=(); _ABANDON_WHY=()
_ERRORS=()
_CUR=-1

_die() { printf 'GATES — VERDICT: ERROR(%s)\n' "$1"; exit 2; }
_err() { _ERRORS+=("$1"); }

_trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  printf '%s' "${s%"${s##*[![:space:]]}"}"
}

# ── parse ───────────────────────────────────────────────────────────────────

_new_crit() { # _new_crit <id> <text>
  local i
  for ((i = 0; i < ${#_ID[@]}; i++)); do
    if [ "${_ID[i]}" = "$1" ]; then
      _err "duplicate criterion id: $1"
      # Orphan what follows instead of aliasing it onto the previous
      # criterion, which would hand one gate another gate's oracle.
      _CUR=-1
      return 0
    fi
  done
  _ID+=("$1"); _TEXT+=("$2")
  _CHECK+=(""); _EXPECT+=(""); _EVLINE+=("0"); _EVTEXT+=("")
  _CUR=$((${#_ID[@]} - 1))
}

_set_attr() { # _set_attr <CHECK|EXPECT|EVIDENCE> <value> <lineno>
  if [ "$_CUR" -lt 0 ]; then
    _err "$1 at line $3 belongs to no criterion"
    return 0
  fi
  case "$1" in
    CHECK)    _CHECK[_CUR]="$2" ;;
    EXPECT)   _EXPECT[_CUR]="$2" ;;
    EVIDENCE) _EVLINE[_CUR]="$3"; _EVTEXT[_CUR]="$2" ;;
  esac
}

# An UNINDENTED attribute is diagnosed, never absorbed: silently ignoring it
# would demote a runnable criterion to a manual one, which is the one parse
# bug that turns this checker into a rubber stamp.
_absorb() { # _absorb <raw-line> <lineno>
  local body
  if [[ "$1" =~ ^([0-9]+)\.[[:space:]]+(.*)$ ]]; then
    _new_crit "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
  elif [[ "$1" =~ ^ABANDON:[[:space:]]*([0-9]+)?[[:space:]]*(.*)$ ]]; then
    _ABANDON_ID+=("${BASH_REMATCH[1]}"); _ABANDON_WHY+=("${BASH_REMATCH[2]}")
  elif [[ "$1" =~ ^(CHECK|EXPECT|EVIDENCE): ]]; then
    _err "unindented ${BASH_REMATCH[1]}: at line $2"
  elif [[ "$1" =~ ^[[:space:]]+(CHECK|EXPECT|EVIDENCE):(.*)$ ]]; then
    body="$(_trim "${BASH_REMATCH[2]}")"
    _set_attr "${BASH_REMATCH[1]}" "$body" "$2"
  fi
}

_parse() { # _parse <file>
  local line n=0 fence=0 inblock=0
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n + 1))
    case "$line" in '```'*) fence=$((1 - fence)); continue ;; esac
    [ "$fence" -eq 1 ] && continue
    case "$line" in
      '## ACCEPTANCE CRITERIA'*) inblock=1; continue ;;
      '## '*) inblock=0; continue ;;
    esac
    [ "$inblock" -eq 1 ] && _absorb "$line" "$n"
  done < "$1"
}

# ── validation ──────────────────────────────────────────────────────────────

_validate_oracles() {
  local i
  for ((i = 0; i < ${#_ID[@]}; i++)); do
    if [ -n "${_CHECK[i]}" ] && [ -z "${_EXPECT[i]}" ]; then
      _err "criterion ${_ID[i]}: CHECK without EXPECT (partial oracle)"
    elif [ -z "${_CHECK[i]}" ] && [ -n "${_EXPECT[i]}" ]; then
      _err "criterion ${_ID[i]}: EXPECT without CHECK (partial oracle)"
    elif [ -n "${_CHECK[i]}" ] && [ "${_EVLINE[i]}" = "0" ]; then
      _err "criterion ${_ID[i]}: runnable but has no EVIDENCE: line"
    fi
  done
}

_validate_abandons() {
  local i j found
  for ((i = 0; i < ${#_ABANDON_ID[@]}; i++)); do
    found=0
    for ((j = 0; j < ${#_ID[@]}; j++)); do
      [ "${_ID[j]}" = "${_ABANDON_ID[i]}" ] && found=1
    done
    [ "$found" -eq 1 ] ||
      _err "ABANDON names unknown criterion: '${_ABANDON_ID[i]}'"
    [ -n "$(_trim "${_ABANDON_WHY[i]}")" ] ||
      _err "ABANDON ${_ABANDON_ID[i]}: blank reason (a handoff needs one)"
  done
}

_is_abandoned() { # _is_abandoned <criterion-id>
  local i
  for ((i = 0; i < ${#_ABANDON_ID[@]}; i++)); do
    [ "${_ABANDON_ID[i]}" = "$1" ] && return 0
  done
  return 1
}

# ── execution ───────────────────────────────────────────────────────────────

# One line, capped, newlines flattened: the smallest output that proves the
# outcome. Full logs stay in the terminal, never in the contract.
_decisive() { # _decisive <combined-output>
  local flat
  flat="$(printf '%s' "$1" | tr '\n\r\t' '   ' | tr -s ' ')"
  flat="$(_trim "$flat")"
  if [ "${#flat}" -gt "$EVIDENCE_CAP" ]; then
    printf '%s…' "${flat:0:$EVIDENCE_CAP}"
  else
    printf '%s' "$flat"
  fi
}

# Fail-closed: exit 0 AND the marker. A nonzero process never passes because
# its error text happens to contain the expected token.
_run_one() { # _run_one <idx>
  local i="$1" out rc
  out="$(timeout "$TIMEOUT" bash -c "${_CHECK[i]}" 2>&1)"
  rc=$?
  _STATUS[i]="NOT-MET"
  if [ "$rc" -eq 124 ]; then
    _EVID[i]="NOT-MET timeout=${TIMEOUT}s"
  elif [ "$rc" -ne 0 ]; then
    _EVID[i]="NOT-MET exit=$rc (nonzero) :: $(_decisive "$out")"
  elif [[ "$out" != *"${_EXPECT[i]}"* ]]; then
    _EVID[i]="NOT-MET exit=0 marker-absent :: $(_decisive "$out")"
  else
    _STATUS[i]="MET"
    _EVID[i]="MET exit=0 marker-found :: $(_decisive "$out")"
  fi
}

_run_all() {
  local i
  for ((i = 0; i < ${#_ID[@]}; i++)); do
    _STATUS[i]=""; _EVID[i]=""
    [ -n "${_CHECK[i]}" ] && _run_one "$i"
  done
}

_evline_owner() { # _evline_owner <lineno> — echoes idx, or nothing
  local i
  for ((i = 0; i < ${#_ID[@]}; i++)); do
    if [ "${_EVLINE[i]}" = "$1" ] && [ -n "${_EVID[i]}" ]; then
      printf '%s' "$i"
      return 0
    fi
  done
}

# Rewrites only the EVIDENCE lines of criteria that actually ran; every other
# byte of the contract is copied through, indentation included.
_write_back() { # _write_back <file>
  local tmp line n=0 idx
  tmp="$(mktemp)" || _die "mktemp failed"
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n + 1))
    idx="$(_evline_owner "$n")"
    if [ -n "$idx" ]; then
      printf '%s%s\n' "${line%%[![:space:]]*}" "EVIDENCE: ${_EVID[idx]}"
    else
      printf '%s\n' "$line"
    fi
  done < "$1" > "$tmp"
  cat "$tmp" > "$1" && rm -f "$tmp"
}

# ── report ──────────────────────────────────────────────────────────────────

# A recorded `pending`, or a criterion that never ran, is PENDING — never MET.
# `status` reports what the file says; it does not revalidate old evidence.
_row_state() { # _row_state <idx>
  local i="$1"
  _is_abandoned "${_ID[i]}" && { printf 'ABANDONED'; return 0; }
  [ -z "${_CHECK[i]}" ] && { printf 'MANUAL'; return 0; }
  [ -n "${_STATUS[i]:-}" ] && { printf '%s' "${_STATUS[i]}"; return 0; }
  case "${_EVTEXT[i]}" in
    MET' '*) printf 'MET-RECORDED' ;;
    *) printf 'PENDING' ;;
  esac
}

_report_rows() {
  local i state
  for ((i = 0; i < ${#_ID[@]}; i++)); do
    state="$(_row_state "$i")"
    printf '  %-3s %-13s %s\n' "${_ID[i]}" "$state" "${_TEXT[i]}"
  done
}

_report_abandons() {
  local i
  for ((i = 0; i < ${#_ABANDON_ID[@]}; i++)); do
    printf '  ABANDONED %s — %s\n' "${_ABANDON_ID[i]}" "${_ABANDON_WHY[i]}"
  done
}

_count_state() { # _count_state <state>
  local i n=0
  for ((i = 0; i < ${#_ID[@]}; i++)); do
    [ "$(_row_state "$i")" = "$1" ] && n=$((n + 1))
  done
  printf '%s' "$n"
}

_verdict() { # _verdict <mode> — prints the line, returns the rc
  local unmet pending abandoned
  if [ "${#_ERRORS[@]}" -gt 0 ]; then
    printf 'GATES — VERDICT: ERROR(%s)\n' "${#_ERRORS[@]}"
    return 2
  fi
  unmet="$(_count_state NOT-MET)"
  pending="$(_count_state PENDING)"
  abandoned="$(_count_state ABANDONED)"
  [ "$unmet" -gt 0 ] &&
    { printf 'GATES — VERDICT: UNMET(%s)\n' "$unmet"; return 2; }
  if [ "$1" = "status" ] && [ "$pending" -gt 0 ]; then
    printf 'GATES — VERDICT: PENDING(%s)\n' "$pending"
    return 2
  fi
  [ "$abandoned" -gt 0 ] &&
    { printf 'GATES — VERDICT: ABANDONED(%s)\n' "$abandoned"; return 3; }
  printf 'GATES — VERDICT: MET\n'
  return 0
}

_report() { # _report <mode> <file>
  local rc
  printf 'GATES — %s (%s)\n' "$2" "$1"
  _report_rows
  _report_abandons
  [ "${#_ERRORS[@]}" -gt 0 ] && printf '  ERROR %s\n' "${_ERRORS[@]}"
  printf 'RUNNABLE: %s of %s criteria; timeout %ss\n' \
    "$(_runnable_count)" "${#_ID[@]}" "$TIMEOUT"
  _verdict "$1"
  rc=$?
  return "$rc"
}

_runnable_count() {
  local i n=0
  for ((i = 0; i < ${#_ID[@]}; i++)); do
    [ -n "${_CHECK[i]}" ] && n=$((n + 1))
  done
  printf '%s' "$n"
}

# ── entry point ─────────────────────────────────────────────────────────────

main() { # main <status|run> <contract>
  local mode="$1" file="$2"
  [ -r "$file" ] || _die "contract unreadable: $file"
  _parse "$file"
  [ "${#_ID[@]}" -gt 0 ] ||
    _die "no numbered criteria under ## ACCEPTANCE CRITERIA"
  _validate_oracles
  _validate_abandons
  if [ "$mode" = "run" ] && [ "${#_ERRORS[@]}" -eq 0 ]; then
    _run_all
    _write_back "$file"
  fi
  _report "$mode" "$file"
}

case "${1:-}" in
  status|run)
    [ $# -eq 2 ] || _die "usage: gates.sh {status|run} <contract-path>"
    main "$1" "$2"
    ;;
  *) _die "usage: gates.sh {status|run} <contract-path>" ;;
esac
