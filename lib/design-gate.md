# DESIGN GATE — Auto-detect design tasks, activate ui-ux-pro-max

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

## DECISION

If **at least one signal** is detected:

1. Check if `ui-ux-pro-max` is active:
   ```bash
   source "$HOME/.claude/lib/detect-plugins.sh"
   detect_uiux_pro_max && echo "ACTIVE" || echo "INACTIVE"
   ```

2. If **ACTIVE** → proceed silently. The plugin context is already available.

3. If **INACTIVE** → ask the user:
   ```
   🎨 DESIGN DETECTED — task touches UI/styling.
   ui-ux-pro-max is not active. Activate it for design-aware guidance?
   (yes / no)
   ```
   - On **yes** → print `⚡ Activating ui-ux-pro-max...` and proceed with design context.
   - On **no** → print `Proceeding without design plugin.` and continue normally.

## IMPORTANT

- This gate adds ~5 seconds overhead. Worth it for design quality.
- Do NOT run this gate on pure backend/API/CLI tasks (no signals = no gate).
- If no signal detected → skip entirely, zero overhead.
