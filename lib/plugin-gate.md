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

## 2. VALIDATION CHECKPOINT (main loop — between probe and reasoner)

Validate the PROBE REPORT before any reasoning:
- `EXTERNAL` non-empty AND each listed plugin's directory appears under
  `CHECKPOINT plugin-dirs`.
- At least one project signal present (MANIFESTS / FRAMEWORK-DEPS /
  TSX-JSX-COUNT > 0 / DOCKER-COUNT > 0 / EMBEDDED hits). Else print
  `⚠️ No project signals detected — recommendations will be conservative.`
  and continue.
- `CHECKPOINT toggle-script=UNAVAILABLE` → print `⚠️ toggle script
  unavailable — recommendations will be advisory only, no auto-activation.`
  and SKIP step 5 (apply) entirely.
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

## 5. APPLY GATE (main loop — only when the flow auto-activates)

If any plugin has ⚡ ENABLE status:
1. List the changes:
   ```
   PROPOSED CHANGES:
     ⚡ Enable ui-ux-pro-max (frontend detected, complexity 65%)
     ⚡ Pre-fetch ctx7 docs for next.js, prisma
   Apply these changes? (yes / no / customize)
   ```
2. "yes" → apply via the exact commands the advisor emitted. "customize" →
   user picks. "no" → proceed with current config.

**Never auto-activate without showing the list and getting confirmation.**

### Rollback on partial failure

Track each toggle; roll back the partial set rather than leave a
half-applied configuration:

```bash
applied=()
for change in "${PROPOSED_CHANGES[@]}"; do
  if bash "$HOME/.claude/lib/toggle-external.sh" enable "$change"; then
    applied+=("$change")
  else
    echo "❌ failed to enable $change — rolling back ${#applied[@]} prior change(s)"
    for prior in "${applied[@]}"; do
      bash "$HOME/.claude/lib/toggle-external.sh" disable "$prior" \
        || echo "⚠️ rollback of $prior also failed — manual cleanup required: see ~/.claude/plugins/cache"
    done
    exit 1
  fi
done
```

Surface: `✅ Applied N change(s).` — or on failure:

```
⚠️ Toggle failed at change <name>. Rolled back the N prior change(s).
   To inspect manually: ls ~/.claude/plugins/cache; bash ~/.claude/lib/toggle-external.sh list
   Re-run /plugin-check after fixing the underlying cause (e.g. permissions).
```
