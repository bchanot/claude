---
name: disk-clean
effort: low
description: |
  Use when the home disk is filling up and rebuildable residue must be
  found and reclaimed: Rust target/debug, docker build cache, superseded
  Playwright browsers, orphan Claude tmp dirs, node_modules of idle
  projects. Triggers: "disk-clean", "disque plein", "home à 85%",
  "libérer de l'espace", "no space left on device", "d'où vient
  l'utilisation disque", "supprime les résidus". NOT code cleanup
  (/code-clean) nor the all-axes project sweep (/tour).
argument-hint: "[root, default $HOME]"
allowed-tools:
  - Bash
  - Read
  - AskUserQuestion
---

# /disk-clean — measure, ask, then reclaim

**Nothing is deleted before the user picks it in STEP 3.** No answer, an
empty selection or a dismissed question = nothing deleted, end the run.
The gate covers every command, the two Claude may run included.

## STEP 1 — measure

`ROOT` = the argument when given, else `$HOME`.

```bash
df -h "${ROOT:-$HOME}" | tail -1
bash ~/.claude/skills/disk-clean/scripts/scan.sh "${ROOT:-$HOME}"
```

The scan is read-only. Rows: `category size age_days path note`.
`age_days` is the last change of the candidate; it informs, the user
decides (no idle threshold here). A cargo row noted `busy` is shown but
never offered.

For each cargo row, also show what would go and where `target` really
is (a `target-dir` in a `.cargo/config.toml` read from the cwd can move
it; metadata and clean run from the same cwd, so they agree). Both
commands delete nothing: `--dry-run` is the preview the doctrine asks
for before a destructive tool, not a run of it:

```bash
cargo clean --manifest-path '<dir>'/Cargo.toml --profile dev --dry-run | tail -1
cargo metadata --format-version 1 --no-deps \
  --manifest-path '<dir>'/Cargo.toml | jq -r .target_directory
```

`target_directory` ≠ `<dir>/target` → the row is dropped and named in
the report: the clean would reach outside the project.

## STEP 2 — show

One table, largest first: category, path, size, age, what happens if
picked (`Claude runs` or `you run`, from the action table below).

## STEP 3 — ask (the gate)

`AskUserQuestion`, `multiSelect: true`, one question per category present
(at most 4 per call; more categories → a second call). Each option label
= path + size. A category with more than 4 rows: the 3 largest by name,
the 4th option "the N others (size)" covering the rest, listed in its
description. A category with one row is asked single-select
(`multiSelect: false`) with options "<path> (size)" and "keep". Only
picked options move to STEP 4.

## STEP 4 — act on picked rows only

| Category | Action | Who |
|---|---|---|
| cargo | re-run the `busy` check for that dir, then `cargo clean --manifest-path '<dir>'/Cargo.toml --profile dev` | Claude |
| docker `Build Cache` | `docker builder prune -f` | Claude |
| docker `Images` | `! docker image prune -a -f` | user |
| docker `Local Volumes` | `! docker volume ls -f dangling=true`, then remove by name after reading | user |
| playwright | `! rm -rf '<path>'` per row (an older revision may still be pinned) | user |
| claude_tmp | `! find '<base>' -maxdepth 1 -name 'tmp.*' -mtime +N -exec rm -rf {} +`, N from the row note | user |
| superpowers | `! rm -rf '<path>'` per row (work logs of past subagent runs) | user |
| node_modules | `! rm -rf '<path>'` per row | user |

Claude runs those two commands and nothing else. Every other deletion is
printed as a `! command` for the user to run (doctrine: Destructive
tools & data loss), each path single-quoted, literal, and checked to
start with `ROOT/` before it is printed. The busy re-check, its own
call, right before each clean (prints the pid of a cargo/rustc running
inside `<dir>`; any output = busy = skip and report, never wait or kill):

```bash
for p in $(pgrep -x 'cargo|rustc'); do
  case "$(readlink "/proc/$p/cwd")/" in '<dir>'/*) echo "$p" ;; esac
done
```

Limit: the busy check sees host processes by cwd only, not a cargo in
a container or one started elsewhere with `--manifest-path`.

## STEP 5 — report

`df` before and after, what Claude ran with the reclaimed size it
printed, the `!` commands left for the user, rows skipped and why.

## Red flags — stop

- About to run a cleanup before the STEP 3 answer exists.
- "It's only a cache, it's safe": the gate still applies.
- A `rm -rf`, wildcard or `docker volume rm` in a Claude-run command.
- A `pgrep` chained with `;` before the clean: it gates nothing. Test it
  and skip on a match.
