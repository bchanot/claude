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

If Scenario A holds, the chain is coupled (docs committed in the same breath as the
flow) and surgical (no dangling code embarked). If Scenario B holds, the guard is
fail-closed and loud. This mirrors what feat / bugfix / hotfix do at their DOC SYNC
step (inline-branch commit, no FINISH), and what ship-feature / init-project do at
their DOC SYNC step BEFORE FINISH (so the doc commit reaches the merge/PR).
