# DESIGN GATE — Auto-detect design tasks, ensure the design toolchain is active

Inline snippet. Include in any agent STEP 0 that may touch UI/design.

## WHEN TO RUN

Run this gate when the task description OR target files match design signals.

## DETECTION

Check BOTH the task description AND the filesystem:

**Task description signals** (case-insensitive match on $ARGUMENTS):
- UI keywords: `component`, `button`, `card`, `modal`, `dialog`, `tooltip`, `dropdown`, `sidebar`, `navbar`, `header`, `footer`, `layout`, `grid`, `form`, `input`, `table`
- Style keywords: `css`, `style`, `theme`, `color`, `font`, `spacing`, `margin`, `padding`, `border`, `shadow`, `animation`, `transition`, `hover`, `responsive`, `dark mode`, `light mode`
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
frontend-design, emil-design-eng, design-motion-principles, design-html,
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

Exit codes: `0` = ready (proceed) · `10` = incomplete (gate trips) · `2` = error.

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
    which needs a valid `MAGIC_API_KEY` in `.env` — tell the user to verify it.
  - Do NOT hand-activate individual tools. The profile is the unit of activation.
- **`unverified` line** (claude CLI absent) → the state of a plugin/mcp couldn't
  be checked; it does not block. Mention it, proceed.

### Other toolchains

The script defaults to the `design` profile. A task needing another profile's
toolchain passes it: `design-tool-gate.sh <profile>`. Scope comes from that
profile's `# GATE-BLOCK:` line (absent → every skill/plugin/mcp entry). The
remedy is always `/profile <that>` — a profile, never a lone tool.

## IMPORTANT

- Remedy is ALWAYS a profile (`/profile design`), never an atomic tool toggle —
  the profile system is the single source of truth for what's active.
- magic is REQUIRED (it trips the gate), but `/profile design` only enables it
  if `MAGIC_API_KEY` is in `.env` — the gate says so; surface that to the user.
- The design-core set (what trips the gate) is declared in `design.profile` on
  the `# GATE-BLOCK:` line(s) — edit there to add/remove a blocking design tool,
  not in the script.
- The state check shells out to `claude` (plugin/mcp list): a few seconds.
  Trivial / non-design tasks skip it entirely (no signal, or trivial tier).
- `design-tool-gate.sh`'s per-type state checks MIRROR
  `profile.sh:skill_status()` — change one, sync the other.
- Do NOT run this gate on pure backend/API/CLI tasks (no signals = no gate).
