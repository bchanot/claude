# DESIGN GATE — Auto-detect design tasks, ensure the design toolchain is active

Inline snippet. Include in any agent STEP 0 that may touch UI/design.

## WHEN TO RUN

Run this gate when the task description OR target files match design signals.

## DETECTION

Check BOTH the task description AND the filesystem:

**Task description signals** (case-insensitive match on $ARGUMENTS):
- UI keywords: `component`, `button`, `card`, `modal`, `dialog`, `tooltip`, `dropdown`, `sidebar`, `navbar`, `header`, `footer`, `layout`, `grid`, `form`, `input`, `table`
- Style keywords: `css`, `style`, `theme`, `color`, `font`, `spacing`, `margin`, `padding`, `border`, `shadow`, `animation`, `transition`, `hover`, `motion`, `animate`, `responsive`, `dark mode`, `light mode`
- Design keywords: `design`, `ui`, `ux`, `visual`, `polish`, `pixel`, `figma`, `mockup`, `wireframe`, `prototype`
- Framework UI: `tailwind`, `styled-component`, `emotion`, `chakra`, `radix`, `shadcn`, `headless`

**Filesystem signals** (quick check, no deep scan):
- Target files have `.tsx`, `.jsx`, `.css`, `.scss`, `.less`, or `.module.css` extension
- `tailwind.config` or `postcss.config` present in project root
- `tokens/`, `theme/`, or `design-system/` directory exists
- Storybook config (`.storybook/`) present
- Animation lib in `package.json` deps: `motion`, `motion-v`, `framer-motion` (legacy), `gsap`, `@gsap/react`, `lottie-react`, `react-spring`, `popmotion`, `@formkit/auto-animate`

## DECISION

Source of truth for activation is the **profile system** — never an atomic
per-tool toggle. The gate's whole job: confirm the design toolchain is active,
and if not, point at ONE command — `/profile design`.

### 1. Tier — does the gate even apply?

- **Trivial** (≤2 files, single cosmetic value, one CSS tweak — same scope as
  `/hotfix`) → no design tools required. Skip the gate, proceed.
- **Build UI / design system / review-audit** → toolchain required, continue.
- In doubt (trivial tweak vs real UI change) → do NOT silently skip: ask the
  user, or default to the Build tier.

Tier does NOT change WHAT gets checked. Every non-trivial design tier draws from
the one `design` profile — so the gate checks that profile's **design-core
tools** (the `# GATE-BLOCK:` allowlist in `design.profile`: ui-ux-pro-max,
frontend-design, emil-design-eng, design-motion-principles, impeccable, design-html,
design-review, design-consultation, magic). The profile also bundles
browser/plan/shotgun tooling and graphify for convenience; those never trip the
gate. Motion (`design-motion-principles`) and static-HTML (`design-html`) are
already in the core set — checked regardless; their CLAUDE.md "+motion /
+static" notes say which tool you'll lean on, not a separate activation step.

### 2. State — run the deterministic check

    bash "$HOME/.claude/lib/design-tool-gate.sh"

It reads the design-core tools (`# GATE-BLOCK:` in `design.profile`) plus their
types (`profile.sh show design --plain`) and checks each on its own channel —
skill symlink, `claude plugin list`, `claude mcp list`, `command -v`. It never
reads `disabledMcpServers` (unreliable for bi-modal servers like magic/context7).
The core set lives in `design.profile`, not in the script or here — single source.

Exit codes: `0` = ready · `11` = ready-but-unverified (proceed, but surface it) · `10` = incomplete (gate trips) · `2` = error.

### 3. Branch on the result

- **0 / `READY`** → proceed silently. Toolchain is active.
- **10 / `INCOMPLETE`** → STOP. The script reports up to three groups; relay
  them and the remedy to the user:

      🎨 DESIGN DETECTED — the design toolchain isn't fully active.
      activate with /profile design:        <skills / ui-ux-pro-max>
      required + manual step:                <e.g. magic — needs MAGIC_API_KEY>
      → run  /profile design  to activate it, then continue.

  - **activate with /profile design** → skills + the plugin; `/profile design`
    turns them on directly.
  - **required + manual step** → required tools the profile can't flip silently.
    **magic lands here: it TRIPS the gate** (it's required for Build), it is NOT
    a silent "optional". `/profile design` runs `toggle-external.sh` for magic,
    which needs a valid `MAGIC_API_KEY` in `~/.claude/.env` — tell the user to verify it.
  - Do NOT hand-activate individual tools. The profile is the unit of activation.
- **11 / `READY BUT UNVERIFIED`** → `claude` was unreachable, so the design
  plugin/MCP (magic, ui-ux-pro-max) could NOT be checked. Do NOT report a plain
  "ready": proceed only after telling the user that N tool(s) went unverified and
  having them confirm with `claude mcp list` / `claude plugin list`. Fail-visible,
  not fail-silent — the most important tool (magic) is exactly an unverifiable one.

### 4. Animation library — suggest-only (fires only on a real motion signal)

Orthogonal to the toolchain check above: §2-3 are about Claude's design TOOLS;
this is about the PROJECT's runtime dep. Evaluate it only once the toolchain is
resolved and you're actually proceeding with the build (READY, or after the user
ran `/profile design`). Never on the INCOMPLETE stop path — that path has one
action only (`/profile design`); don't stack an optional note on it.

**Fires only when ALL THREE hold** — drop any one → no suggestion, stay silent:

1. **Motion signal** — the task matched a motion keyword from §DETECTION:
   `animation`, `transition`, `hover`, `motion`, or `animate`. A static
   button / card / layout with no motion signal needs no anim lib → skip.
2. **Stack eligible** — `detect_anim_eligibility` returns `eligible|…`.
3. **No anim lib yet** — `is_anim_lib_installed` finds none.

Only if condition 1 holds, run the helper for 2 and 3 — do NOT re-list packages
here; the helper's `is_anim_lib_installed` is the single source of which libs
count:

    source "$HOME/.claude/lib/animation-lib-check.sh"
    result=$(detect_anim_eligibility)            # '<status>|<package>|<reason>'
    status=$(echo "$result" | cut -d'|' -f1)
    pkg=$(echo "$result"    | cut -d'|' -f2)
    reason=$(echo "$result" | cut -d'|' -f3)
    if [ "$status" = "eligible" ] && ! is_anim_lib_installed >/dev/null; then
      cmd=$(recommend_anim_install_cmd "$pkg")   # pnpm/yarn/bun/npm per lockfile
      # → surface the one-line suggestion below. Do NOT run $cmd.
    fi

**Surface — always this single line (non-blocking, suggest-only):**

    🎬 Stack motion-eligible (<reason>), no anim lib — `<cmd>`? (optional; say the word, I'll add it)

**Rules:**

- **Suggest-only, never auto-install.** Run `<cmd>` ONLY on explicit user
  consent. BDR-005: mid-session + existing `package.json` = consent required —
  same contract as `/onboard` STEP 2.5, opposite of `/init-project` STEP 5e
  (auto-install on a just-validated fresh scaffold).
- **Non-blocking.** Never halts the build; NOT a second gate. The toolchain stop
  (§3, exit 10) is the only STOP. Surface the line, keep going.
- **Stateless dedup, by construction.** The suggestion is ALWAYS the single line
  above — no first-time-block / later-short split. That split would need session
  state the gate doesn't have, and a file marker would persist forever (per
  project, not per session). Determinism here comes from having nothing to
  remember, not from a behavioral "the agent recalls it" guard. Re-fire is one
  ignorable line, on a narrow population: condition 3 (`is_anim_lib_installed`,
  10 libs incl gsap / react-spring / lottie) kills it the instant any anim lib
  lands, so only "eligible + pure-CSS + actively declined" ever sees it twice.
- **Two "motion"s (agent-facing).** The lib `motion` (npm dep, this step) ≠ the
  skill `design-motion-principles` (`# GATE-BLOCK:` core set, §2-3). The
  toolchain check handles the skill; this step handles the lib. Don't conflate
  them when talking to the user.

### Other toolchains

The script defaults to the `design` profile. A task needing another profile's
toolchain passes it: `design-tool-gate.sh <profile>`. Scope comes from that
profile's `# GATE-BLOCK:` line (absent → every skill/plugin/mcp entry). The
remedy is always `/profile <that>` — a profile, never a lone tool.

## IMPORTANT

- Remedy is ALWAYS a profile (`/profile design`), never an atomic tool toggle —
  the profile system is the single source of truth for what's active.
- magic is REQUIRED (it trips the gate), but `/profile design` only enables it
  if `MAGIC_API_KEY` is in `~/.claude/.env` — the gate says so; surface that to the user.
- The design-core set (what trips the gate) is declared in `design.profile` on
  the `# GATE-BLOCK:` line(s) — edit there to add/remove a blocking design tool,
  not in the script.
- The state check shells out to `claude` (plugin/mcp list): a few seconds.
  Trivial / non-design tasks skip it entirely (no signal, or trivial tier).
- `design-tool-gate.sh`'s per-type state checks MIRROR
  `profile.sh:skill_status()` — change one, sync the other.
- Do NOT run this gate on pure backend/API/CLI tasks (no signals = no gate).
