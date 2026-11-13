# Plugin gate — shared consumer include (plugin-check, onboard, init-project, ship-feature STEP 0)

Runs in the CONSUMER'S MAIN LOOP. The detection and the reasoning are
dispatched (BDR-077 tiers); the validation checkpoint, the report
presentation, and the apply gate live HERE — a dispatched agent can neither
ask the user nor safely mutate plugin state.

## 1. PROBE (dispatch — sonnet)

```
Agent(subagent_type="plugin-probe", description="plugin gate — probe",
      prompt="Run your probes from <PROJECT_ROOT>. Emit the PROBE REPORT.")
```

## 2. VALIDATION CHECKPOINT (main loop: between probe and reasoner)

Validate the PROBE REPORT before any reasoning:
- `PROFILE` block holds a `profile=` line.
- At least one project signal present (MANIFESTS / FRAMEWORK-DEPS /
  TSX-JSX-COUNT > 0 / DOCKER-COUNT > 0 / EMBEDDED hits). Else print
  `⚠️ No project signals detected: recommendations will be conservative.`
  and continue.
- `CHECKPOINT profile-sh=UNAVAILABLE` → print `⚠️ profile.sh unavailable:
  recommendations will be advisory only, no auto-activation.` and SKIP
  step 5 (apply) entirely.
- PROBE REPORT missing/unparsable → retry the probe ONCE fresh; a 2nd
  failure → STOP and surface (never reason over invented detection).

## 3. REASON (dispatch — opus)

```
Agent(subagent_type="plugin-advisor", description="plugin gate — reason",
      prompt="""
REQUEST: <the user's request / project description, verbatim>
PROBE REPORT (ground truth — do not re-detect):
<the full PROBE REPORT from step 1>
""")
```

## 4. PRESENT + BLOCKING GATE (main loop)

Show the returned PLUGIN CHECK block. The advisor emits tokens only; the
main loop builds every command from the fixed templates of step 5, never
pastes the advisor's text into a shell. A PROJECT_ROOT holding `'`, a
newline or a control character is never substituted into a template: print
the commands with the root shown as `'<root>'` and a warning that the
user must quote it by hand, and run nothing. Before running ANY command (the step-4 diff
included) check each token: a profile name is one of the advisor's own
set (web, seo, dev, design, qa, audit, minimal; never `full`, `max` or a
user-added profile) and matches `^[a-z0-9][a-z0-9-]*$` with an existing
`$HOME/.claude/lib/profiles/<name>.json`; a pack is one of design, scroll3d,
seo, web-validate, gstack-dev, gstack-browser, gstack-design (`higgsfield`
and `extras` are never accepted from an advisor token: paid or
credit-metered services, explicit user ask only, `profile.sh enable extras`
by hand); a plugin is one of the two managed full ids
`ui-ux-pro-max@ui-ux-pro-max-skill`, `pr-review-toolkit@claude-code-plugins`.
A token matching none is printed as rejected and skipped, never run.
For a `↻ SET <profile>` line run
`bash "$HOME/.claude/lib/profile.sh" -C '<PROJECT_ROOT>' diff '<profile>'` and
print its `→ off` lines under it as "turns off" (none → "turns off: nothing")
and its `→ on` lines as "turns on" (none → "turns on: nothing").
The diff exits non-zero on a bad name, an unknown profile or a missing
profiles dir: on any non-zero exit print "turns off: unknown" and continue.
- `ACTION REQUIRED? YES` → offer: A) fix plugins (print "run `make plugin`
  in your claude-config checkout", run nothing) B) type "force". STOP until
  answered.
- OK → print `✅ Plugin check passed — [active plugins] — complexity: <score>%`.

## 5. APPLY GATE (main loop: only when the flow auto-activates)

Trigger: a `↻ SET`, `⚡ ENABLE` or `⚠️ DISABLE` line. Under `source=flag`
(`PROFILE :` block) the advisor emits only `relaunch: cc <name> <profile>`:
nothing is applied. Apply only when the parent of
`git -C '<PROJECT_ROOT>' rev-parse --path-format=absolute --git-common-dir`
(the root profile.sh writes at, same in a linked worktree) equals
PROJECT_ROOT and PROJECT_ROOT is not `$HOME`;
otherwise print the commands and apply nothing, naming the cause: no git
root yet (run them after git init), a linked worktree or submodule, or
PROJECT_ROOT is `$HOME`.
1. List the changes, saying they are project-wide and persist in
   `<PROJECT_ROOT>/.claude/settings.local.json`:
   ```
   PROPOSED CHANGES (project-wide, persisted in
   <PROJECT_ROOT>/.claude/settings.local.json):
     ↻ Set profile dev (backend detected) — turns off: <diff lines>
     ⚡ Enable pack design (frontend detected, complexity 65%)
     ⚡ Enable ui-ux-pro-max@ui-ux-pro-max-skill
   Apply these changes? (yes / no / customize)
   ```
2. "yes" → run the changes in order, the SET first, then the deltas (after
   "customize" too). Each one is
   `bash "$HOME/.claude/lib/profile.sh" -C '<PROJECT_ROOT>' set '<name>'`,
   `... enable '<pack | full plugin id>'` or
   `... disable '<pack | full plugin id>'` (same prefix). Each call
   writes `.claude/settings.local.json` atomically or refuses (rc 2, nothing
   written): stop at the first non-zero rc, print its stderr, and continue
   with the current config. "customize" → user picks. "no" → proceed with
   current config.
3. After a successful write print `✅ Applied N change(s): run
   /reload-plugins to load the packs in this session (connectors and model:
   next session).` Say the change is project-wide and persists in
   `<PROJECT_ROOT>/.claude/settings.local.json`. Print the undo: after a SET:
   `bash "$HOME/.claude/lib/profile.sh" -C '<PROJECT_ROOT>' unset`, after
   deltas the inverse enable / disable.

**Never auto-activate without showing the list and getting confirmation.
Never write the user scope.**
