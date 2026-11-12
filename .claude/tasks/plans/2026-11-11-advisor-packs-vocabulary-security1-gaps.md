# RUN B — security round 1 (GATE 2 BLOCK(1) after GATE 1 CONFORME), 2026-11-11

Apply on top of the current working tree (RUN B rounds 1-3 in place, uncommitted). Binding: plan r3, round-2 and round-3 gap lists, contract CLARIFICATIONS.

## BLOCKING (HIGH) — must close
B1. skills/onboard/SKILL.md:254 (consent prompt :257 "yes install now"): the install action must not depend on the working directory and must never run `make plugin` / install-plugins.sh (/onboard runs inside a foreign repo: a bare `make plugin` runs that repo's Makefile, or install-plugins.sh with its sudo / curl|sh paths). Replace with the one cwd-independent command `npm install -g ctx7` (what install-plugins.sh STEP 6 runs), and add on the next line, as text the user may run themselves: "version épinglée et find-docs : `make plugin` depuis le dépôt claude-config". The "yes install now" answer runs only `npm install -g ctx7`.
B1b. agents/plugin-advisor.md context7 WARN (~:281, ~:289 "Fix: `make plugin`"): same wording: fix = `npm install -g ctx7`; `make plugin` named only as "from the claude-config repo".

## MEDIUM — close in the same round
M1. lib/plugin-gate.md token check: a SET profile token is accepted only from the advisor's own set {web, seo, dev, design, qa, audit, minimal} (no `full`: target full is KEEP; no `max`: it turns higgsfield, extras and pr-review-toolkit on; no user-added profile from an advisor token). A profile outside that set is printed as rejected.
M2. lib/plugin-gate.md step 4: for a SET print both the `→ off` lines ("turns off") and the `→ on` lines ("turns on") of `profile.sh diff`.

## Citer left behind (verifier N1, BDR-100)
C2. skills/plugin-check/SKILL.md:14-17: "show the advisor's exact commands" → the main loop shows the commands it builds from the gate's step-5 templates (`set` / `enable` / `disable`, with `-C "<PROJECT_ROOT>"`), after the gate's token check; the user runs them. Only those lines.

## Advisor consistency (verifier N2)
N2. agents/plugin-advisor.md PHASE 2.5 (~:79-84): tiers decide tool depth only (ctx7, gstack-browser for browser-QA, gsd, graphify rule); they name no profile. Profile choice lives only in the WRITING table, signals only in the RULES (as :145 states). Remove "profile `minimal` (or `dev`…)" and "current profile" from the tiers; drop examples that contradict the WRITING table (site vitrine / landing page → web).

## Style (verifier N4)
S4. lib/tests/session-banner.test.sh:160 and :173 back under 80 chars (split the pattern string the way neighbouring checks do). USAGE.md:237 arrow aligned with its block; USAGE.md:419 the ui-ux-pro-max OPTIONAL on its own `→ OPTIONAL:` line. lib/plugin-gate.md:92 `<root>` → `<PROJECT_ROOT>`.

## Tests
T3. SB10: `gone skills/onboard/SKILL.md 'make plugin`? *\(installe'` = 1 (the old cwd-dependent install line gone); `has` lib/plugin-gate.md 'turns on' = 1; `gone lib/plugin-gate.md 'higgsfield,'`… keep existing; `has` lib/plugin-gate.md the accepted SET set line (e.g. 'web, seo, dev, design, qa, audit, minimal') = 1; `gone skills/plugin-check/SKILL.md "advisor's exact commands"` = 1. All lines ≤ 80 chars.
