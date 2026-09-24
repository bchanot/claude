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
- Target files have `.tsx`, `.jsx`, `.vue`, `.svelte`, `.astro`, `.css`, `.scss`, `.less`, or `.module.css` extension
- `tailwind.config` or `postcss.config` present in project root
- `tokens/`, `theme/`, or `design-system/` directory exists
- Storybook config (`.storybook/`) present
- Animation lib in `package.json` deps: any package `is_anim_lib_installed` recognizes (`lib/animation-lib-check.sh`, the single source)

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
frontend-design, emil-design-eng, design-motion-principles, design-html,
design-review, design-consultation, the `21st` CLI and `21st-ui-build` — the
canary for the whole 21st skill pack). The profile also bundles
browser/plan/shotgun tooling and graphify for convenience; those never trip the
gate. Motion (`design-motion-principles`) and static-HTML (`design-html`) are
already in the core set — checked regardless; their CLAUDE.md "+motion /
+static" notes say which tool you'll lean on, not a separate activation step.

### 2. State — run the deterministic check

    bash "$HOME/.claude/lib/design-tool-gate.sh"

It reads the design-core tools (`# GATE-BLOCK:` in `design.profile`) plus their
types (`profile.sh show design --plain`) and checks each on its own channel —
skill symlink, `claude plugin list`, `claude mcp list`, `command -v`. It never
reads `disabledMcpServers` (unreliable for bi-modal servers like context7).
The core set lives in `design.profile`, not in the script or here — single source.

Exit codes: `0` = ready · `11` = ready-but-unverified (proceed, but surface it) · `10` = incomplete (gate trips) · `2` = error.

### 3. Branch on the result

- **0 / `READY`** → proceed silently. Toolchain is active.
- **10 / `INCOMPLETE`** → STOP. The script reports up to three groups; relay
  them and the remedy to the user:

      🎨 DESIGN DETECTED — the design toolchain isn't fully active.
      activate with /profile design:        <skills / ui-ux-pro-max>
      required + manual step:                <e.g. 21st — needs the CLI>
      → run  /profile design  to activate it, then continue.

  - **activate with /profile design** → skills + the plugin; `/profile design`
    turns them on directly.
  - **required + manual step** → required tools the profile can't flip silently.
    **the `21st` CLI lands here: it TRIPS the gate** (it's required for Build),
    it is NOT a silent "optional". `/profile design` symlinks the 21st skills,
    but the CLI they shell out to is a global npm install: tell the user to run
    `npm i -g @21st-dev/cli` then `21st login` (no API key, no MCP).
  - Do NOT hand-activate individual tools. The profile is the unit of activation.
- **11 / `READY BUT UNVERIFIED`** → `claude` was unreachable, so the design
  plugin (ui-ux-pro-max) could NOT be checked. Do NOT report a plain "ready":
  proceed only after telling the user that N tool(s) went unverified and having
  them confirm with `claude plugin list`. Fail-visible, not fail-silent.

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

### 5. Impeccable design context — suggest-only (one check, one line)

Same class as §4: a PROJECT-side prerequisite, not a tool. `impeccable`
installs globally, but every one of its verbs reads a per-project `PRODUCT.md`
that only `/impeccable init` writes. Without it the skill runs on invented
context, which is worse than not running it — and nothing else in the process
says so, because init has to happen in the agent chat, not in an installer.

**Fires when BOTH hold** — else stay silent:

1. impeccable symlink present under `skills/` (non-blocking external — not on the `# GATE-BLOCK:` list, so §3 never checks it).
2. The project has no `PRODUCT.md` at its root.

Evaluate it on the same path as §4: after the toolchain resolves, never on the
INCOMPLETE stop path. One line, non-blocking:

    🧭 impeccable has no project context here (no PRODUCT.md) — run `/impeccable init` first? (optional)

**Rules:**

- Non-blocking, and never run `init` unprompted: it interviews the user about
  the product, so it needs their attention, not their absence.
- One line per session at most. A refusal is an answer; do not re-ask inside
  the same task.
- Skip entirely for a review/audit of a single component and for any non-UI
  work. This is for Build and design-system tiers.

### Other toolchains

The script defaults to the `design` profile. A task needing another profile's
toolchain passes it: `design-tool-gate.sh <profile>`. Scope comes from that
profile's `# GATE-BLOCK:` line (absent → every skill/plugin/mcp entry). The
remedy is always `/profile <that>` — a profile, never a lone tool.

## IMPORTANT

- Remedy is ALWAYS a profile (`/profile design`), never an atomic tool toggle —
  the profile system is the single source of truth for what's active.
- the `21st` CLI is REQUIRED (it trips the gate) and `/profile design` cannot
  install it — the gate names the two commands; surface them to the user.
- The design-core set (what trips the gate) is declared in `design.profile` on
  the `# GATE-BLOCK:` line(s) — edit there to add/remove a blocking design tool,
  not in the script.
- The state check shells out to `claude` (plugin/mcp list): a few seconds.
  Trivial / non-design tasks skip it entirely (no signal, or trivial tier).
- `design-tool-gate.sh`'s per-type state checks MIRROR
  `profile.sh:skill_status()` — change one, sync the other.
- Do NOT run this gate on pure backend/API/CLI tasks (no signals = no gate).
