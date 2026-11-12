# CONTRACT — doctrine-rules-graphify
- date: 2026-11-12 | flow: feat | branch: feature/doctrine-rules-graphify
- status: active

## REQUEST (verbatim — IMMUTABLE)
D1+D5+D6 from .claude/tasks/TODO.md § Release 3.0.0 scope (user decisions 2026-11-11 [gated], TODO:158). D1 doctrine: CLAUDE.global.md:52-54 "Session start 1. Read `.claude/memory/`" + skills/capitalize/SKILL.md:375 still state the full read at session start, while the 4c digest (hooks/session-start.sh) delivers open BLK + TODO + last journal; decision: digest at start + on-demand registry read, capitalize:375 aligned. D5 user rules: rules/web-security.md vs rules/secure-by-default.md: strict duplicates (web-security :11, :19, "Login rate limiting," in :20) and password wording conflict ("bcrypt/argon2" vs "argon2id (bcrypt or scrypt otherwise)"); decision: web-security keeps only its unique rules (cookie flags, upload type/size, forced HTTPS, security headers), points to secure-by-default, password = argon2id. D6 project rule: .claude/rules/graphify-vendored.md says `graphify install --platform claude` "touches nothing else", but graphifyy 0.9.67 appends a `# graphify` block to ~/.claude/CLAUDE.md (= CLAUDE.global.md); `graphify claude install` writes into the caller's cwd, so the install-plugins.sh trap protects $REPO only when run from $REPO; decision: rule text names the CLAUDE.global.md append + install-plugins.sh runs the graphify step from $REPO. Line numbers may have moved: re-locate. Grep every citer (doctrine-citers census in make test). make test needs GATES_TIMEOUT=600 + PATH=$HOME/.bun/bin:$PATH (LRN-271). Foreign-code style. In force: BDR-125, BDR-100, LRN-275 (explicit staging), LRN-276, LRN-277.

## CLARIFICATIONS
Q: plan? / A: .claude/tasks/plans/2026-11-12-doctrine-rules-graphify-1123.md, latest revision is binding (orchestrator)
Q: D1 Session start text (first answer, superseded)? / A: "digest + fallback" text: digest applied at start; no digest (foreign repo, memory mod off) → read TODO + open blockers yourself; full registry read on demand, planning flows read before planning; step "either missing → create" kept; capitalize:375 closing line "Next session: the startup digest shows open blockers, TODO and the last journal line." (user, 2026-11-12) [gated]
Q: D1 re-gate after challenge round 1 (`_digest_todo` reads only `### Actionable`, absent from init-project/onboard TODOs)? / A: TODO.md stays read at start; the digest gives open blockers + last journal line; no digest (foreign repo, memory mod off) → list open blockers yourself; registries read when the task needs it, planning flows scan them per `~/.claude/lib/analyze-before-plan.md`; capitalize:375 → "Next session: TODO.md and the startup digest (open blockers, last journal line)." Plan r2 holds the exact text (user, 2026-11-12) [gated]
Q: D1 digest `+N` count line hides upstream blockers (challenge round 2)? / A: add "a `+N` line → read those entries in `blockers.md`" to step 1 (user, 2026-11-12) [gated]
Q: TODO headings in other projects (user, 2026-11-12)? / A: follow-up run: make every project TODO readable by the digest (template/init-project/onboard heading, and existing TODOs or a digest fallback); out of this run, logged in TODO.md
Q: D5 lines partly covered by secure-by-default (service/admin key client-side, RLS on Postgres and kin, IDOR)? / A: drop the service-key line, keep IDOR and RLS generalized to Postgres and kin (user, 2026-11-12) [gated]
Q: MIGRATION.md:127 "Read `.claude/memory/`" diff? / A: historical 1.x upgrade step, left as is; the 3.0.0 MIGRATION section is a later run (orchestrator)

## ACCEPTANCE CRITERIA
1. D1: Session start reads TODO.md, names the digest (blockers + journal), the fallback and the on-demand registry scan; the full-read wording is gone from CLAUDE.global.md and capitalize.
   CHECK: cd /home/bchanot/Documents/claude && G=CLAUDE.global.md && C=skills/capitalize/SKILL.md && grep -q '1. Read `.claude/tasks/TODO.md`' $G && grep -q 'memory digest' $G && grep -q 'memory mod off' $G && grep -q 'a `+N` line' $G && grep -q 'analyze-before-plan.md' $G && ! grep -q 'Read `.claude/memory/` (5 registries' $G && ! grep -q 'read .claude/memory/ at startup' $C && grep -q 'Next session: TODO.md and the startup digest' $C && [ "$(LC_ALL=C.UTF-8 awk 'length>80' $G | wc -l)" -le 3 ] && echo D1-OK
   EXPECT: D1-OK
   EVIDENCE: MET exit=0 marker-found :: D1-OK
2. D5: web-security keeps its unique rules plus IDOR and RLS, points to secure-by-default, drops duplicates and the bcrypt wording; body lines at most 80 chars.
   CHECK: cd /home/bchanot/Documents/claude && W=rules/web-security.md && grep -q 'secure-by-default' $W && grep -q 'IDOR' $W && grep -q 'Row Level Security' $W && grep -q 'httpOnly' $W && grep -qi 'upload' $W && grep -q 'HTTPS' $W && grep -qi 'security headers' $W && ! grep -qi 'bcrypt' $W && ! grep -q 'No API key in code' $W && ! grep -q 'service/admin key' $W && ! grep -qi 'rate limit' $W && ! grep -q 'only the fields' $W && [ "$(tail -n +4 $W | awk 'length>80' | wc -l)" = 0 ] && echo D5-OK
   EXPECT: D5-OK
   EVIDENCE: MET exit=0 marker-found :: D5-OK
3. D6: the rule credits the skill copy to `graphify install`, names the CLAUDE.global.md append; install-plugins.sh runs `graphify claude install` only from $REPO.
   CHECK: cd /home/bchanot/Documents/claude && R=.claude/rules/graphify-vendored.md && ! grep -q 'Touches nothing else' $R && ! grep -q 'written by `graphify claude install`' $R && grep -q 'written by `graphify install`' $R && grep -q 'CLAUDE.global.md' $R && grep -qF '(cd "$REPO" && graphify claude install)' install-plugins.sh && ! grep -qE '^[[:space:]]*graphify claude install' install-plugins.sh && ! grep -q 'claude install failed — run manually' install-plugins.sh && bash -n install-plugins.sh && echo D6-OK
   EXPECT: D6-OK
   EVIDENCE: MET exit=0 marker-found :: D6-OK
4. Full suite green, shellcheck clean, project rules valid.
   CHECK: cd /home/bchanot/Documents/claude && shellcheck -S warning install-plugins.sh && bash lib/project-rules.sh check >/dev/null && GATES_TIMEOUT=600 PATH="$HOME/.bun/bin:$PATH" make test 2>&1 | tail -1 | grep -q 'all suites green' && echo GREEN
   EXPECT: GREEN
   EVIDENCE: MET exit=0 marker-found :: GREEN

## FILE SCOPE
CLAUDE.global.md (## Session start only), skills/capitalize/SKILL.md (the auto-persisted closing line only), rules/web-security.md, .claude/rules/graphify-vendored.md, install-plugins.sh (Step 7 `graphify claude install` line + the guard comment that says the trap is fully effective only from $REPO)
