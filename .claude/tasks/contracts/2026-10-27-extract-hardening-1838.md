# CONTRACT — extract-hardening
- date: 2026-10-27 | flow: feat | branch: feature/extract-hardening (off develop 06012ea)
- status: active

## REQUEST (verbatim — IMMUTABLE)
lib/project-rules.sh `extract` hardening (TODO.md line 26, security gate 2026-10-27 follow-up): (1) check the rc of the `> "$out"` rule write group and of `mkdir -p` before rewriting `$src`, so a failed rule write leaves the source untouched and returns rc 2 (today the section is still removed with rc 0); (2) refuse an `<out>` that already exists (`[ -e "$out" ] || [ -L "$out" ]`), is absolute, or contains a `..` component, rc 2 with nothing written; (3) align agents/onboarder.md MODE: split S0.3 prose with the lib (`####x` is rejected, not a bare title). Tests in lib/tests/project-rules.test.sh for each refusal and for the untouched source on a failed write.

## CLARIFICATIONS
(pass A: none — request complete)

## ACCEPTANCE CRITERIA
1. `extract` whose `mkdir -p "$(dirname "$out")"` fails (a file sits where the parent dir must be) is rc 2, nothing written, source unchanged.
2. `extract` whose rule write (`{ … } > "$out"`) fails (parent dir not writable) is rc 2, no rule file left behind, source unchanged: the heading still occurs once.
   CHECK: bash lib/tests/project-rules.test.sh | tail -1
   EXPECT: FAIL=0
   EVIDENCE: MET exit=0 marker-found :: PASS=139 FAIL=0
3. `extract` refuses, rc 2 and nothing written: an absolute `<out>`, an `<out>` with a `..` component (`a/../b`, `../b`, `a/..`), an `<out>` that exists, an `<out>` that is a dangling symlink (`-L` true, `-e` false). The refusal names the reason on stderr. Each refusal runs before any glob check or temp file.
4. Every pre-existing extract contract holds: T7-T13 of the suite unchanged and green; `##` behaviour byte-identical (no change to the awk helpers).
5. `agents/onboarder.md` MODE: split S0.3 follows the lib's case order, refusal first: a heading starting with `# ` or `####` (space or not) is refused by the lib (rc 2, STOP with the row); a row starting with `## ` → STOP (a bare row carries no `## `); then `### ` is a subsection; then any other leading `#` (`#1 priority`) is a bare `##` title. A sequential reader can no longer land `####x` on the bare-title clause. No other prose change.
   CHECK: grep -q '####' agents/onboarder.md && echo H4-NAMED
   EXPECT: H4-NAMED
   EVIDENCE: MET exit=0 marker-found :: H4-NAMED
6. `lib/project-rules.sh` stays shellcheck clean, every line ≤ 80 chars, functions ≤ 25 logic lines and ≤ 5 locals; no `# shellcheck disable` added.
   CHECK: shellcheck lib/project-rules.sh lib/tests/project-rules.test.sh && [ -z "$(awk 'length > 80' lib/project-rules.sh)" ] && ! grep -q 'shellcheck disable' lib/project-rules.sh && echo WIDTH-OK
   EXPECT: WIDTH-OK
   EVIDENCE: MET exit=0 marker-found :: WIDTH-OK
7. `make test` all GREEN.
   CHECK: make test 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green
8. `bash lib/project-rules.sh check` still prints `4 rule(s) ok` on this repo.
   CHECK: bash lib/project-rules.sh check | tail -1
   EXPECT: project-rules: 4 rule(s) ok
   EVIDENCE: MET exit=0 marker-found :: project-rules: 4 rule(s) ok

## FILE SCOPE
lib/project-rules.sh, lib/tests/project-rules.test.sh, agents/onboarder.md (§ MODE: split S0.3 only)
