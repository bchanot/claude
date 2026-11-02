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

Show the returned PLUGIN CHECK block.
- `ACTION REQUIRED? YES` → offer: A) fix plugins B) type "force". STOP until
  answered.
- OK → print `✅ Plugin check passed — [active plugins] — complexity: <score>%`.

## 5. APPLY GATE (main loop: only when the flow auto-activates)

If any plugin has ⚡ ENABLE status:
1. List the changes:
   ```
   PROPOSED CHANGES:
     ⚡ Enable ui-ux-pro-max (frontend detected, complexity 65%)
     ⚡ Pre-fetch ctx7 docs for next.js, prisma
   Apply these changes? (yes / no / customize)
   ```
2. "yes" → run the advisor's commands in order, each one `bash
   "$HOME/.claude/lib/profile.sh" -C <PROJECT_ROOT> set <name>` or `enable
   <pack>`. Each call writes `.claude/settings.local.json` atomically or
   refuses (rc 2, nothing written), so there is nothing to roll back: stop at
   the first non-zero rc, print its stderr, and continue with the current
   config. "customize" → user picks. "no" → proceed with current config.
3. After a successful write print `✅ Applied N change(s): run
   /reload-plugins to load the packs in this session (connectors and model:
   next session).` In a `--settings` conversation (`PROFILE :` block says
   `source=flag`) the advisor emits no enable for a pack the flag turns off;
   it says `relaunch: cc <name> <profile>` instead.

**Never auto-activate without showing the list and getting confirmation.
Never write the user scope.**
