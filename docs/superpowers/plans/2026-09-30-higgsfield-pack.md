# Higgsfield Pack Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `make plugin` installs the Higgsfield CLI and its skills, off by default, with two toggles to turn them on.

**Architecture:** A sourced helper (`lib/higgsfield-skills.sh`) clones the upstream skills into gitignored `skills-external/higgsfield-*` and probes the CLI; both installers and the doctor call it. `lib/toggle-external.sh` links the skills on demand through two tools: `higgsfield`, a fixed allowlist of seven media skills, and `higgsfield-websites`, a single skill. Nothing is listed in `link.sh` or in a profile, which is what keeps the pack off across re-runs.

**Tech Stack:** bash, git, npm (run by the user only), shellcheck, hermetic suites under `lib/tests/` run through `make test`.

**Spec:** `docs/superpowers/specs/2026-09-30-higgsfield-pack-design.md`
**Contract:** `.claude/tasks/contracts/2026-09-30-higgsfield-pack-1412.md` (14 criteria, binding)

## How this plan is packaged

Every edit below was dry-run in a scratch copy, task by task, in order. The
suite went 0/5 → 5/0 (Task 2), 6/8 → 14/0 (Task 3), 14/1 → 15/0 (Task 4),
15/1 → 16/0 (Task 5); shellcheck is clean; each patch applies to the branch;
three deliberate bugs injected in the scratch code turned the suite red. The
exact bytes live in `docs/superpowers/plans/2026-09-30-higgsfield-pack.patches/`. Each task shows its code inline for reading and
names the file to apply. Apply the file, never a retyped copy.

Apply a patch with `git apply <file>`. If `git apply` refuses (the target
moved), stop and report `BLOCKED` with the error. Do not hand-merge.

## Global Constraints

- Executors never run `install-plugins.sh`, `update-all.sh`, `link.sh`, `doctor.sh`, `npm install`, `npx`, `lib/toggle-external.sh` against the real repo, or `higgsfield_sync_skills` against the network (BDR-095). The suite is the only thing that runs.
- Tests run through `make test suite=lib/tests/<file>` only. Never call a suite with `bash` directly, never prefix the command with env variables.
- Nothing about Higgsfield goes in `link.sh`, `lib/profile.sh`, `lib/profiles/*.profile` or `lib/effort-pins.txt` (BDR-093, BDR-079, BDR-105, BDR-107). The suite locks this.
- The skill sync sits before the last `apply_effort_pins "$REPO"` in `install-plugins.sh` and `update-all.sh` (BDR-108, BLK-024).
- `lib/toggle-external.sh` takes no new top-level `source` (LRN-178).
- The CLI token never reaches a terminal or a log: `higgsfield auth token` is only ever called through `_higgsfield_probe` (helper) or `bounded` (toggle), both of which redirect to `/dev/null`.
- CLI presence is proven by `higgsfield_cli_ok` (the binary answers), never by `command -v higgsfield` alone: the npm shim can sit on PATH with no binary behind it.
- Media pack membership is the allowlist `HIGGSFIELD_MEDIA_SKILLS`, never a glob: upstream is unpinned, and an unlisted skill must stay unlinked (default deny).
- House limits for new code: functions of 25 logic lines at most, 5 parameters, 5 locals; logic lines within 80 columns (message strings on `ok | info | warn | err | echo | printf` lines and the existing long `case` patterns follow the surrounding installer style and may run longer); shellcheck clean; comments state intent.
- Commits: explicit paths only (`git add <paths>`), never `git add -A`, never `--no-verify`, no attribution trailer. The hooks push each commit.
- `CLAUDE.global.md` and `settings.json` are hand-curated (BDR-028): only the orchestrator touches them.

## Review Focus

1. A refresh while the pack is enabled: the live `skills/<name>` link must keep resolving. Pinned by `live-reads` in `SYNC_KEEPS_PARKED` (Task 2).
2. Upstream changes its layout (no `higgsfield-*/SKILL.md`, a pack-named dir without SKILL.md, a pack-named symlink): the sync must skip what is not a real skill directory, and return non-zero with the copies kept when nothing qualifies. Pinned by `noskill`, `symlink` and `no-skills` (Task 2).
3. Upstream adds or renames a skill: it is synced, reported, and never linked by `enable higgsfield`. Pinned by `UNLISTED_NOT_LINKED` (Task 3).
4. npm holds back the package's postinstall script, on a first install or on a later update, so the shim exists and the binary does not. `higgsfield_cli_ok` must say no (`shim-only` in `PROBES_SILENT`, Task 2), the toggle must name that cause and not "sign in" (`shim-*` in `SIGNED_OUT_WARNS`, Task 3), and both installers must gate on the probe (`probe-gates`, `probe-after-npm`, Tasks 4 and 5). The installer branches themselves cannot run in a suite: checked by reading.
5. The generalised pack arms must not change what `21st` prints or does. Pinned by `PACK_21ST_UNCHANGED` (Task 3).

## Rollback

Before reverting these commits on a machine where the pack was enabled, run `bash lib/toggle-external.sh disable higgsfield` and `disable higgsfield-websites`. Otherwise the live `skills/higgsfield-*` links outlive the toggle that knows them and the gitignore rule that hides them.

## Known limits (accepted)

- A skill that upstream removes or renames keeps its last local copy; nothing prunes it.
- Upstream prompts change with no diff to review (tracks `main`).
- Whether `higgsfield auth token` stays local is unverified (closed-source binary), hence the 15 s bound.

---

### Task 1: Lock entry and gitignore

**Files:**
- Modify: `plugins.lock.json` (new `higgsfield` entry before `graphifyy`)
- Modify: `.gitignore` (link side after `skills/21st-*`, source side and sync stage after `skills-external/21st-*/`)

**Interfaces:**
- Consumes: nothing.
- Produces: lock key `higgsfield` with `version` (read by Tasks 4 and 5); ignore rules `skills/higgsfield-*`, `skills-external/higgsfield-*/` and `skills-external/.higgsfield-stage.*/` (LRN-025: both states of a toggleable artifact).

- [ ] **Step 1: Apply the lock patch**

Run: `git apply docs/superpowers/plans/2026-09-30-higgsfield-pack.patches/01-lock.patch`

````diff
--- a/plugins.lock.json
+++ b/plugins.lock.json
@@ -25,6 +25,11 @@
     "version": "latest",
     "note": "21st.dev CLI (bin `21st`) — standalone CLI + a pack of 7 skills, no MCP, no API key: auth is `21st login` (browser token in ~/.config/21st). Install: npm install -g @21st-dev/cli. The skill pack is staged-installed into skills-external/21st-* by install-plugins.sh Step 8.7 — `21st skills install` refuses to write through the ~/.claude/skills symlink."
   },
+  "higgsfield": {
+    "source": "npm:@higgsfield/cli",
+    "version": "latest",
+    "note": "Higgsfield CLI (bins `higgsfield`, `higgs`) — image, video, audio and brand media generation, metered credits; auth is `higgsfield auth login` (browser). Install: npm install -g @higgsfield/cli. The package vendors its binary in a postinstall script; if npm holds it back, add --allow-scripts=@higgsfield/cli. The upstream skills are git-cloned from https://github.com/higgsfield-ai/skills (tracks main, no pin) into skills-external/higgsfield-* by lib/higgsfield-skills.sh (install-plugins.sh Step 8.6, refreshed by update-all.sh); a skill upstream removes keeps its last local copy. OFF by default and in no profile: `lib/toggle-external.sh enable higgsfield` links the 7 allowlisted media skills (HIGGSFIELD_MEDIA_SKILLS), `enable higgsfield-websites` the landing-page aid."
+  },
   "graphifyy": {
     "source": "pypi:graphifyy",
     "version": "latest",
````

- [ ] **Step 2: Apply the gitignore patch**

Run: `git apply docs/superpowers/plans/2026-09-30-higgsfield-pack.patches/01-gitignore.patch`

````diff
--- a/.gitignore
+++ b/.gitignore
@@ -101,6 +101,11 @@
 # membership, so the pack can gain a skill with no edit here.
 skills/21st-*
 
+# Higgsfield skill pack symlinks — created on demand by toggle-external.sh
+# (`enable higgsfield` / `enable higgsfield-websites`). The pack is OFF by
+# default and in no profile, so these usually don't exist.
+skills/higgsfield-*
+
 # Context7 docs-lookup skill — installed by `ctx7 setup --claude --cli`
 # (install-plugins.sh Step 6, when absent) into ~/.claude/skills (a symlink to
 # this repo's skills/). ctx7-managed and re-created on demand — not vendored here.
@@ -236,6 +241,13 @@
 # layout and the content is sha256-verified against 21st.dev's manifest.
 skills-external/21st-*/
 
+# Higgsfield skill pack — machine-owned: a git clone of higgsfield-ai/skills,
+# staged by lib/higgsfield-skills.sh (install-plugins.sh Step 8.6) and moved
+# here, refreshed by update-all.sh. Not vendored: it tracks upstream main.
+# The second line is the helper's stage, left behind only by a killed run.
+skills-external/higgsfield-*/
+skills-external/.higgsfield-stage.*/
+
 # npx `skills add` project-scope artifacts — darwin-skill copies itself into
 # the repo's .agents/ and writes skills-lock.json at root. Our own agents live
 # in agents/ (no dot) and stay tracked. Anchored to root so only the dotted
````

- [ ] **Step 3: Verify**

Run:
```bash
python3 -c "import json;d=json.load(open('plugins.lock.json'))['higgsfield'];assert d['version']=='latest' and 'managed_by' not in d;print('LOCK_OK')"
git check-ignore -q skills/higgsfield-generate && git check-ignore -q skills-external/higgsfield-generate/SKILL.md && git check-ignore -q skills-external/.higgsfield-stage.abc123/src/x && echo IGNORED_ALL
git check-ignore -q skills/feat/SKILL.md || echo CONTROL_OK
```
Expected: `LOCK_OK`, `IGNORED_ALL`, `CONTROL_OK` (a tracked skill is not ignored).

- [ ] **Step 4: Commit**

```bash
git add plugins.lock.json .gitignore
git commit -m "chore(higgsfield): lock entry and gitignore for the skill pack"
```

---

### Task 2: Sync helper, CLI probes and their suite

**Files:**
- Create: `lib/tests/higgsfield.test.sh` (from `docs/superpowers/plans/2026-09-30-higgsfield-pack.patches/02-higgsfield.test.sh`)
- Create: `lib/higgsfield-skills.sh` (from `docs/superpowers/plans/2026-09-30-higgsfield-pack.patches/02-higgsfield-skills.sh`)

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `HIGGSFIELD_SKILLS_URL` (env value wins over the upstream default).
  - `higgsfield_sync_skills <repo>`: prints the number of skills synced on stdout; returns 0 when at least one skill was synced, 1 otherwise (existing copies untouched). Stages inside `<repo>/skills-external/.higgsfield-stage.*` so each replacement is a rename on one filesystem.
  - `higgsfield_cli_ok`: returns 0 when `higgsfield version` answers; prints nothing.
  - `higgsfield_signed_in`: returns 0 when `higgsfield auth token` succeeds; prints nothing.
  - Internal: `_higgsfield_adopt <clone> <dest>`, `_higgsfield_probe <args...>`.
  - Suite helpers later tasks reuse: `expect`, `expect_has`, `expect_not`, `verdict`, `yn`, `entries`, `git_q`, `$WORK`, `$ROOT`, `$BIN` (fake `higgsfield` and `21st`), `$CLEAN` (a PATH with the core tools and no CLI); the file ends with a `# ── tally ──` block that must stay last.

- [ ] **Step 1: Write the failing suite**

Run: `cp docs/superpowers/plans/2026-09-30-higgsfield-pack.patches/02-higgsfield.test.sh lib/tests/higgsfield.test.sh`

````bash
#!/usr/bin/env bash
# lib/tests/higgsfield.test.sh — hermetic suite for the Higgsfield pack.
#   sync    lib/higgsfield-skills.sh against a local git repo shaped like
#           upstream (no network), and its CLI probes against a fake CLI
#   toggle  lib/toggle-external.sh `higgsfield` / `higgsfield-websites`
#           against a fixture tree, fake CLIs first on PATH
#   wiring  static locks on the installers (order, off by default)
# Each named case prints one `PASS <NAME>` or `FAIL <NAME>:<details>` line.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0; fail=0; errs=""

# expect <label> <got> <want> — record a mismatch for the current case.
expect() { [ "$2" = "$3" ] || errs="$errs $1(got[$2] want[$3])"; }
# expect_has / expect_not <label> <text> <fragment>
expect_has() { case "$2" in *"$3"*) ;; *) errs="$errs $1(lacks[$3])" ;; esac; }
expect_not() { case "$2" in *"$3"*) errs="$errs $1(has[$3])" ;; esac; }
# verdict <NAME> — close the current case: PASS when nothing was recorded.
verdict() {
  if [ -z "$errs" ]; then pass=$((pass + 1)); printf 'PASS %s\n' "$1"
  else fail=$((fail + 1)); printf 'FAIL %s:%s\n' "$1" "$errs"; fi
  errs=""
}
# yn <command...> — "yes" when the command succeeds, else "no".
yn() { if "$@" 2>/dev/null; then echo yes; else echo no; fi; }
# entries <dir> — how many entries the directory holds, hidden ones included.
entries() { find "$1" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' '; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Fake CLIs, first on PATH in every case that needs one. `higgsfield`
# answers per $FAKE_HF_BINARY (ok | missing: the npm shim without its
# binary) and $FAKE_HF_SESSION (in | out).
BIN="$WORK/bin"; mkdir -p "$BIN"
cat > "$BIN/higgsfield" <<'EOF'
#!/usr/bin/env bash
if [ "${FAKE_HF_BINARY:-ok}" = missing ]; then
  echo "@higgsfield/cli: binary not found" >&2; exit 1
fi
case "${1:-} ${2:-}" in
  "version ") echo "higgsfield 0.0.0 (fixture) built never"; exit 0 ;;
  "auth token")
    if [ "${FAKE_HF_SESSION:-in}" = in ]; then echo "fixture-token"; exit 0; fi
    echo "Error: Not authenticated." >&2; exit 2 ;;
esac
exit 64
EOF
cat > "$BIN/21st" <<'EOF'
#!/usr/bin/env bash
[ "${1:-}" = whoami ] && echo "Logged in as fixture (saved in fixture)."
EOF
chmod +x "$BIN/higgsfield" "$BIN/21st"

# A PATH that holds the tools the scripts under test need and nothing else:
# no `higgsfield`, no `timeout`, whatever this machine has installed.
CLEAN="$WORK/cleanbin"; mkdir -p "$CLEAN"
for t in bash dirname basename mkdir mv rm ln sed; do
  ln -s "$(command -v "$t")" "$CLEAN/$t"
done

# git_q <dir> <git args...> — quiet git in a fixture repo: own identity, no
# hooks, so the machine's global git config never leaks in.
git_q() {
  local dir="$1"; shift
  git -C "$dir" -c user.name=fixture -c user.email=fixture@example.invalid \
    -c core.hooksPath=/dev/null -c init.defaultBranch=trunk "$@" \
    >/dev/null 2>&1
}

# mk_upstream <dir> — a git repo shaped like the upstream skills repo: three
# pack skills, a pack-named dir with no SKILL.md, a pack-named symlink to
# a foreign skill, and root machinery that must never be synced.
mk_upstream() {
  local up="$1" s
  mkdir -p "$up/scripts" "$up/higgsfield-noskill" "$up/other-skill"
  for s in higgsfield-generate higgsfield-soul-id higgsfield-websites; do
    mkdir -p "$up/$s/references"
    printf -- '---\nname: %s\n---\n' "$s" > "$up/$s/SKILL.md"
    echo "ref" > "$up/$s/references/notes.md"
  done
  echo "old" > "$up/higgsfield-generate/old.md"
  echo "no skill here" > "$up/higgsfield-noskill/README.md"
  ln -s other-skill "$up/higgsfield-linked"
  echo "---" > "$up/other-skill/SKILL.md"
  echo "#!/bin/sh" > "$up/setup"
  echo "#!/bin/sh" > "$up/scripts/update-check.sh"
  git_q "$up" init
  git_q "$up" add -A
  git_q "$up" commit -m fixture
}

# sync_into <repo> [url] — run the helper in a subshell; prints "<rc>:<count>".
sync_into() {
  (
    export HIGGSFIELD_SKILLS_URL="${2:-$UP}"
    # shellcheck source=lib/higgsfield-skills.sh disable=SC1091
    source "$ROOT/lib/higgsfield-skills.sh"
    out="$(higgsfield_sync_skills "$1")"
    printf '%s:%s' "$?" "$out"
  )
}

# probe <path> <function> — run one CLI probe of the helper on the given
# PATH; prints everything it wrote, then "rc=<status>".
probe() {
  PATH="$1" bash -c 'source "$1/lib/higgsfield-skills.sh"; "$2"; echo "rc=$?"' \
    _ "$ROOT" "$2" 2>&1
}

# ── sync ────────────────────────────────────────────────────
UP="$WORK/upstream"; mk_upstream "$UP"
R1="$WORK/r1"; mkdir -p "$R1/skills" "$R1/skills-disabled"
EXT="$R1/skills-external"

expect fixture  "$(yn test -f "$UP/.git/HEAD")" yes
expect rc-count "$(sync_into "$R1")" "0:3"
expect generate "$(yn test -f "$EXT/higgsfield-generate/SKILL.md")" yes
expect refs \
  "$(yn test -f "$EXT/higgsfield-soul-id/references/notes.md")" yes
expect websites "$(yn test -f "$EXT/higgsfield-websites/SKILL.md")" yes
expect noskill  "$(yn test -e "$EXT/higgsfield-noskill")" no
expect symlink  "$(yn test -L "$EXT/higgsfield-linked")" no
expect no-other "$(yn test -e "$EXT/other-skill")" no
expect no-setup "$(yn test -e "$EXT/setup")" no
expect no-git   "$(find "$EXT" -name .git | wc -l | tr -d ' ')" 0
expect entries  "$(entries "$EXT")" 3
verdict SYNC_MOVES_PACK_ONLY

rm "$UP/higgsfield-generate/old.md"
echo "new" > "$UP/higgsfield-generate/new.md"
git_q "$UP" add -A; git_q "$UP" commit -m refresh
expect before    "$(yn test -f "$EXT/higgsfield-generate/old.md")" yes
expect rc-count  "$(sync_into "$R1")" "0:3"
expect stale-out "$(yn test -e "$EXT/higgsfield-generate/old.md")" no
expect new-in    "$(yn test -f "$EXT/higgsfield-generate/new.md")" yes
verdict SYNC_REFRESH_DROPS_STALE

ln -s "$EXT/higgsfield-soul-id" "$R1/skills-disabled/higgsfield-soul-id"
ln -s "$EXT/higgsfield-generate" "$R1/skills/higgsfield-generate"
expect rc-count    "$(sync_into "$R1")" "0:3"
expect parked-link "$(yn test -L "$R1/skills-disabled/higgsfield-soul-id")" yes
expect parked-reads \
  "$(yn test -f "$R1/skills-disabled/higgsfield-soul-id/SKILL.md")" yes
expect not-enabled "$(yn test -e "$R1/skills/higgsfield-soul-id")" no
expect live-reads  "$(yn test -f "$R1/skills/higgsfield-generate/SKILL.md")" yes
verdict SYNC_KEEPS_PARKED

BARE="$WORK/bare-upstream"; mkdir -p "$BARE"; echo "x" > "$BARE/README.md"
git_q "$BARE" init; git_q "$BARE" add -A; git_q "$BARE" commit -m fixture
expect no-repo   "$(sync_into "$R1" "$WORK/no-such-repo")" "1:0"
expect no-skills "$(sync_into "$R1" "$BARE")" "1:0"
expect copy-kept "$(yn test -f "$EXT/higgsfield-generate/new.md")" yes
expect entries   "$(entries "$EXT")" 3
verdict SYNC_FAIL_KEEPS_COPY

expect cli-ok      "$(probe "$BIN:$PATH" higgsfield_cli_ok)" "rc=0"
expect signed-in   "$(probe "$BIN:$PATH" higgsfield_signed_in)" "rc=0"
expect signed-out  \
  "$(FAKE_HF_SESSION=out probe "$BIN:$PATH" higgsfield_signed_in)" "rc=2"
expect shim-only   \
  "$(FAKE_HF_BINARY=missing probe "$BIN:$PATH" higgsfield_cli_ok)" "rc=1"
expect no-cli      "$(probe "$CLEAN" higgsfield_cli_ok)" "rc=127"
expect no-timeout  "$(probe "$BIN:$CLEAN" higgsfield_cli_ok)" "rc=0"
verdict PROBES_SILENT

# ── tally ───────────────────────────────────────────────────
printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
````

- [ ] **Step 2: Run it, confirm it fails**

Run: `make test suite=lib/tests/higgsfield.test.sh`
Expected: five `FAIL` lines (`SYNC_MOVES_PACK_ONLY`, `SYNC_REFRESH_DROPS_STALE`, `SYNC_KEEPS_PARKED`, `SYNC_FAIL_KEEPS_COPY`, `PROBES_SILENT`: the helper does not exist yet, so every sync answers `127:`), then `PASS=0 FAIL=5` and a non-zero make status.

- [ ] **Step 3: Write the helper**

Run: `cp docs/superpowers/plans/2026-09-30-higgsfield-pack.patches/02-higgsfield-skills.sh lib/higgsfield-skills.sh && chmod 644 lib/higgsfield-skills.sh`

````bash
#!/usr/bin/env bash
# ============================================================
# lib/higgsfield-skills.sh — Higgsfield skill pack sync + CLI probes
#
# Sourced by install-plugins.sh (Step 8.6), update-all.sh (7.3b) and
# doctor.sh. The pack is machine-owned: cloned from upstream and moved
# into skills-external/higgsfield-* (gitignored), then linked on demand by
# lib/toggle-external.sh. It is listed in neither link.sh nor any profile:
# either would re-enable a parked pack on every run (BDR-093).
# ============================================================

# Upstream skills repo, single source for both installers. An env value
# wins so the hermetic suite can point it at a local fixture repo.
HIGGSFIELD_SKILLS_URL="${HIGGSFIELD_SKILLS_URL:-\
https://github.com/higgsfield-ai/skills.git}"

# _higgsfield_adopt <clone> <dest>
# Move every real higgsfield-*/ directory of the clone that holds a SKILL.md
# over its copy in <dest>; prints how many landed. A symlinked entry is
# skipped: only upstream's own directories are adopted. A skill counts only
# once its move succeeded.
_higgsfield_adopt() {
  local clone="$1" dest="$2" dir name count=0
  for dir in "$clone"/higgsfield-*/; do
    dir="${dir%/}"
    { [ -f "$dir/SKILL.md" ] && [ ! -L "$dir" ]; } || continue
    name="$(basename "$dir")"
    rm -rf "${dest:?}/${name:?}" && mv "$dir" "$dest/$name" \
      && count=$((count + 1))
  done
  echo "$count"
}

# higgsfield_sync_skills <repo>
# Clone upstream into a stage and replace each
# <repo>/skills-external/higgsfield-* with the fresh copy; upstream's own
# machinery (setup, scripts/, plugin manifests, .git) stays in the stage.
# The stage sits next to the destination, on the same filesystem, so each
# replacement is a rename. Prints the number of skills synced. Returns 1,
# existing copies untouched, when the clone fails or upstream holds no
# higgsfield-*/SKILL.md. A parked skill (skills-disabled/<name>, a symlink
# to the source path) stays parked. Known limit: a skill that upstream
# removes or renames keeps its last local copy.
higgsfield_sync_skills() {
  local dest="$1/skills-external" stage count=0
  mkdir -p "$dest" || return 1
  stage="$(mktemp -d "$dest/.higgsfield-stage.XXXXXX")" || return 1
  # No credential prompt: a private or deleted upstream must fail, not hang.
  if GIT_TERMINAL_PROMPT=0 git clone --quiet --depth 1 \
      "$HIGGSFIELD_SKILLS_URL" "$stage/src" >/dev/null 2>&1; then
    count="$(_higgsfield_adopt "$stage/src" "$dest")"
  fi
  rm -rf "${stage:?}"
  echo "$count"
  [ "$count" -gt 0 ]
}

# _higgsfield_probe <args...>
# Run `higgsfield <args>` silently, 15 s at most when `timeout` exists. The
# CLI is closed source: a probe must never hang an installer, and what it
# prints (a token, for `auth token`) must never reach a terminal or a log.
_higgsfield_probe() {
  if command -v timeout >/dev/null 2>&1; then
    timeout 15 higgsfield "$@" </dev/null >/dev/null 2>&1
  else
    higgsfield "$@" </dev/null >/dev/null 2>&1
  fi
}

# higgsfield_cli_ok — 0 when the binary answers. `command -v` alone only
# proves the npm shim: the binary is vendored by a postinstall script that
# npm may hold back, on a first install or on any later update.
higgsfield_cli_ok() { _higgsfield_probe version; }

# higgsfield_signed_in — 0 when the CLI holds a session.
higgsfield_signed_in() { _higgsfield_probe auth token; }
````

- [ ] **Step 4: Run the suite, confirm it passes**

Run: `make test suite=lib/tests/higgsfield.test.sh`
Expected: five `PASS` lines, `PASS=5 FAIL=0`.

- [ ] **Step 5: Shellcheck**

Run: `shellcheck lib/higgsfield-skills.sh lib/tests/higgsfield.test.sh`
Expected: no output.

- [ ] **Step 6: Commit**

```bash
git add lib/higgsfield-skills.sh lib/tests/higgsfield.test.sh
git commit -m "feat(higgsfield): skill pack sync helper and CLI probes, with suite"
```

---

### Task 3: The two toggles

**Files:**
- Modify: `lib/tests/higgsfield.test.sh` (toggle cases + `OFF_BY_DEFAULT_WIRING`, inserted above the tally)
- Modify: `lib/toggle-external.sh` (header, `MANAGED_TOOLS`, allowlist, enumerators, dispatcher, probe, hints, pack arms, single-symlink arms, `usage` range)

**Interfaces:**
- Consumes: the suite helpers of Task 2.
- Produces, in `lib/toggle-external.sh`:
  - tools `higgsfield` and `higgsfield-websites` for `status | enable | disable | list`.
  - `HIGGSFIELD_MEDIA_SKILLS`: the seven allowlisted media skill names.
  - `higgsfield_skills`: prints the allowlisted names synced under `skills-external/` (a `SKILL.md` present).
  - `higgsfield_unlisted`: prints synced `higgsfield-*` skills that no tool owns.
  - `pack_skills <tool>`: prints the members of `21st` or `higgsfield`.
  - `bounded <cmd...>`: silent CLI probe, 15 s at most when `timeout` exists.
  - `pack_hints <tool>`: warns (never fails) when the pack's CLI is missing, does not answer, or is signed out; for `higgsfield`, also names each unlisted skill. Called after a pack enable and after `enable higgsfield-websites`.
  - Messages: `<tool> enabled (<n> skills: <r> restored, <l> linked)`, `<tool> disabled (<n> skills parked)`, `<tool> already enabled`, `<tool> already disabled`, `<tool> pack not installed in <repo>/skills-external — run: make plugin` (LRN-007: the error names the path checked).

- [ ] **Step 1: Add the failing cases**

Run: `git apply docs/superpowers/plans/2026-09-30-higgsfield-pack.patches/03-suite.patch`

````diff
--- a/lib/tests/higgsfield.test.sh
+++ b/lib/tests/higgsfield.test.sh
@@ -164,5 +164,153 @@
 expect no-timeout  "$(probe "$BIN:$CLEAN" higgsfield_cli_ok)" "rc=0"
 verdict PROBES_SILENT
 
+# ── toggle ──────────────────────────────────────────────────
+# mk_toggle_fx <dir> [skill...] — fixture repo: the toggle script plus one
+# skills-external source per named skill (none → installed-nothing tree).
+mk_toggle_fx() {
+  local fx="$1" s; shift
+  mkdir -p "$fx/lib" "$fx/skills"
+  cp "$ROOT/lib/toggle-external.sh" "$ROOT/lib/gstack-removed.sh" "$fx/lib/"
+  for s in "$@"; do
+    mkdir -p "$fx/skills-external/$s"
+    echo "---" > "$fx/skills-external/$s/SKILL.md"
+  done
+}
+PACK=(higgsfield-generate higgsfield-soul-id higgsfield-websites)
+
+# tog <fixture> <args...> — run the fixture's toggle script, fake CLIs first.
+tog() {
+  local fx="$1"; shift
+  TOGGLE_EXTERNAL_REPO_OVERRIDE="$fx" PATH="$BIN:$PATH" \
+    bash "$fx/lib/toggle-external.sh" "$@" 2>&1
+}
+# list_row <fixture> <tool> — the status column of `list` for one tool.
+list_row() { tog "$1" list | awk -v t="$2" '$1 == t { print $2 }'; }
+
+F0="$WORK/f0"; mk_toggle_fx "$F0"
+F1="$WORK/f1"; mk_toggle_fx "$F1" "${PACK[@]}"
+expect pack-missing  "$(tog "$F0" status higgsfield)" missing
+expect web-missing   "$(tog "$F0" status higgsfield-websites)" missing
+expect pack-disabled "$(tog "$F1" status higgsfield)" disabled
+expect web-disabled  "$(tog "$F1" status higgsfield-websites)" disabled
+ln -s "$F1/skills-external/higgsfield-generate" "$F1/skills/higgsfield-generate"
+expect pack-partial  "$(tog "$F1" status higgsfield)" enabled
+expect web-apart     "$(tog "$F1" status higgsfield-websites)" disabled
+expect list-pack     "$(list_row "$F1" higgsfield)" enabled
+expect list-web      "$(list_row "$F1" higgsfield-websites)" disabled
+verdict STATUS_STATES
+
+F2="$WORK/f2"; mk_toggle_fx "$F2" "${PACK[@]}"
+out="$(tog "$F2" enable higgsfield)"; rc=$?
+expect rc "$rc" 0
+expect generate "$(readlink "$F2/skills/higgsfield-generate")" \
+  "$F2/skills-external/higgsfield-generate"
+expect soul-id "$(readlink "$F2/skills/higgsfield-soul-id")" \
+  "$F2/skills-external/higgsfield-soul-id"
+expect no-websites "$(yn test -e "$F2/skills/higgsfield-websites")" no
+expect_has count "$out" "higgsfield enabled (2 skills: 0 restored, 2 linked)"
+out="$(tog "$F2" enable higgsfield)"; rc=$?
+expect again-rc "$rc" 0
+expect_has again "$out" "higgsfield already enabled"
+verdict ENABLE_PACK_EXCLUDES_WEBSITES
+
+# The media pack is an allowlist: a synced skill nobody listed is reported,
+# never linked; neither is a listed name whose directory holds no SKILL.md.
+F8="$WORK/f8"; mk_toggle_fx "$F8" "${PACK[@]}" higgsfield-newcomer
+mkdir -p "$F8/skills-external/higgsfield-brandkit" \
+  "$F8/skills-external/higgsfield-noskill"
+out="$(tog "$F8" enable higgsfield)"; rc=$?
+expect rc "$rc" 0
+expect_has count "$out" "higgsfield enabled (2 skills: 0 restored, 2 linked)"
+expect newcomer-off "$(yn test -e "$F8/skills/higgsfield-newcomer")" no
+expect brandkit-off "$(yn test -e "$F8/skills/higgsfield-brandkit")" no
+expect_has reported "$out" "higgsfield-newcomer"
+expect_not noskill-quiet "$out" "higgsfield-noskill"
+expect links "$(entries "$F8/skills")" 2
+verdict UNLISTED_NOT_LINKED
+
+F3="$WORK/f3"; mk_toggle_fx "$F3" "${PACK[@]}"
+out="$(tog "$F3" enable higgsfield-websites)"; rc=$?
+expect rc "$rc" 0
+expect link "$(readlink "$F3/skills/higgsfield-websites")" \
+  "$F3/skills-external/higgsfield-websites"
+expect no-generate "$(yn test -e "$F3/skills/higgsfield-generate")" no
+expect pack-status "$(tog "$F3" status higgsfield)" disabled
+expect web-status  "$(tog "$F3" status higgsfield-websites)" enabled
+tog "$F3" disable higgsfield-websites >/dev/null
+out="$(FAKE_HF_SESSION=out tog "$F3" enable higgsfield-websites)"; rc=$?
+expect hint-rc "$rc" 0
+expect_has web-hint "$out" "higgsfield auth login"
+verdict ENABLE_WEBSITES_ALONE
+
+# Continues on F2: the pack is enabled, websites is not.
+tog "$F2" enable higgsfield-websites >/dev/null
+out="$(tog "$F2" disable higgsfield)"; rc=$?
+expect rc "$rc" 0
+expect_has msg "$out" "higgsfield disabled (2 skills parked)"
+expect parked "$(yn test -L "$F2/skills-disabled/higgsfield-generate")" yes
+expect unlinked      "$(yn test -e "$F2/skills/higgsfield-generate")" no
+expect web-untouched "$(yn test -e "$F2/skills/higgsfield-websites")" yes
+out="$(tog "$F2" enable higgsfield)"
+expect_has restored "$out" "2 restored, 0 linked"
+tog "$F2" disable higgsfield-websites >/dev/null
+expect web-parked "$(yn test -L "$F2/skills-disabled/higgsfield-websites")" yes
+expect pack-on    "$(tog "$F2" status higgsfield)" enabled
+verdict DISABLE_PARKS
+
+F4="$WORK/f4"; mk_toggle_fx "$F4" "${PACK[@]}"
+out="$(FAKE_HF_SESSION=out tog "$F4" enable higgsfield)"; rc=$?
+expect out-rc "$rc" 0
+expect out-linked "$(yn test -e "$F4/skills/higgsfield-generate")" yes
+expect_has out-hint "$out" "higgsfield auth login"
+F5="$WORK/f5"; mk_toggle_fx "$F5" "${PACK[@]}"
+out="$(FAKE_HF_SESSION=in tog "$F5" enable higgsfield)"
+expect_not in-quiet "$out" "auth login"
+expect_not in-no-token "$out" "fixture-token"
+F6="$WORK/f6"; mk_toggle_fx "$F6" "${PACK[@]}"
+out="$(TOGGLE_EXTERNAL_REPO_OVERRIDE="$F6" PATH="$CLEAN" \
+  bash "$F6/lib/toggle-external.sh" enable higgsfield 2>&1)"; rc=$?
+expect absent-rc "$rc" 0
+expect absent-linked "$(yn test -e "$F6/skills/higgsfield-generate")" yes
+expect_has absent-hint "$out" "not on PATH"
+F9="$WORK/f9"; mk_toggle_fx "$F9" "${PACK[@]}"
+out="$(FAKE_HF_BINARY=missing tog "$F9" enable higgsfield)"; rc=$?
+expect shim-rc "$rc" 0
+expect_has shim-hint "$out" "does not answer"
+expect_not shim-not-login "$out" "auth login"
+verdict SIGNED_OUT_WARNS
+
+out="$(tog "$F0" enable higgsfield)"; rc=$?
+expect pack-rc "$rc" 1
+expect_has pack-path "$out" "$F0/skills-external"
+out="$(tog "$F0" enable higgsfield-websites)"; rc=$?
+expect web-rc "$rc" 1
+expect_has web-path "$out" "$F0/skills-external/higgsfield-websites"
+verdict ENABLE_MISSING_ERRS
+
+# The pack arms are shared with 21st: its behaviour must not move.
+F7="$WORK/f7"; mk_toggle_fx "$F7" 21st-one 21st-two
+expect off "$(tog "$F7" status 21st)" disabled
+out="$(tog "$F7" enable 21st)"
+expect_has on "$out" "21st enabled (2 skills: 0 restored, 2 linked)"
+expect_not quiet "$out" "21st login"
+expect hf-apart "$(tog "$F7" status higgsfield)" missing
+out="$(tog "$F7" disable 21st)"
+expect_has parked "$out" "21st disabled (2 skills parked)"
+verdict PACK_21ST_UNCHANGED
+
+# ── wiring ──────────────────────────────────────────────────
+# count <file> <fixed string> — matching lines (0 when none).
+count() { grep -cF -- "$2" "$ROOT/$1"; }
+
+# Positive control first: the pattern does bite on a line that carries it.
+expect control    "$(echo 'higgsfield-x external' | grep -cF higgsfield)" 1
+expect link-sh    "$(count link.sh higgsfield)" 0
+expect profile-sh "$(count lib/profile.sh higgsfield)" 0
+expect profiles \
+  "$(cat "$ROOT"/lib/profiles/*.profile | grep -cF higgsfield)" 0
+expect pins-map   "$(count lib/effort-pins.txt higgsfield)" 0
+verdict OFF_BY_DEFAULT_WIRING
+
 # ── tally ───────────────────────────────────────────────────
 printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
````

- [ ] **Step 2: Run, confirm the new cases fail**

Run: `make test suite=lib/tests/higgsfield.test.sh`
Expected: `PASS=6 FAIL=8`. The five Task 2 cases and `OFF_BY_DEFAULT_WIRING` PASS. `STATUS_STATES`, `ENABLE_PACK_EXCLUDES_WEBSITES`, `UNLISTED_NOT_LINKED`, `ENABLE_WEBSITES_ALONE`, `DISABLE_PARKS`, `SIGNED_OUT_WARNS`, `ENABLE_MISSING_ERRS` FAIL (the script answers `unknown` / `Unknown tool`), and `PACK_21ST_UNCHANGED` fails on `hf-apart` alone (`unknown` instead of `missing`).

- [ ] **Step 3: Apply the toggle patch**

Run: `git apply docs/superpowers/plans/2026-09-30-higgsfield-pack.patches/03-toggle-external.patch`

````diff
--- a/lib/toggle-external.sh
+++ b/lib/toggle-external.sh
@@ -8,7 +8,8 @@
 # as symlinks inside skills/. This script moves those symlinks
 # to/from skills-disabled/ so Claude Code stops/starts scanning them.
 #
-# A multi-skill pack (gstack, 21st) toggles all of its skills at once.
+# A multi-skill pack (gstack, 21st, higgsfield) toggles all of its skills
+# at once.
 #
 # Usage:
 #   toggle-external.sh list
@@ -21,6 +22,8 @@
 #   emil-design-eng   — single symlink → skills-external/emil-design-eng
 #   darwin-skill      — single symlink → ~/.agents/skills/darwin-skill
 #   21st              — 21st.dev skill pack (needs the `21st` CLI + login)
+#   higgsfield        — Higgsfield media pack (needs the `higgsfield` CLI)
+#   higgsfield-websites — single skill, landing-page aid (named ask only)
 #   observability-and-instrumentation, deprecation-and-migration,
 #   ci-cd-and-automation — the agent-skills trio, same single-symlink shape
 #   as emil-design-eng (commit-pinned instead of main-branch tracking)
@@ -52,7 +55,8 @@
 err()  { echo -e "${RED}✗${NC} $1"; }
 
 # All non-plugin tools this script can toggle.
-MANAGED_TOOLS=(gstack emil-design-eng darwin-skill 21st
+MANAGED_TOOLS=(gstack emil-design-eng darwin-skill 21st higgsfield
+  higgsfield-websites
   observability-and-instrumentation deprecation-and-migration ci-cd-and-automation
   scroll-world-storytelling build-threejs-scroll-worlds
   scroll-scrubbed-visual-sequence scroll-scrubbed-word-reveal
@@ -69,6 +73,87 @@
   done
 }
 
+# Media skills of the "higgsfield" pack: an explicit allowlist. Upstream is
+# unpinned, so a skill it adds or renames must never be linked by
+# `enable higgsfield` without an edit here (default deny).
+# higgsfield-websites is its own tool: landing-page aid, named ask only.
+HIGGSFIELD_MEDIA_SKILLS=(higgsfield-generate higgsfield-soul-id
+  higgsfield-product-photoshoot higgsfield-brandkit
+  higgsfield-marketplace-cards higgsfield-video-explainer
+  higgsfield-youtube-thumbnail)
+
+# Prints the allowlisted media skills synced under skills-external/.
+higgsfield_skills() {
+  local name
+  for name in "${HIGGSFIELD_MEDIA_SKILLS[@]}"; do
+    [ -f "$REPO/skills-external/$name/SKILL.md" ] && echo "$name"
+  done
+  return 0
+}
+
+# Prints the synced higgsfield-* skills no tool owns: neither on the media
+# allowlist nor higgsfield-websites. Upstream added or renamed something.
+higgsfield_unlisted() {
+  local d name
+  for d in "$REPO"/skills-external/higgsfield-*/; do
+    [ -f "${d}SKILL.md" ] || continue
+    name="$(basename "$d")"
+    case " ${HIGGSFIELD_MEDIA_SKILLS[*]} higgsfield-websites " in
+      *" $name "*) ;;
+      *) echo "$name" ;;
+    esac
+  done
+}
+
+# Prints the member skills of a multi-skill pack tool (21st, higgsfield).
+pack_skills() {
+  case "$1" in
+    21st)       twentyfirst_skills ;;
+    higgsfield) higgsfield_skills ;;
+  esac
+}
+
+# bounded <cmd...> — run a CLI probe silently, 15 s at most when `timeout`
+# exists: a closed-source binary must never hang a toggle, and what it
+# prints (a token) must never reach the terminal. Twin of
+# _higgsfield_probe in lib/higgsfield-skills.sh, kept here because this
+# script takes no extra `source` (the fixture suites copy it alone).
+bounded() {
+  if command -v timeout >/dev/null 2>&1; then
+    timeout 15 "$@" </dev/null >/dev/null 2>&1
+  else
+    "$@" </dev/null >/dev/null 2>&1
+  fi
+}
+
+# Post-enable notes for a pack. Its skills shell out to a CLI: without it
+# (or without a session) they can only report failure. Warn, never block:
+# the pack is still correctly wired and `make plugin` installs the CLI.
+pack_hints() {
+  local name
+  case "$1" in
+    21st)
+      if ! command -v 21st >/dev/null 2>&1; then
+        warn "the \`21st\` CLI is not on PATH — install it: npm i -g @21st-dev/cli"
+      elif ! 21st whoami 2>/dev/null | grep -q '^Logged in as '; then
+        warn "not signed in to 21st — component retrieval and 21st AI need: 21st login"
+      fi
+      ;;
+    higgsfield)
+      if ! command -v higgsfield >/dev/null 2>&1; then
+        warn "the \`higgsfield\` CLI is not on PATH — run: make plugin"
+      elif ! bounded higgsfield version; then
+        warn "the \`higgsfield\` CLI does not answer (npm shim without its binary) — run: make plugin"
+      elif ! bounded higgsfield auth token; then
+        warn "not signed in to Higgsfield — generation needs: higgsfield auth login"
+      fi
+      while read -r name; do
+        warn "$name is synced but on no allowlist, not linked — see HIGGSFIELD_MEDIA_SKILLS in lib/toggle-external.sh"
+      done < <(higgsfield_unlisted)
+      ;;
+  esac
+}
+
 # Prints the names (directory basenames) that belong to "gstack".
 # Source of truth: skills-external/gstack/*/SKILL.md. The repo's
 # skills/<name> symlinks are generated from these by gstack ./setup.
@@ -94,7 +179,7 @@
       ;;
     emil-design-eng|observability-and-instrumentation|deprecation-and-migration|ci-cd-and-automation| \
     scroll-world-storytelling|build-threejs-scroll-worlds|scroll-scrubbed-visual-sequence| \
-    scroll-scrubbed-word-reveal|scroll-progress-timeline)
+    scroll-scrubbed-word-reveal|scroll-progress-timeline|higgsfield-websites)
       [ -d "$REPO/skills-external/$tool" ] || { echo "missing"; return; }
       [ -e "$SKILLS_DIR/$tool" ] && echo "enabled" || echo "disabled"
       ;;
@@ -102,12 +187,12 @@
       [ -d "$HOME/.agents/skills/$tool" ] || { echo "missing"; return; }
       [ -e "$SKILLS_DIR/$tool" ] && echo "enabled" || echo "disabled"
       ;;
-    21st)
+    21st|higgsfield)
       local installed=0
       while read -r name; do
         installed=1
         [ -e "$SKILLS_DIR/$name" ] && { echo "enabled"; return; }
-      done < <(twentyfirst_skills)
+      done < <(pack_skills "$tool")
       [ "$installed" -eq 1 ] && echo "disabled" || echo "missing"
       ;;
     *)
@@ -135,7 +220,8 @@
       ;;
     emil-design-eng|darwin-skill|observability-and-instrumentation|deprecation-and-migration| \
     ci-cd-and-automation|scroll-world-storytelling|build-threejs-scroll-worlds| \
-    scroll-scrubbed-visual-sequence|scroll-scrubbed-word-reveal|scroll-progress-timeline)
+    scroll-scrubbed-visual-sequence|scroll-scrubbed-word-reveal|scroll-progress-timeline| \
+    higgsfield-websites)
       if [ -e "$SKILLS_DIR/$tool" ]; then
         rm -rf "${DISABLED_DIR:?}/${tool:?}"
         mv "$SKILLS_DIR/$tool" "$DISABLED_DIR/$tool"
@@ -144,7 +230,7 @@
         warn "$tool already disabled"
       fi
       ;;
-    21st)
+    21st|higgsfield)
       # Parked under the plain skill name — same convention as the other
       # externals, so profile.sh's park/restore path stays interoperable.
       local parked=0
@@ -153,11 +239,11 @@
         rm -rf "${DISABLED_DIR:?}/${name:?}"
         mv "$SKILLS_DIR/$name" "$DISABLED_DIR/$name"
         parked=$((parked + 1))
-      done < <(twentyfirst_skills)
+      done < <(pack_skills "$tool")
       if [ "$parked" -gt 0 ]; then
-        ok "21st disabled ($parked skills parked)"
+        ok "$tool disabled ($parked skills parked)"
       else
-        warn "21st already disabled"
+        warn "$tool already disabled"
       fi
       ;;
     *) err "Unknown tool: $tool"; return 1 ;;
@@ -194,7 +280,8 @@
       ;;
     emil-design-eng|darwin-skill|observability-and-instrumentation|deprecation-and-migration| \
     ci-cd-and-automation|scroll-world-storytelling|build-threejs-scroll-worlds| \
-    scroll-scrubbed-visual-sequence|scroll-scrubbed-word-reveal|scroll-progress-timeline)
+    scroll-scrubbed-visual-sequence|scroll-scrubbed-word-reveal|scroll-progress-timeline| \
+    higgsfield-websites)
       local src
       case "$tool" in
         darwin-skill) src="$HOME/.agents/skills/$tool" ;;
@@ -213,8 +300,9 @@
         err "$tool not installed at $src — run: make plugin"
         return 1
       fi
+      if [ "$tool" = "higgsfield-websites" ]; then pack_hints higgsfield; fi
       ;;
-    21st)
+    21st|higgsfield)
       local restored=0 linked=0
       while read -r name; do
         if [ -e "$DISABLED_DIR/$name" ]; then
@@ -227,24 +315,17 @@
           ln -sf "$REPO/skills-external/$name" "$SKILLS_DIR/$name"
           linked=$((linked + 1))
         fi
-      done < <(twentyfirst_skills)
+      done < <(pack_skills "$tool")
       if [ "$((restored + linked))" -eq 0 ]; then
-        if [ "$(status_tool 21st)" = "missing" ]; then
-          err "21st pack not installed in $REPO/skills-external — run: make plugin"
+        if [ "$(status_tool "$tool")" = "missing" ]; then
+          err "$tool pack not installed in $REPO/skills-external — run: make plugin"
           return 1
         fi
-        warn "21st already enabled"
+        warn "$tool already enabled"
         return 0
       fi
-      ok "21st enabled ($((restored + linked)) skills: $restored restored, $linked linked)"
-      # The skills shell out to the CLI; without it (or without a session)
-      # they can only report failure. Warn, never block — the pack is still
-      # correctly wired and `make plugin` installs the CLI.
-      if ! command -v 21st >/dev/null 2>&1; then
-        warn "the \`21st\` CLI is not on PATH — install it: npm i -g @21st-dev/cli"
-      elif ! 21st whoami 2>/dev/null | grep -q '^Logged in as '; then
-        warn "not signed in to 21st — component retrieval and 21st AI need: 21st login"
-      fi
+      ok "$tool enabled ($((restored + linked)) skills: $restored restored, $linked linked)"
+      pack_hints "$tool"
       ;;
     *) err "Unknown tool: $tool"; return 1 ;;
   esac
@@ -259,7 +340,7 @@
 }
 
 usage() {
-  sed -n '3,23p' "$0" | sed 's/^# \?//'
+  sed -n '3,26p' "$0" | sed 's/^# \?//'
   exit "${1:-0}"
 }
 
````

- [ ] **Step 4: Run the suite and the four suites that copy this script**

Run, one command per suite:
```bash
make test suite=lib/tests/higgsfield.test.sh
make test suite=lib/tests/toggle-external-repo-resolution.test.sh
make test suite=lib/tests/gstack-removed.test.sh
make test suite=lib/tests/profile-set-managed.test.sh
make test suite=lib/tests/profile-default.test.sh
```
Expected: `PASS=14 FAIL=0` for the Higgsfield suite, and each of the four others ends green (make status 0).

- [ ] **Step 5: Shellcheck and the help text**

Run: `shellcheck lib/toggle-external.sh lib/tests/higgsfield.test.sh && sed -n '3,26p' lib/toggle-external.sh | tail -3`
Expected: no shellcheck output; the last three lines shown are the `21st`, `higgsfield` and `higgsfield-websites` tool lines.

- [ ] **Step 6: Commit**

```bash
git add lib/toggle-external.sh lib/tests/higgsfield.test.sh
git commit -m "feat(toggle): higgsfield and higgsfield-websites toggles"
```

---

### Task 4: Installer step 8.6 and the login tests

**Files:**
- Modify: `lib/tests/higgsfield.test.sh` (`INSTALL_WIRING`, above the tally)
- Modify: `install-plugins.sh` (Step 6 login test, new Step 8.6 before Step 8.7, Step 8.7 login test, one summary line)

**Interfaces:**
- Consumes: `higgsfield_sync_skills`, `higgsfield_cli_ok`, `higgsfield_signed_in`, `HIGGSFIELD_SKILLS_URL` (Task 2); lock key `higgsfield` through the existing `pinned_version` (Task 1); the installer's `ok | info | warn | err` helpers and `$REPO`.
- Produces: Step 8.6 (CLI install proven by the probe, skill sync, login offer on a terminal stdin); login offers of Steps 6 and 8.7 reachable under the `tee` redirect (`[ -t 0 ]` alone, BDR-093 TTY-only login kept).

- [ ] **Step 1: Add the failing case**

Run: `git apply docs/superpowers/plans/2026-09-30-higgsfield-pack.patches/04-suite.patch`

````diff
--- a/lib/tests/higgsfield.test.sh
+++ b/lib/tests/higgsfield.test.sh
@@ -312,5 +312,29 @@
 expect pins-map   "$(count lib/effort-pins.txt higgsfield)" 0
 verdict OFF_BY_DEFAULT_WIRING
 
+# ln_first / ln_last <file> <fixed string> — line number of a match.
+ln_first() { grep -nF -- "$2" "$ROOT/$1" | head -1 | cut -d: -f1; }
+ln_last()  { grep -nF -- "$2" "$ROOT/$1" | tail -1 | cut -d: -f1; }
+# shellcheck disable=SC2016  # a literal to grep for, not an expansion
+PINS='apply_effort_pins "$REPO"'
+
+# install-plugins.sh: the sync sits in Step 8.6, before the effort pins
+# (BDR-108); the CLI is proven by a probe, not by its shim; every login
+# offer tests stdin alone (stdout is the tee pipe).
+sync_ln="$(ln_last install-plugins.sh 'higgsfield_sync_skills')"
+expect after-8.5 "$(yn test "$sync_ln" -gt \
+  "$(ln_first install-plugins.sh 'Step 8.5: External skills')")" yes
+expect before-8.7 "$(yn test "$sync_ln" -lt \
+  "$(ln_first install-plugins.sh 'Step 8.7: 21st.dev')")" yes
+expect before-pins "$(yn test "$sync_ln" -lt \
+  "$(ln_last install-plugins.sh "$PINS")")" yes
+expect probe-gates \
+  "$(yn test "$(count install-plugins.sh 'if higgsfield_cli_ok')" -ge 3)" yes
+expect control "$(echo 'if [ -t 0 ] && [ -t 1 ]; then' | grep -cF -- '-t 1')" 1
+expect no-stdout-test "$(count install-plugins.sh '-t 1')" 0
+expect stdin-tests \
+  "$(yn test "$(count install-plugins.sh '[ -t 0 ]')" -ge 3)" yes
+verdict INSTALL_WIRING
+
 # ── tally ───────────────────────────────────────────────────
 printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
````

- [ ] **Step 2: Run, confirm it fails**

Run: `make test suite=lib/tests/higgsfield.test.sh`
Expected: `PASS=14 FAIL=1`, the failure being `FAIL INSTALL_WIRING:` listing `after-8.5`, `before-8.7`, `before-pins`, `probe-gates`, `no-stdout-test`, `stdin-tests`.

- [ ] **Step 3: Apply the installer patch**

Run: `git apply docs/superpowers/plans/2026-09-30-higgsfield-pack.patches/04-install-plugins.patch`

````diff
--- a/install-plugins.sh
+++ b/install-plugins.sh
@@ -582,6 +582,8 @@
 fi
 # ctx7 auth — detect, then offer login ONLY in an interactive TTY. A non-interactive
 # run (CI / headless / re-run) must never open a browser or block on OAuth.
+# The test reads stdin alone: stdout is the tee pipe set up at the top of
+# this script, never a terminal.
 if command -v ctx7 &>/dev/null; then
   # Deterministic offline oracle: ctx7's OAuth token lives here (XDG-aware).
   # Present => authenticated; absent => anonymous. No subprocess, no network, no browser.
@@ -590,7 +592,7 @@
     ok "ctx7 authenticated (full rate limits)"
   else
     info "ctx7 works anonymously — docs + library already usable, no auth required."
-    if [ -t 0 ] && [ -t 1 ]; then
+    if [ -t 0 ]; then
       # Interactive terminal: offer to log in now (opens a browser).
       printf '%b' "${BLUE}→${NC} Authenticate ctx7 now for higher rate limits? [y/N] "
       read -r ctx7_ans || ctx7_ans=""
@@ -991,6 +993,76 @@
 echo ""
 
 # ============================================================
+# STEP 8.6 — HIGGSFIELD CLI + SKILL PACK
+# ============================================================
+# `@higgsfield/cli` (bins `higgsfield`, `higgs`): image, video, audio and
+# brand media generation from the terminal, one browser login, metered
+# credits. Its skills come from github.com/higgsfield-ai/skills, cloned by
+# lib/higgsfield-skills.sh into skills-external/higgsfield-* (gitignored).
+#
+# Nothing is linked here. The pack is OFF by default and belongs to no
+# profile: `lib/toggle-external.sh enable higgsfield` turns the media skills
+# on, `enable higgsfield-websites` the landing-page aid. Keeping it out of
+# link.sh and of every profile is what stops a re-run from re-enabling it
+# (BDR-093). This step runs before Step 8.7 so the effort pins are still
+# re-applied after the last vendoring step (BDR-108).
+echo "── Step 8.6: Higgsfield CLI + skill pack ───────────────────"
+echo ""
+# shellcheck source=lib/higgsfield-skills.sh disable=SC1091
+source "$REPO/lib/higgsfield-skills.sh"
+HF_PKG="@higgsfield/cli"
+# The package vendors its binary in a postinstall script that npm may hold
+# back; this form lets that one script run.
+HF_REMEDY="npm install -g --allow-scripts=${HF_PKG} ${HF_PKG}"
+
+# higgsfield_cli_ok, not `command -v`: the npm shim can sit on PATH with no
+# binary behind it, and only a probe tells the two apart.
+if higgsfield_cli_ok; then
+  ok "Higgsfield CLI already installed"
+else
+  HF_VER=$(pinned_version "higgsfield")
+  [ "$HF_VER" = "latest" ] || HF_PKG="${HF_PKG}@${HF_VER}"
+  info "Installing ${HF_PKG} (version from plugins.lock.json: ${HF_VER})..."
+  npm install -g "$HF_PKG" || true
+  if higgsfield_cli_ok; then
+    ok "Higgsfield CLI installed"
+  else
+    err "Higgsfield CLI install failed — run manually: $HF_REMEDY"
+  fi
+fi
+
+if higgsfield_cli_ok; then
+  # Skill pack — cloned to a stage, then moved under skills-external/.
+  if HF_N=$(higgsfield_sync_skills "$REPO"); then
+    ok "Higgsfield skill pack synced to skills-external/ ($HF_N skills)"
+  else
+    warn "Higgsfield skill pack sync failed — existing copies kept (check: git clone $HIGGSFIELD_SKILLS_URL)"
+  fi
+
+  # Auth — offer the login only when stdin is a terminal: a non-interactive
+  # run (CI / headless) must never open a browser or block on OAuth.
+  if higgsfield_signed_in; then
+    ok "Higgsfield: signed in"
+  elif [ -t 0 ]; then
+    printf '%b' "${BLUE}→${NC} Sign in to Higgsfield now? (opens a browser) [y/N] "
+    read -r hf_ans || hf_ans=""
+    if [[ "$hf_ans" =~ ^[Yy]([Ee][Ss])?$ ]]; then
+      if higgsfield auth login; then
+        ok "Higgsfield authenticated"
+      else
+        warn "Higgsfield login did not finish — re-run 'higgsfield auth login' anytime"
+      fi
+    else
+      info "Skipped — sign in later with:  higgsfield auth login"
+    fi
+  else
+    info "Not signed in. Generation needs:  higgsfield auth login"
+  fi
+  info "Pack is off by default — enable:  bash lib/toggle-external.sh enable higgsfield"
+fi
+echo ""
+
+# ============================================================
 # STEP 8.7 — 21ST.DEV CLI + SKILL PACK
 # ============================================================
 # `@21st-dev/cli` (bin `21st`): one browser login (`21st login`, token in
@@ -1065,13 +1137,13 @@
 # Auth — detect, then offer login ONLY in an interactive TTY. A non-interactive
 # run (CI / headless / re-run) must never open a browser or block on OAuth.
 # Search and logo lookup are free; retrieving component code and 21st AI need
-# the session. Mirrors the ctx7 auth block (Step 6).
+# the session. Mirrors the ctx7 auth block (Step 6), stdin-only test included.
 if command -v 21st &>/dev/null; then
   # `whoami` is a local token read (no network): "Logged in as <user> (saved …)."
   TFD_WHO="$(21st whoami 2>/dev/null | head -1)"
   if [[ "$TFD_WHO" == "Logged in as "* ]]; then
     ok "21st: ${TFD_WHO%.}"
-  elif [ -t 0 ] && [ -t 1 ]; then
+  elif [ -t 0 ]; then
     printf '%b' "${BLUE}→${NC} Sign in to 21st now? (opens a browser) [y/N] "
     read -r tfd_ans || tfd_ans=""
     if [[ "$tfd_ans" =~ ^[Yy]([Ee][Ss])?$ ]]; then
@@ -1236,6 +1308,7 @@
 echo "    🔄 mengto scroll skills — scroll-world-storytelling, build-threejs-scroll-worlds, scroll-scrubbed-visual-sequence, scroll-scrubbed-word-reveal, scroll-progress-timeline (curl → symlink, pinned commit)"
 echo "    🔄 darwin-skill        — autonomous skill optimizer (npx skills, ~/.agents/skills/)"
 echo "    🔄 21st skill pack     — 21st.dev CLI skills; design ones follow the profile (full by default), publishing ones on demand (toggle: lib/toggle-external.sh enable 21st)"
+echo "    🔄 higgsfield pack     — Higgsfield CLI media skills (image, video, audio, brand), OFF by default (toggle: lib/toggle-external.sh enable higgsfield; landing-page aid: enable higgsfield-websites)"
 echo ""
 echo "  All plugins installed at: user scope (~/.claude/plugins/)"
 echo "  GStack skills symlinked individually into ~/.claude/skills/ (→ submodule)"
````

- [ ] **Step 4: Run the suite and the suites that lock this file**

```bash
make test suite=lib/tests/higgsfield.test.sh
make test suite=lib/tests/effort-routing.test.sh
make test suite=lib/tests/curated-config-guard.test.sh
```
Expected: `PASS=15 FAIL=0`; the two others green.

- [ ] **Step 5: Shellcheck and syntax**

Run: `shellcheck install-plugins.sh lib/tests/higgsfield.test.sh && bash -n install-plugins.sh && echo SYNTAX_OK`
Expected: `SYNTAX_OK`, no shellcheck output. Do not execute the installer.

- [ ] **Step 6: Commit**

```bash
git add install-plugins.sh lib/tests/higgsfield.test.sh
git commit -m "feat(install): Higgsfield step 8.6; login offers test stdin alone"
```

---

### Task 5: Refresh on `make update`

**Files:**
- Modify: `lib/tests/higgsfield.test.sh` (`UPDATE_WIRING`, above the tally)
- Modify: `update-all.sh` (new block 7.3b before 7.4)

**Interfaces:**
- Consumes: `higgsfield_sync_skills`, `higgsfield_cli_ok` (Task 2); lock key `higgsfield` (Task 1); the script's `ok | warn | info` helpers and `$REPO`.
- Produces: block 7.3b. It skips when the CLI is absent, proves the updated CLI with the probe (a shim left without its binary gets a warning and the remedy), replaces only `skills-external/` sources (a parked pack stays parked), and runs before the effort-pins re-apply (BDR-108).

- [ ] **Step 1: Add the failing case**

Run: `git apply docs/superpowers/plans/2026-09-30-higgsfield-pack.patches/05-suite.patch`

````diff
--- a/lib/tests/higgsfield.test.sh
+++ b/lib/tests/higgsfield.test.sh
@@ -336,5 +336,16 @@
   "$(yn test "$(count install-plugins.sh '[ -t 0 ]')" -ge 3)" yes
 verdict INSTALL_WIRING
 
+# update-all.sh: refresh before the 21st block and before the pins re-apply,
+# and the updated CLI is proven by the probe.
+sync_ln="$(ln_last update-all.sh 'higgsfield_sync_skills')"
+expect before-21st "$(yn test "$sync_ln" -lt \
+  "$(ln_first update-all.sh '7.4. Update the 21st.dev')")" yes
+expect before-pins "$(yn test "$sync_ln" -lt \
+  "$(ln_last update-all.sh "$PINS")")" yes
+expect probe-after-npm \
+  "$(yn test "$(count update-all.sh 'if higgsfield_cli_ok')" -ge 1)" yes
+verdict UPDATE_WIRING
+
 # ── tally ───────────────────────────────────────────────────
 printf 'PASS=%s FAIL=%s\n' "$pass" "$fail"; [ "$fail" -eq 0 ]
````

- [ ] **Step 2: Run, confirm it fails**

Run: `make test suite=lib/tests/higgsfield.test.sh`
Expected: `PASS=15 FAIL=1`, the failure being `FAIL UPDATE_WIRING:` listing `before-21st`, `before-pins`, `probe-after-npm`.

- [ ] **Step 3: Apply the updater patch**

Run: `git apply docs/superpowers/plans/2026-09-30-higgsfield-pack.patches/05-update-all.patch`

````diff
--- a/update-all.sh
+++ b/update-all.sh
@@ -465,6 +465,45 @@
   fi
 fi
 
+# ── 7.3b. Update the Higgsfield CLI + skill pack ──
+# CLI: global npm bin. Skills: re-cloned by lib/higgsfield-skills.sh, which
+# replaces the SOURCE under skills-external/ only: a pack parked in
+# skills-disabled/ (symlinks to those sources) stays parked. Runs before the
+# effort-pins re-apply below (BDR-108).
+echo ""
+echo "── Updating Higgsfield CLI + skill pack..."
+if ! command -v higgsfield &>/dev/null; then
+  info "Higgsfield CLI not installed — skipping (run: make plugin)"
+else
+  # shellcheck source=lib/higgsfield-skills.sh disable=SC1091
+  source "$REPO/lib/higgsfield-skills.sh"
+  HF_VER=""
+  if [ -f "$REPO/plugins.lock.json" ] && command -v python3 &>/dev/null; then
+    HF_VER=$(python3 -c "
+import json
+with open('$REPO/plugins.lock.json') as f:
+    d = json.load(f)
+print(d.get('higgsfield',{}).get('version','latest'))
+" 2>/dev/null || true)
+  fi
+  HF_PKG="@higgsfield/cli@latest"
+  [ -n "$HF_VER" ] && [ "$HF_VER" != "latest" ] \
+    && HF_PKG="@higgsfield/cli@${HF_VER}"
+  npm install -g "$HF_PKG" 2>/dev/null || true
+  # The probe, not npm's exit status: an update that skips the package's
+  # postinstall script leaves the shim on PATH with no binary behind it.
+  if higgsfield_cli_ok; then
+    ok "Higgsfield CLI updated (${HF_VER:-latest})"
+  else
+    warn "Higgsfield CLI does not answer after the update — run: npm install -g --allow-scripts=@higgsfield/cli @higgsfield/cli"
+  fi
+  if HF_N=$(higgsfield_sync_skills "$REPO"); then
+    ok "Higgsfield skill pack refreshed ($HF_N skills)"
+  else
+    warn "Higgsfield skill pack refresh failed — existing pack kept"
+  fi
+fi
+
 # ── 7.4. Update the 21st.dev CLI + skill pack ──
 # The CLI is a global npm bin; the skills are its hash-verified output, staged
 # under a throwaway HOME because `21st skills install` refuses to write
````

- [ ] **Step 4: Run the suite and the order lock**

```bash
make test suite=lib/tests/higgsfield.test.sh
make test suite=lib/tests/effort-routing.test.sh
```
Expected: `PASS=16 FAIL=0`; effort-routing green.

- [ ] **Step 5: Shellcheck and syntax**

Run: `shellcheck update-all.sh lib/tests/higgsfield.test.sh && bash -n update-all.sh && echo SYNTAX_OK`
Expected: `SYNTAX_OK`. Do not execute the updater.

- [ ] **Step 6: Commit**

```bash
git add update-all.sh lib/tests/higgsfield.test.sh
git commit -m "feat(update): refresh the Higgsfield CLI and skill pack"
```

---

### Task 6: Doctor lines

**Files:**
- Modify: `doctor.sh` (one `source` next to the others, one block in section 4 after the Graphifyy check)

**Interfaces:**
- Consumes: `higgsfield_cli_ok`, `higgsfield_signed_in` (Task 2); the script's `pass | info` helpers.
- Produces: `Higgsfield CLI installed (<version>)` + `Higgsfield session active`, or the `info` fallbacks (shim without binary, not installed, not signed in). Never `warn`, never `fail`: the tool is optional and off by default. Every probe sits inside an `if`, so `set -e` cannot trip.

- [ ] **Step 1: Apply the doctor patch**

Run: `git apply docs/superpowers/plans/2026-09-30-higgsfield-pack.patches/06-doctor.patch`

````diff
--- a/doctor.sh
+++ b/doctor.sh
@@ -26,6 +26,8 @@
 source "$REPO/lib/doctor-vendored.sh"
 # shellcheck source=lib/doctor-skills.sh disable=SC1091
 source "$REPO/lib/doctor-skills.sh"
+# shellcheck source=lib/higgsfield-skills.sh disable=SC1091
+source "$REPO/lib/higgsfield-skills.sh"
 
 echo ""
 echo "═══ claude-config doctor (v${VERSION}) ═══"
@@ -246,6 +248,22 @@
   info "Graphifyy not installed (optional — codebase knowledge graph: pipx install graphifyy)"
 fi
 
+# Higgsfield is optional and off by default: info level, never a warning.
+# The probe, not `command -v`: the npm shim can outlive its binary.
+if higgsfield_cli_ok; then
+  HF_VERSION="$(higgsfield version 2>/dev/null | awk 'NR==1 {print $2}')"
+  pass "Higgsfield CLI installed (${HF_VERSION:-version unknown})"
+  if higgsfield_signed_in; then
+    pass "Higgsfield session active"
+  else
+    info "Higgsfield not signed in (generation needs: higgsfield auth login)"
+  fi
+elif command -v higgsfield >/dev/null 2>&1; then
+  info "Higgsfield CLI on PATH but its binary does not answer (run: npm install -g --allow-scripts=@higgsfield/cli @higgsfield/cli)"
+else
+  info "Higgsfield CLI not installed (optional — media generation: make plugin)"
+fi
+
 echo ""
 
 # ────────────────────────────────────────────────────────────
````

- [ ] **Step 2: Verify without running the doctor**

Run:
```bash
shellcheck doctor.sh && bash -n doctor.sh && echo SYNTAX_OK
grep -E '(warn|fail) .*[Hh]iggsfield' doctor.sh || echo INFO_LEVEL_ONLY
```
Expected: `SYNTAX_OK`, `INFO_LEVEL_ONLY`.

- [ ] **Step 3: Commit**

```bash
git add doctor.sh
git commit -m "feat(doctor): report the Higgsfield CLI and its session"
```

---

### Task 7: README and CHANGELOG

**Files:**
- Modify: `README.md` (new `### Higgsfield CLI` after the 21st section)
- Modify: `CHANGELOG.md` (`[Unreleased]`: one bullet under Added, Security, Fixed)

**Interfaces:**
- Consumes: the names fixed by Tasks 3 to 6.
- Produces: user documentation. Prose follows `rules/writing-style.md` (BDR-085): no em-dash, no "it's not X, it's Y", no decorative bold.

- [ ] **Step 1: Apply the README patch**

Run: `git apply docs/superpowers/plans/2026-09-30-higgsfield-pack.patches/07-readme.patch`

````diff
--- a/README.md
+++ b/README.md
@@ -348,6 +348,55 @@
 auto-approving with no prompt raised (LRN-153), so an `ask` entry would have
 declared an intent without gating anything.
 
+### Higgsfield CLI
+
+`@higgsfield/cli` (bins `higgsfield` and `higgs`) generates images, video,
+audio and brand media from the terminal. One browser login, no API key.
+Generation spends account credits.
+
+```bash
+npm i -g @higgsfield/cli
+higgsfield auth login       # browser flow
+```
+
+`make plugin` does both (Step 8.6 installs the CLI, then offers the login in
+an interactive terminal) and clones the skills of
+[higgsfield-ai/skills](https://github.com/higgsfield-ai/skills) into
+`skills-external/higgsfield-*`. `make update` refreshes the CLI and the
+skills, and `make doctor` reports the CLI and its session. The copies are
+machine-owned and gitignored. They follow upstream `main`, so a prompt
+change arrives with no diff to review, and a skill that upstream removes
+keeps its last local copy.
+
+The pack is off by default and belongs to no profile. It costs nothing until
+you ask for it, and no `profile set` touches it:
+
+```bash
+bash lib/toggle-external.sh enable higgsfield            # media skills
+bash lib/toggle-external.sh enable higgsfield-websites   # landing-page aid
+bash lib/toggle-external.sh disable higgsfield
+```
+
+`higgsfield` links a fixed list of seven media skills: generate, soul-id,
+product-photoshoot, brandkit, marketplace-cards, video-explainer and
+youtube-thumbnail. The list is `HIGGSFIELD_MEDIA_SKILLS` in
+`lib/toggle-external.sh`. A skill that upstream adds later is synced and
+reported, and stays unlinked until it is added there.
+
+`higgsfield-websites` is kept apart. Here it helps with landing pages inside
+the design stack (assets, references), and `higgsfield website
+create|deploy|publish` stays unused. Claude enables either toggle itself on
+an explicit ask (Skill routing in `CLAUDE.global.md`) and checks the price
+with `higgsfield generate cost` before a paid run.
+
+The skills are cloned, not installed with `npx skills add`: that installer
+links every skill into `~/.claude/skills` on each refresh, which would undo
+the off-by-default state.
+
+The package ships its binary through a postinstall script. If npm holds that
+script back, `higgsfield` exists on PATH and fails at once; reinstall with
+`npm install -g --allow-scripts=@higgsfield/cli @higgsfield/cli`.
+
 ---
 
 ## Diagnostic and maintenance
````

- [ ] **Step 2: Apply the CHANGELOG patch**

Run: `git apply docs/superpowers/plans/2026-09-30-higgsfield-pack.patches/07-changelog.patch`

````diff
--- a/CHANGELOG.md
+++ b/CHANGELOG.md
@@ -7,6 +7,7 @@
 ## [Unreleased]
 
 ### Added
+- **Higgsfield pack, off by default**: `make plugin` installs the `@higgsfield/cli` CLI (Step 8.6) and clones the skills of higgsfield-ai/skills into `skills-external/higgsfield-*` through the new `lib/higgsfield-skills.sh`; `make update` refreshes both; `make doctor` reports the CLI and its session at info level. The pack belongs to no profile: `lib/toggle-external.sh enable higgsfield` links the seven allowlisted media skills, `enable higgsfield-websites` the landing-page aid, and no `profile set` or `make link` re-enables either. `CLAUDE.global.md` routes explicit media-generation asks to it. Hermetic suite `lib/tests/higgsfield.test.sh`.
 - **Effort round (BDR-108)**: every skill carries an entry level next to its model pin. `lib/effort-pins.txt` (map) + `lib/effort-pins.sh` (idempotent re-apply after the last vendoring step of `install-plugins.sh` and `update-all.sh`) replace the hardcoded brainstorming/writing-plans loop and extend the pins to the design stack (high, one level per stack since the last loaded wins), superpowers, agent-skills and the 21st pack; `skills-perso` low, `pdf-translate` medium, `site-motion` high; doctrine: the design stack loads paired with the first Read (a lone Skill call applies nothing). Model pins stay tier aliases: the latest version of a tier is also the cheapest or same-priced, so the quality/price trade-off is tier × effort, never version. `lib/effort-audit.py` prints thinking coverage per scope (sub-agent records carry no thinking count on ~90 % of requests: EVAL-037's "executors stay cheap" was a measurement gap, not a finding).
 - **Effort tiering (BDR-107)**: reasoning effort routed per role and per phase. Session default `high`; `effort:` pins on the 20 repo-authored agents; entry level on 28 tracked user-invoked skills plus the two vendored superpowers skills (re-applied by `install-plugins.sh` after resync); five shifter skills `effort-low` … `effort-max` loaded at phase boundaries per `lib/effort-shift.md`, always sent with the step's first tool call (a lone Skill call is a no-op on 2.1.283), with `max` at the verify-secure caps and ship-feature 4b; `/effort-max` as the turn-scoped relaunch lever; statusline shows the live level; session banner warns when `CLAUDE_CODE_EFFORT_LEVEL` silences the pins; census `lib/tests/effort-routing.test.sh`; transcript audit `lib/effort-audit.py`.
 - **Design gate asks the user to sign in to 21st instead of skipping it**:
@@ -400,6 +401,7 @@
   `verification-before-completion` to the verifier gates.
 
 ### Security
+- `settings.json` `permissions.deny` now refuses `npm i -g`, `npm install --global` and `npm i --global`: the rule matched `npm install -g` only, so the other spellings of the same global install went through.
 - **Ten secret-reader deny rules added**: `sed`, `awk`, `cut`, `tr`,
   `sort`, `uniq`, `diff`, `od`, `xxd`, `strings` against `.env*`. Six of
   those tools sat in `permissions.allow`, so reading a `.env` through
@@ -463,6 +465,7 @@
   plugin cache or `claude plugin list`.
 
 ### Fixed
+- `install-plugins.sh` never offered the ctx7 and 21st logins: both blocks required stdout to be a terminal, and stdout is the `tee` pipe of the install log. They now test stdin alone, as `update-all.sh` already did.
 - `lib/effort-pins.sh` residual LOW (security re-gate of BDR-108): INT/TERM trap removes the mktemp sibling and exits 130 (never an EXIT trap, the installer owns one); the post-write re-read message no longer claims CRLF and is reached by a stubbed unit test; the rejected map line is printed through `printf '%q'` so a caller's `echo -e` cannot interpret map content; the fixture suite guards its `mktemp -d` and skips the read-only case visibly under root.
 - `update-all.sh` re-fetched the vendored skills at every run but never re-applied the effort pins: brainstorming/writing-plans lost their xhigh until the next `make plugin` (BDR-107 gap, closed by `lib/effort-pins.sh`).
 - **gitflow pre-commit blocked every commit with gitleaks 8.16** (Ubuntu's apt
````

- [ ] **Step 3: Verify**

Run:
```bash
grep -q '^### Higgsfield' README.md && grep -q 'toggle-external.sh enable higgsfield' README.md && echo README_OK
awk '/^## \[Unreleased\]/{f=1;next} /^## \[/{f=0} f' CHANGELOG.md | grep -ci higgsfield
sed -n '/^### Higgsfield CLI/,/^---$/p' README.md | grep -c '—'
```
Expected: `README_OK`; a count of at least 1; then `0` (no em-dash in the new section).

- [ ] **Step 4: Commit**

```bash
git add README.md CHANGELOG.md
git commit -m "docs: Higgsfield pack in README and CHANGELOG"
```

---

### Task 8 (orchestrator only): Routing lines in CLAUDE.global.md

**Files:**
- Modify: `CLAUDE.global.md` (Skill routing, 6 lines after the SEO line; 306 → 312 lines, guard 320: BDR-062, BDR-098)

Hand edit of a guarded config (BDR-028). Not dispatched.

- [ ] **Step 1: Apply**

Run: `git apply docs/superpowers/plans/2026-09-30-higgsfield-pack.patches/08-claude-global.patch`

````diff
--- a/CLAUDE.global.md
+++ b/CLAUDE.global.md
@@ -266,6 +266,12 @@
   verification-before-completion → the verifier gates
 - SEO+GEO → seo (GEO only → geo); W3C + WCAG a11y → web-validate;
   security audit (secrets, CVE, OWASP) → cso
+- Media generation (image, video, audio, brand kit), explicit ask →
+  Higgsfield pack, off by default: `bash ~/.claude/lib/toggle-external.sh
+  enable higgsfield`, then Read the skill under `~/.claude/skills/`;
+  `higgsfield generate cost` before a paid run. Landing page "with
+  Higgsfield", named ask → `enable higgsfield-websites`: an aid inside
+  Design work and the site rules, never `website create|deploy|publish`.
 gstack OFF → its skills (investigate, qa, review, health, retro,
 office-hours…) are gone: use the fallback above, else say so.
 
````

- [ ] **Step 2: Verify**

```bash
[ "$(wc -l < CLAUDE.global.md)" -le 320 ] && echo GUARD_OK
make test suite=lib/tests/doctrine-citers.test.sh
make test suite=lib/tests/effort-routing.test.sh
```
Expected: `GUARD_OK`, both suites green. No heading or bold label is added, so no citer needs patching (BDR-100).

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.global.md
git commit -m "docs(global): route media generation to the Higgsfield pack"
```

---

### Task 9 (orchestrator only): Live state on this machine, full suite, gates

- [ ] **Step 1: First sync (network)**

Run in the repo root, in the Bash tool's own shell (no `bash -c`, which the settings ask about):
```bash
source lib/higgsfield-skills.sh && higgsfield_sync_skills "$PWD"
```
Expected: `8`. Upstream was read at f83af0b on 2026-09-30: no SKILL.md references a file outside its own folder, so dropping upstream's root `setup` and `scripts/` loses nothing.

- [ ] **Step 2: Enable the media pack**

```bash
bash lib/toggle-external.sh enable higgsfield
bash lib/toggle-external.sh status higgsfield-websites
```
Expected: `higgsfield enabled (7 skills: 0 restored, 7 linked)`, no warning (CLI answers, session active, no unlisted skill); then `disabled`.

- [ ] **Step 3: Tree stays clean, routing census stays green**

```bash
git status --short
make test suite=lib/tests/skill-routing-census.test.sh
```
Expected: only `.claude/` paths in the status (the pack is gitignored on both sides); the census green with the seven descriptions now in the live catalog (simulated at 0.50 max before the change).

- [ ] **Step 4: Full suite, doctor, gates**

```bash
make test
bash ~/.claude/lib/gates.sh run .claude/tasks/contracts/2026-09-30-higgsfield-pack-1412.md
```
Expected: make status 0; `GATES — VERDICT: MET`.
