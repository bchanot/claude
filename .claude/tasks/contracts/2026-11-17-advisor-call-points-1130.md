# CONTRACT — advisor-call-points, run A (BDR-150 amendment)
- date: 2026-11-17 | flow: feat | branch: feature/advisor-call-points (off develop)
- status: active
- plan: .claude/tasks/plans/2026-11-17-advisor-call-points-1130.md (r4)

## REQUEST (verbatim — IMMUTABLE)
User 2026-11-17, after the transcript count (main loop 2 advisor calls on Opus, 409k/680k uncached tokens; 18 of 20 opus sub-agents 19 calls on Fable, median 70k; sonnet 0 of 8), answering the three proposals: "oui 1 et 2, et le 3 aussi". Proposal 1: let the judgment agents (plan-challenger, verifier, security-auditor) call the advisor once, before their verdict; sonnet executors stay without; for the security-auditor, advice can add a finding or raise a severity, never clear a semgrep HIGH or CRITICAL. Proposal 2: name the main loop's call points in the skills rather than leave them to its judgment: before settling the approach (ahead of the plan of /feat, /bugfix, /ship-feature), at the second failure of a gate loop before re-dispatching or escalating, and before proposing the merge; the text lives in lib/effort-shift.md § Advisor, the skills cite it, the doctrine-citers census checks it. Proposal 3: count advisor calls per session (main loop vs sub-agents, model served).

## CLARIFICATIONS
- [gated 2026-11-17] user: split in runs. Run A (this contract) = doctrine (CLAUDE.global.md, lib/effort-shift.md § Advisor) + the three judgment agents. Run B = inline call lines in skills/feat, skills/bugfix, skills/ship-feature, lib/verify-secure-loop.md. Run C = the counter.
- [gated 2026-11-17] user: the counter (proposal 3) is a section of /memory-feedback (run C).
- [internal 2026-11-17] gates round 1 (verifier CONFORME, security PASS) flagged block E: a raise double-counted in BLOCK(n), a no-class finding had no severity → block E r5 (plan), criterion 4 gains 'so it counts once' and 'REPORTED as LOW'.
- [gated 2026-11-17] user: an advisor-added or -raised security finding takes the severity of the STEP 3 checklist class it matches; no matching class → REPORTED, non-blocking (block E r4).
- [internal 2026-11-17] executor NEED-DECISION: block B line reworded to "(for work outside them, see the / triggers in CLAUDE.global.md § Workflow):" (census T3 read "§ Workflow names").
- [internal 2026-11-17] re-challenge → plan r4 (section "r4 changes"): criterion 1 markers + 315 lines, criterion 2/4 markers, EVIDENCE: pending lines.
- [internal 2026-11-17] challenge round 1 → plan r3 (section "r3 changes"): criteria re-scoped (criterion 2 counts STEP inside § Advisor only), blocks per r3.
- [internal 2026-11-17] advisor review: blocks C-E carry "absent or erroring → proceed" (they read their agent file and CLAUDE.global.md, never lib/effort-shift.md); block E carries a grounding clause (added or raised finding cites a file:line read); "at most once" wording in both block A and B; no skill step numbers in block B.

## RELATED MEMORY
- BDR-150 (accepted): amended here, "sub-agents do not" (c3507ea) becomes "the three judgment agents at most once"; "never routed or pinned" kept.
- LRN-294: honored, scope set from observed tool lists, rest named a prose rule.
- BDR-066 / LRN-083: loop decisions stay in the main loop; advice is input.

## ACCEPTANCE CRITERIA
1. CLAUDE.global.md carries block A: the three-agent scope and the § Advisor pointer.
   CHECK: cd /home/bchanot/Documents/claude && echo "$({ grep -c 'and security-auditor at most once, before the verdict; other' CLAUDE.global.md || true; })/$({ grep -c 'sub-agents do not. Fable is never routed' CLAUDE.global.md || true; })/$({ grep -cF '`~/.claude/lib/effort-shift.md` § Advisor' CLAUDE.global.md || true; })/$(wc -l < CLAUDE.global.md)"
   EXPECT: 1/1/1/315
   EVIDENCE: MET exit=0 marker-found :: 1/1/1/315
2. lib/effort-shift.md § Advisor carries block B, with no skill step number.
   CHECK: cd /home/bchanot/Documents/claude && sec() { sed -n '/^## Advisor/,/^## Never/p' lib/effort-shift.md; }; echo "$(grep -c '^## Advisor' lib/effort-shift.md)/$(sec | grep -c 'Main loop, at least at these points')/$(sec | grep -c 'once per verify-secure run, at the first gate loop')/$(sec | grep -c 'never enters an executor brief')/$(sec | grep -c 'once per dispatch, before their verdict')/$(sec | grep -c STEP)"
   EXPECT: 1/1/1/1/1/0
   EVIDENCE: MET exit=0 marker-found :: 1/1/1/1/1/0
3. Each judgment agent carries its one-call rule with the proceed clause.
   CHECK: cd /home/bchanot/Documents/claude && for f in plan-challenger verifier security-auditor; do printf '%s/' "$({ grep -c 'Advisor (when listed): at most one call' agents/$f.md || true; })$({ grep -c 'erroring → proceed' agents/$f.md || true; })"; done; echo
   EXPECT: 11/11/11/
   EVIDENCE: MET exit=0 marker-found :: 11/11/11/
4. Advice can only add: security-auditor routes and tags it, verifier and plan-challenger never clear.
   CHECK: cd /home/bchanot/Documents/claude && echo "$({ grep -c 'It never removes,' agents/security-auditor.md || true; })/$({ grep -c 'BLOCK(n) like any other' agents/security-auditor.md || true; })/$({ grep -c 'so it counts once' agents/security-auditor.md || true; })/$({ grep -c 'is REPORTED as LOW,' agents/security-auditor.md || true; })/$({ grep -c 'Advice alone never clears a' agents/verifier.md || true; })/$({ grep -c 'alone never drops or lowers one' agents/plan-challenger.md || true; })"
   EXPECT: 1/1/1/1/1/1
   EVIDENCE: MET exit=0 marker-found :: 1/1/1/1/1/1
5. Full make test green (run with GATES_TIMEOUT=400).
   CHECK: cd /home/bchanot/Documents/claude && PATH=$HOME/.bun/bin:$PATH make test </dev/null 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green
6. Touched lines ≤ 80 columns; blocks applied verbatim from plan r4; no other wording changed in the five files (manual).

## FILE SCOPE
CLAUDE.global.md (§ Workflow bullet ~:81-85), lib/effort-shift.md (§ Advisor body ~:103-110), agents/plan-challenger.md (§ RULES), agents/verifier.md (§ RULES), agents/security-auditor.md (§ RULES).
