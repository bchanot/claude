# Behavioral check — doc-sync coupled, end-to-end

The deterministic suite (`run-doc-commit.sh`, T1–T7) proves `doc-commit.sh` in
isolation. This is the in-vivo whole-chain check: a real dev-flow shape — code
commit, then doc-syncer patches public docs, then the include commits them — with
dangling code AND a forbidden `.claude/` path present, proving the doc commit is
coupled, surgical, AND fail-closed on an upstream scope violation.

## Scenario A — coupled + surgical (the happy path)

```bash
R="$(mktemp -d)"; cd "$R"
git init -q && git config user.email t@t.t && git config user.name t
mkdir -p .claude/memory docs src
printf '# Proj\n' > README.md
printf 'baseline\n' > .claude/memory/decisions.md
git add -A && git commit -qm baseline

# 1) the flow commits CODE
printf 'feature code\n' > src/feature.txt
git add -- src/feature.txt && git commit -qm "feat: the feature"

# 2) doc-syncer patches public docs (a modified README + a created docs page).
#    It would surface PATCHED_FILES, ONE PATH PER LINE:
#       README.md
#       docs/usage.md
printf '\n## New feature\nUse --export.\n' >> README.md
printf 'usage guide\n' > docs/usage.md

# 3) a code file is left dangling (must NOT be embarked)
printf 'WIP do not commit\n' > src/dangling.txt

# 4) the include passes EACH PATCHED_FILES line as a SEPARATE arg (argv, space-safe)
doc_hash="$(bash "$HOME/.claude/lib/doc-commit.sh" commit "docs: README + usage" "README.md" "docs/usage.md")"
```

### Expected (assert)
- Exactly TWO commits after baseline: the code commit, then the doc commit.
- The doc commit (`$doc_hash`) contains ONLY `README.md` + `docs/usage.md` — never
  `src/feature.txt` (already committed) or `src/dangling.txt` (WIP).
- `src/dangling.txt` is still untracked after the doc commit.
- No `.claude/**` path in the doc commit (doc-syncer never patches it; the helper
  guards it regardless).

## Scenario B — fail-closed guard (the upstream-anomaly path)

```bash
# A bug upstream surfaces a forbidden path in PATCHED_FILES (doc-syncer must never
# patch .claude/ — BDR-022). The include passes it through; the helper must REFUSE.
printf 'x\n' >> .claude/memory/decisions.md          # make the forbidden path dirty
printf '\n## later\n' >> README.md                   # a legit doc also changed
bash "$HOME/.claude/lib/doc-commit.sh" commit "docs: mixed" "README.md" ".claude/memory/decisions.md"
echo "rc=$?"
```

### Expected (assert)
- `rc=4` (scope violation), NOTHING committed — `README.md` is NOT half-committed.
- stderr is loud (`REFUSED …`) and NAMES the offender (`.claude/memory/decisions.md`).
- The include treats rc 4 as an upstream BDR-022 anomaly to investigate — not a
  silent skip. The refusal IS the alarm.

## Scenario C — fail-loud on a rejected commit (the masked-failure path)

```bash
# The gitflow pre-commit hook (or signing, or a protected branch) rejects the doc
# commit. The helper must NOT report success: no false "committed", no stale hash.
printf '#!/bin/sh\nexit 1\n' > "$R/.git/hooks/pre-commit"; chmod +x "$R/.git/hooks/pre-commit"
printf '\n## another section\n' >> README.md
out="$(bash "$HOME/.claude/lib/doc-commit.sh" commit "docs: rejected" "README.md")"
echo "rc=$? out=[$out]"
```

### Expected (assert)
- `rc=5` (commit rejected), `out` EMPTY (no stale hash leaked on stdout).
- stderr is loud (`COMMIT REJECTED …`) — never a false `committed`.
- HEAD did NOT move; the doc stays in the working tree, uncommitted. The orchestrator
  must surface this and NOT proceed to FINISH as if docs landed (doc-commit.md rc 5 row).

## Scenario D — MINOR-shape oracle escalates a SIGNIFICANT-in-disguise

```bash
# doc-syncer's LLM classified a drift MINOR, but the patch ADDS A SECTION HEADING —
# structurally not a factual tweak. The oracle must overrule the MINOR call.
printf '\n## Brand new feature\n\nA whole new capability.\n' >> USAGE.md   # the "MINOR" patch
bash "$HOME/.claude/lib/doc-shape.sh" check "USAGE.md"; echo "rc=$?"
```

### Expected (assert)
- `rc=1` (exceeds the MINOR envelope), stderr names the heading reason + `USAGE.md`.
- doc-syncer STEP A4 routes this to the SIGNIFICANT gate (`Apply? yes/no/select`) instead
  of the silent auto-commit — the deterministic oracle overrules the LLM (LRN-046).
- A genuine factual one-liner (changed command, no heading, small) returns `rc=0` and
  stays on the silent MINOR auto-commit path — zero friction (BDR-036 preserved).
- The oracle is a STRUCTURAL floor: a small meaning-changing edit with no heading still
  reads MINOR (rc 0). It reduces RISK-1's gross cases, it does not eliminate RISK-1.

If Scenario A holds, the chain is coupled (docs committed in the same breath as the
flow) and surgical (no dangling code embarked). If Scenario B holds, the guard is
fail-closed and loud. If Scenario C holds, a rejected commit fails LOUD instead of
masking as success. If Scenario D holds, a shape-suspect MINOR is escalated to the
human gate instead of auto-committed. This mirrors what feat / bugfix / hotfix do at
their DOC SYNC step (inline-branch commit, no FINISH), and what ship-feature /
init-project do at their DOC SYNC step BEFORE FINISH (so the doc commit reaches the merge/PR).
