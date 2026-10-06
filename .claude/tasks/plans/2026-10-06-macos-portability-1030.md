# Plan — make test green on macOS: portable shell idioms (tests + prod) — r3

Date: 2026-10-06 · Branch: bugfix/macos-portability · Kind: build-plan (bugfix)
r2 after the three-lens challenge (correctness FATAL(6), robustness
CONCERNS(4), simplicity FATAL(2)); every BLOCKER/MAJOR closed by a named
change below, see § Challenge log.

## Bug
`make test` red on develop: 13 suites, ~45 FAIL lines. Suite and libs were
written and validated on Linux (GNU userland); this machine is macOS (BSD
userland, bash 5.3 from Homebrew, `timeout`/`gdate` only via
/opt/homebrew/bin, NO gnu-sed). Per-suite FAIL → cause map:

| Suite | FAIL | Cause |
|---|---|---|
| lib/gitflow-test.sh | 15 "merged into…" | early-exit consumer under pipefail (A) |
| lib/tests/run-release-candidate.sh | CHANGELOG not finalized | `sed -i` no suffix (B) |
| floor-guard, profile-census, profile-default .test.sh | 1+2+1 | `sed -i` no suffix (B) |
| effort-pins (3), source-scope (2), fast-libs H2-H4 (3) | string-compare of `wc -l` | BSD wc pads (C) |
| lib/seo-data/seo-data.test.sh | 3 perms + 1 stdlib | `stat -c` (D), `/bin/grep` (E) |
| fast-libs T7-stale | 1 | `touch -d` (F) |
| gstack-links T4 | 3 | `realpath -m` absent → guard never fires (G, prod) |
| design-tool-gate | 5 | bare `timeout` off the sanitized PATH (H, prod) |
| doctrine-citers T3 | 1 | extractor false positive + regex-interpolated resolver (I) |
| effort-routing | 2 | pins dropped from 2 gitignored SKILL.md on 2026-10-05 (J, machine state) |

Not red but same class, found by the challenge: lib/doc-shape.sh:70 (git
producer `| grep -Eq` under pipefail, fails OPEN: structural doc change
classed MINOR), update-all.sh:607 (`grep -oP`, BSD grep rc 2, `|| true`
silently empties `_plugins` → marketplace plugins never update on macOS).

## Root cause classes and their portable form
- (A) **Early-exit consumer under `set -o pipefail`**: `grep -q`, `head -1`,
  awk `{print; exit}` exit before the producer finished → producer gets
  SIGPIPE → rc 141 → pipeline false. Reproduced 5/5 on `git log | grep -q`.
  NOT fixed by `grep PAT >/dev/null` (GNU grep treats stdout=/dev/null like
  `-q`, challenger-verified in grep's main()). Portable form: take the
  producer OUT of the pipeline — tests: `grep -q PAT < <(cmd)`; prod:
  `out="$(cmd)"` then grep/awk/head the variable (here-string). Only sites
  whose producer is an external command under pipefail. `printf '%s' "$v" |
  grep -q` is safe (builtin writes once; 50/50 probe) and is left alone.
- (B) `sed -i 'x' f` → tests (temp dirs): `sed -i.bak 'x' f && rm -f f.bak`.
  Prod on a user dotfile: unique sibling `t=$(mktemp "$f.XXXXXX")`, `sed 'x'
  "$f" >"$t" && cat "$t" >"$f"`, `rm -f "$t"`, explicit failure branch (never
  `-i.bak`: it would overwrite and then delete a hand-made ~/.zshrc.bak, and a
  failing sed in a non-final `&&` escapes errexit).
- (C) `$(… | wc -l)` → append `| tr -d ' '` (idiom of hooks/unpushed-guard.sh:41).
- (D) `stat -c '%a'` → `python3 -I -c 'import os,stat,sys; print(oct(stat.S_IMODE(os.stat(sys.argv[1]).st_mode))[2:])' F`.
- (E) `/bin/grep` → `/usr/bin/grep` (LRN-074 pin, 6 files already).
- (F) `touch -d '10 days ago' F` → `touch -t 200001010000 F` (POSIX; cache_status only tests `-mtime -N`).
- (G) `realpath -m` → emulate: walk up to the nearest EXISTING ancestor, `cd` + `pwd -P`, append the unresolved remainder.
- (H) bare `timeout 15` → `perl -e 'alarm shift; exec @ARGV' 15 …` (perl ships in /usr/bin on both OS; keeps the 15 s bound everywhere, comment stays true).
- (I) citation name must start with a non-blank; resolver matches FIXED strings (awk `index()` on heading / bold lines), never interpolates the name into `-E`.

## Decided (user, 2026-10-06)
- Scope: tests AND prod sites. Doctrine: POSIX/BSD-portable scripts on the
  native userland of both OS. Rejected: Homebrew GNU tools on PATH.

## Fix plan (exact sites)
1. lib/gitflow-test.sh — the 26 assertions whose producer is an external
   command (git, bash …) `cmd | grep -q[xF|i] PAT` → `grep -q[xF|i] PAT <
   <(cmd)` (A); the 11 `printf '%s' "$v" | grep -q` sites stay. Same form at
   lib/tests/gstack-playwright.test.sh:126-127 (negative destructive-command
   guard, fails OPEN on SIGPIPE), lib/tests/run-doc-commit.sh:104 (git
   status), lib/tests/run-release-candidate.sh:55 (git show).
2. lib/profile.sh:269-274 and lib/design-tool-gate.sh:163-165 — capture
   `claude plugin list` into a variable, then awk+grep on it (kills both the
   awk `exit` and the grep -q race). lib/profile.sh:285,374,444,
   lib/design-tool-gate.sh:170, lib/toggle-external.sh:142,
   install-plugins.sh:474 — the call STAYS inside the condition:
   `if grep -q[iE] PAT <<<"$(cmd 2>&1)"; then` (A). Never a bare
   `out="$(cmd)"`: profile.sh:374/444 (enable_skill/disable_skill),
   install-plugins.sh:474 (install_plugin) and toggle-external.sh:142
   (pack_hints) run bare under `set -euo pipefail`, a bare capture of a
   failing CLI would abort `profile.sh set` / `make plugin` (confirmation
   pass, bash 5.3 probe). lib/tests/profile-set-managed.test.sh — add a
   fake-claude case returning rc≠0 on `plugin enable` so the regression is
   caught.
3. lib/design-tool-gate.sh:125 — `line="$(perl -e 'alarm shift; exec @ARGV' 15 21st whoami 2>/dev/null </dev/null)"`, first line via `${line%%$'\n'*}` (H + A). install-plugins.sh:1143 `TFD_WHO=$(21st whoami … | head -1)` — same capture-then-first-line (A, errexit-safe).
4. lib/design-tool-gate.sh `ensure_21st_on_path` / `ensure_claude_on_path` — add `/opt/homebrew/bin/<bin>` to the candidate list (Apple-Silicon npm global prefix, `npm prefix -g` = /opt/homebrew here). SAME change: lib/tests/design-tool-gate.test.sh:20-21 hermeticity precondition gains `|| [ -e /opt/homebrew/bin/21st ]` so CLI_ABSENT_10 skips loudly instead of reaching a real CLI.
5. lib/doc-shape.sh:70 — `grep -Eq … < <(git diff HEAD -- "$p")` (A).
6. update-all.sh:607 — `grep -oP '(?<=❯ )\S+'` → `sed -n 's/.*❯ \([^[:space:]][^[:space:]]*\).*/\1/p'` (non-empty token, so a line ending in "❯ " never yields `claude plugin update ""`; one token per line, as `claude plugin list` prints one plugin per line).
7. install-plugins.sh:1201,1204 — sibling-temp form (B). Delete :1207-1208
   (`{ N; /^\n$/d; }`): dead on GNU (pattern space never `^\n$`), and BSD `N`
   at EOF would DROP the marker comment; deletion = GNU behaviour preserved.
8. lib/tests/run-release-candidate.sh:43, floor-guard.test.sh, profile-census.test.sh, profile-default.test.sh — `-i.bak` + rm (B); BSD sed expands `\n` in the replacement, no rewrite.
9. lib/tests/effort-pins.test.sh:41,99,109; source-scope.test.sh:48,49,66; fast-libs.test.sh:46,47,50 — `| tr -d ' '` (C).
10. lib/seo-data/seo-data.test.sh:26,28,480 (D); :139 (E).
11. lib/tests/fast-libs.test.sh:39 (F).
12. lib/gstack-links.sh:64 — `_gstack_links_realpath_m <path>` helper (G):
    refuse (rc 1, warn) any path holding a `..` component; walk up with
    `[ -d ]` to the nearest existing directory; `CDPATH= cd -P -- "$dir" &&
    pwd -P`; append the unresolved remainder. Line 63 unchanged (plain
    `realpath` is native on both). lib/tests/gstack-links.test.sh — add T4b:
    dst=`$SRC/missing/x` (parent absent) must be refused, nothing created.
13. lib/tests/doctrine-citers.test.sh:19 extractor `["“][^"”[:space:]][^"”]{1,59}["”]`; :27-28 resolver → awk, fixed strings (I): a heading line resolves when the text right after `#+ ` STARTS with the name and the next char is one of ` ` `:` `(` `—` or end of line; a `**name` substring anywhere on a line still resolves (bullet labels like `- **Secrets**`). Flip fixture gains a case: doctrine heading "Alphabet", citation "Alpha" → must stay DANGLING.
14. Machine state (no commit): `bash lib/effort-pins.sh` re-pins the two skills (J).
15. Regression guard `lib/tests/portability-census.test.sh` — DETERMINISTIC
    idioms only, over a file list given as args (default: tracked `*.sh` +
    `hooks/*`), comment lines skipped, exit 2 on hit:
    `sed -i ['"]` (no suffix) · `stat -c` · `realpath -m` · `touch -d` ·
    `grep -[A-Za-z]*P` · `(^|[^a-z])/bin/grep`.
    Allowlist with reasons, file:line: lib/tests/guard-bash.test.sh:221,225
    (deny fixtures must keep the GNU spelling an agent types), and the census
    file itself. Flip test: plant `sed -i 's/a/b/' x` in a mktemp dir and pass
    that file as the arg → must red. NO `| grep -q` rule (not deterministic
    by text; the real fix is structural). Makefile untouched (glob already
    picks `lib/tests/*.test.sh`).
16. TODO.md: known re-red trigger — update-all.sh applies pins only at :572
    after every vendoring step; an abort upstream drops them again. Follow-up:
    pin right after each vendoring step or flag in doctor.

Untouched on purpose: hooks/rtk-rewrite.sh:115 (not under pipefail,
sha256-pinned hook); doctor.sh:405,564 (printf/one-line producers, cannot
SIGPIPE; doctor not in the suite); other `printf | grep -q` sites.

## Acceptance
- `make test` exits 0 on this macOS machine; no SKIP added, no suite removed.
- New: gstack-links T4b green; portability census green on the tree and red
  on the planted fixture.
- Linux: NOT verifiable from this machine. Every replacement is chosen to be
  semantically identical under GNU tools (producer capture, `-i.bak`, tr,
  python3, perl alarm, sed -n). `[deferred 2026-10-06]` a Linux `make test`
  run before the next release is the human's call.

## Out of scope
- Why the 2026-10-05 fetch dropped the two pins (not reproduced; TODO entry).
- lib/tests/effort-routing.test.sh reading live gitignored files (it is the drift detector).
- doctor.sh `readlink -f` (separate pass).

## Challenge log (r1 → r2)
- BLOCKER (correctness 1, simplicity 1, robustness 4): census red by
  construction → §15 narrowed to deterministic idioms, file-list arg,
  allowlist, self-exclusion, no `grep -q` rule.
- MAJOR (correctness 2): `>/dev/null` is not a fix under GNU grep → class (A)
  form = producer out of the pipeline.
- MAJOR (correctness 3, robustness 3): upstream awk `exit` / `head -1` → §2, §3 capture first.
- MAJOR (correctness 4, robustness 3): missed same-class prod sites → §5 doc-shape, §6 update-all.
- MAJOR (correctness 5, robustness 1): `-i.bak` on dotfiles → sibling temp, explicit failure.
- MAJOR (correctness 6, robustness 2): gstack-links fallback false → §12 ancestor walk + T4b.
- MINOR accepted: `/usr/bin/grep` (LRN-074), `touch -t`, dead :1208 deleted,
  Makefile untouched, perl alarm bound, /opt/homebrew/bin candidates,
  fixed-string resolver, TODO re-red trigger.
- MINOR declined: none.
- Confirmation pass (correctness CONCERNS(2), r3): MAJOR errexit on bare
  capture → §2 keeps the call inside the condition + rc≠0 fake-claude case;
  MAJOR hermeticity → §4 precondition; MINOR 4 unlisted class-(A) test sites
  → §1; resolver semantics + Alphabet/Alpha flip → §13; `..`/CDPATH/-P →
  §12; non-empty token → §6.
