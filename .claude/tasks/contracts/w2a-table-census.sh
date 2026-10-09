#!/usr/bin/env bash
# GATE 0 oracle, contract 2026-10-09-model-router-w2a: DEFAULT_CONFIG.skills
# and .agents in register.ts hold exactly the plan's phase rows (plan
# 2026-10-09-model-router-w2 § Row tables), every value a declared phase.
# Prints W2A-TABLE-COMPLETE only when every assertion passes.
set -u
F="${1:?register.ts path}"
python3 - "$F" <<'PY'
import re, sys
src = open(sys.argv[1]).read()
m = re.search(r'const DEFAULT_CONFIG: Config = \{(.*?)\n\}\n', src, re.S)
if not m: print("no DEFAULT_CONFIG block"); sys.exit(1)
cfg = m.group(1)
def block(name):
    b = re.search(r'\n  ' + name + r': \{([^\n]*)\},', cfg) \
        or re.search(r'\n  ' + name + r': \{(.*?)\n  \}', cfg, re.S)
    if not b: print(f"no {name} block"); sys.exit(1)
    rows = re.findall(r"(?:^|[{,])\s*'?([A-Za-z0-9_-]+)'?:\s*'([a-z]+)'", b.group(1), re.M)
    return dict(rows)
phases = set(
    re.findall(r"^\s*([a-z]+): \{ tier:", re.search(r'\n  phases: \{(.*?)\n  \}', cfg, re.S).group(1), re.M))
want_skills = {}
for ph, names in {
 'plan': 'ship-feature init-project onboard tour audit-delta analyze code-clean client-handover brainstorming writing-plans requesting-code-review 21st-ui-review',
 'reflect': 'feat hotfix bugfix refactor web-validate harden seo geo site-motion frontend-design emil-design-eng design-motion-principles 21st-ui-build scroll-world-storytelling build-threejs-scroll-worlds scroll-scrubbed-visual-sequence scroll-scrubbed-word-reveal scroll-progress-timeline subagent-driven-development writing-skills deprecation-and-migration 21st-ai 21st-ui-explore',
 'implement': 'gitflow prune-memory pdf-translate ci-cd-and-automation observability-and-instrumentation test-driven-development',
 'apply': 'commit-change release-candidate doc capitalize close reconcile deploy',
 'mechanical': 'status profile plugin-check skills-perso using-git-worktrees 21st-cli-use 21st-registry 21st-design-sync',
}.items():
    for n in names.split(): want_skills[n] = ph
want_agents = {'Explore': 'explore', 'Plan': 'judge'}
for ph, names in {
 'implement': 'feater bugfixer code-cleaner scaffolder onboarder',
 'write': 'commit-changer doc-syncer handover-doc-writer refactorer',
 'apply': 'hotfixer release-executor plugin-probe validator-analyzer',
 'verify': 'verifier security-auditor',
 'judge': 'plan-challenger plugin-advisor seo-analyzer geo-analyzer analyzer',
 'mechanical': 'status-reporter',
}.items():
    for n in names.split(): want_agents[n] = ph
ok = True
for name, want in (('skills', want_skills), ('agents', want_agents)):
    got = block(name)
    for k in sorted(set(want) | set(got)):
        if want.get(k) != got.get(k):
            ok = False; print(f"{name}.{k}: want {want.get(k)} got {got.get(k)}")
    bad = {k: v for k, v in got.items() if v not in phases}
    if bad: ok = False; print(f"{name}: undeclared phases {bad}")
if len(want_skills) != 56 or len(want_agents) != 23:
    ok = False; print(f"oracle self-check: {len(want_skills)} skill rows, {len(want_agents)} agent rows")
if 'Built-ins only' in cfg: ok = False; print("stale comment 'Built-ins only'")
ph = re.search(r'\n  phases: \{(.*?)\n  \}', cfg, re.S).group(1)
for want in ("write: { tier: 'work', effort: 'high' }", "apply: { tier: 'work', effort: 'low' }"):
    if want not in ph: ok = False; print(f"phases: missing {want}")
print("W2A-TABLE-COMPLETE" if ok else "W2A-TABLE-INCOMPLETE"); sys.exit(0 if ok else 1)
PY
