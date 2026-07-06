---
name: onboard
description: 'Use when bringing an existing repo into the claude-config framework — needs archetype detection, config install, full multi-axis audit (debt/SEO/GEO/UI-UX/perf/security/a11y/docs), and prioritized backlog. Multi-agent orchestrator. Do NOT use for repos created via /init-project. Triggers: "onboard", "onboard project", "audit existing repo", "setup existing project".'
argument-hint: '[optional hints: "Python FastAPI" | "add gsd" | "Next.js monorepo" | "force-archetype:wordpress"]'
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent, Skill
---

# ORCHESTRATOR: ONBOARD

## REQUEST
$ARGUMENTS

---

## STEP 0 — PLUGIN CHECK + AUTO-ACTIVATE

Load `$HOME/.claude/agents/plugin-advisor.md` with hint "onboarding existing project + $ARGUMENTS".

- ACTION REQUIRED → show RECOMMENDATIONS block, offer: A) apply recos B) type "force". STOP.
- PROPOSED CHANGES exist → show list, ask "Apply? (yes / no / customize)". Apply on confirm.
- OK → `✅ Plugin check passed — [active plugins] — complexity: <score>%`, continue.

Complexity score is carried forward for STEP 4 graphify decision.

---

## STEP 1 — ARCHETYPE DETECTION

Load `$HOME/.claude/lib/archetype-detector.md`. Apply algorithm on current working directory.

**If user passed `force-archetype:<name>` in $ARGUMENTS** → skip detection, use that archetype, print `🎯 Archetype forcé : <name>`. Verify `~/.claude/lib/project-archetypes/<name>.md` exists, else STOP with error.

Otherwise:
- Scan filesystem for signals (respect counter-signals / exclusions).
- Score each archetype in `~/.claude/lib/project-archetypes/*.md` (hors `_TEMPLATE.md`).
- Apply selection rules from `archetype-detector.md`.

**Output format:**
```
ARCHETYPE DETECTION
Top scores:
  1. <name>  XX/YY (zz%) — strong:N, medium:N, weak:N  [SELECTED | AMBIGUOUS]
  2. ...

SELECTED: <name>  (confiance: HAUTE | MOYENNE | BASSE)
```

**Cases:**
- SELECTED HAUTE → continue STEP 2 avec l'archétype.
- SELECTED MOYENNE → afficher "⚠️ Confiance moyenne — confirmez ? (yes / switch to <runner-up> / describe manually)". STOP.
- AMBIGUOUS → présenter options A/B/C/D comme dans `archetype-detector.md`. STOP.
- UNKNOWN → présenter questions manuelles (type de projet, public/interne, DB, stack). STOP.

**Afficher les implications auto-appliquées** de l'archétype :
```
IMPLICATIONS (auto depuis archétype <name>):
  - public       : true | false
  - database     : required | optional | none
  - audit_stack  : [analyze, code-clean, seo, design-review, perf, cso, a11y, doc]
  - plugins      : context7=<y/n>, ui-ux-pro-max=<y/n>, gstack=<y/n>
```

**Si archétype a un bloc d'avertissement spécifique** (ex: react-spa en public → avertissement SEO) : **l'afficher en pleine largeur**, demander confirmation ou exploration migration. Stocker la réponse pour STEP 7.

---

## STEP 1b — MONOREPO GATE

Si filesystem scan détecte un monorepo (plugin-advisor signal OR `apps/`+`packages/`+workspace config) :
```
MONOREPO DETECTED
Packages found: [list]
Options:
  A) Onboard entire workspace (one CLAUDE.md at root)
  B) Onboard a specific package (cd into it)
  C) Onboard each package separately (sequential)
Choice? (A / B <name> / C)
```
STOP. La réponse détermine si STEP 1 tourne une fois (A) ou N fois (C) ou avec un PROJECT_ROOT différent (B).

---

## STEP 2 — BASELINE CONFIG (onboarder agent)

Load `$HOME/.claude/agents/onboarder.md`. Passer un BRIEF minimal issu du filesystem scan :
- `archetype` (depuis STEP 1)
- `project_name` (depuis package.json/pyproject.toml/README.md/dir name)
- `stack` (depuis manifests détectés)
- `purpose` (depuis README.md première section)
- `build_cmd`, `test_cmd`, `lint_cmd` (depuis package.json scripts / Makefile / README)
- Les champs manquants à ce stade restent `null` — STEP 3 les remplira via interview

L'agent génère :
- `CLAUDE.md` (brouillon — à raffiner après STEP 3)
- `.claude/settings.json`
- `.claudeignore`
- `.gitignore` (safety check)
- `.claude/tasks/TODO.md`, `.claude/memory/{decisions,learnings,blockers,journal,evals}.md`
- **Pas encore** `ROADMAP.md` (décision STEP 9)

Si `CLAUDE.md` existe déjà : lire son contenu, ne PAS écraser — fusionner après STEP 3.

---

## STEP 2.5 — ANIMATION LIB (propose, opt-in)
Vérifier si le stack peut consommer `motion` (ex-`framer-motion`, rebranded nov 2024)
et proposer l'install si absent. **Aucun install sans confirmation utilisateur** —
on ajoute une dep à un projet existant.

```bash
source "$HOME/.claude/lib/animation-lib-check.sh"
result=$(detect_anim_eligibility)
status=$(echo "$result" | cut -d'|' -f1)
pkg=$(echo "$result" | cut -d'|' -f2)
reason=$(echo "$result" | cut -d'|' -f3)
```

Cas :
- **`status=eligible` AND aucune lib anim détectée** → proposer :
  ```
  🎬 ANIMATION LIB
  Stack: <reason>. Aucune lib d'animation détectée.
  Install `<cmd>` ? (yes / skip)
  ```
  Sur `yes` → exécuter `recommend_anim_install_cmd "$pkg"` puis confirmer.
  Sur `skip` → continuer silencieusement.

- **`status=eligible` AND une lib anim déjà présente** (motion, framer-motion, gsap, lottie, react-spring, popmotion, auto-animate) → log info uniquement :
  ```
  🎬 Animation lib déjà présente : <lib> — pas d'action.
  ```

- **`status=no`** → skip silencieusement (raison loggée seulement en mode verbose).

---

## STEP 2.6 — GITFLOW INIT

Adopter le modèle gitflow sur ce repo existant :
```bash
bash "$HOME/.claude/lib/gitflow.sh" init
```
Sur un repo existant, cela : renomme `master`→`main` si besoin (LOCAL), crée
`develop` depuis main, réconcilie le socle `.gitignore` (additif — n'écrase
jamais les règles du projet), installe le hook pre-commit versionné, et fait UN
commit `chore: adopt gitflow socle + hook` sur main (pendant que le hook est
inactif → jamais auto-bloqué). Idempotent — un re-run est un no-op.

**Annoncer le renommage master→main** s'il a lieu. Le renommage est LOCAL ;
repointer la branche par défaut du remote vers `main` + la protection de branche
sur `main`/`develop` est une étape de migration séparée (sous-chantier B) — pas
faite ici. Pré-condition : working tree raisonnablement propre (le commit
d'adoption ne stage que `.gitignore` + `.githooks`).

---

## STEP 3 — DEEP INTERVIEW

L'orchestrateur pilote directement l'interview (l'agent `interviewer.md` est laissé pour `/init-project` où le BRIEF format est attendu ; ici on reste en markdown libre dans la CLAUDE.md).

Source des questions :
- **3a** — set minimum business (hardcodé ci-dessous, toujours posé sauf si déjà connu)
- **3b** — bloc `## Interview questions (adaptive)` du fichier `~/.claude/lib/project-archetypes/<name>.md`

### 3a — Set minimum business (toujours posé sauf si déjà trouvé dans README/CLAUDE.md existant)
1. Users cibles / persona principal ?
2. Stade projet ? (prototype / bêta / prod / maintenance)
3. Deadlines clés ? (MVP, release, audit externe)
4. Taille équipe + rôles ?
5. Contraintes légales ? (RGPD, RGAA a11y, HIPAA, autres)
6. Budget perfs ? (TTI cible, taille bundle, contraintes hébergement)

### 3b — Questions adaptatives par archétype
Charger le bloc `## Interview questions (adaptive)` depuis `~/.claude/lib/project-archetypes/<name>.md`. Poser uniquement ce qui n'est pas déjà connu.

### 3c — Filtrage
Ne pas redemander ce qui est déjà dans :
- README.md
- package.json / pyproject.toml / Cargo.toml
- Un CLAUDE.md existant
- Les réponses STEP 1 / 1b

Présenter toutes les questions en UN BLOC. Attendre les réponses. STOP.

Après réponses : **mettre à jour le brouillon CLAUDE.md** avec les infos obtenues.

---

## STEP 3.5 — CTX7 DOC AUDIT (avant graphify)

Vérifier que le projet a les docs de ses fast-libs accessibles.

```bash
command -v ctx7 &>/dev/null && ctx7 --version 2>/dev/null | head -1 || echo "ctx7-not-installed"
ls .ctx7-cache/ 2>/dev/null
```

### Détection fast-libs
Parse manifests selon l'archétype :
- **nextjs-app-router** → chercher : next, react, prisma, @supabase/*, drizzle-orm, next-auth, @clerk/*
- **react-spa** → chercher : react, @tanstack/*, zustand, jotai
- **rest-api-node** → chercher : fastify, @nestjs/*, prisma, drizzle-orm
- **rest-api-python** → chercher : fastapi, pydantic, sqlalchemy (si ≥ 2.0)
- **astro-static** → chercher : astro, @astrojs/*
- **wordpress / cli-tool / library / dotfiles-meta / static-html** → souvent aucune fast-lib, audit léger

### Vérification cache
Pour chaque fast-lib détectée :
1. Existe un fichier `.ctx7-cache/<lib>.md` ?
2. Fraîcheur < 7 jours ?

### Actions
- **ctx7 installé + fast-libs détectées + cache manquant/obsolète** → proposer :
  ```
  📚 DOC AUDIT ctx7
  Fast-libs détectées : [liste]
  Cache manquant/obsolète : [liste]

  Pré-fetcher les docs maintenant ? (yes / skip)
  ```
  Si yes :
  ```bash
  mkdir -p .ctx7-cache
  ctx7 docs /vercel/next.js "app router middleware routing" > .ctx7-cache/nextjs-core.md
  # ... pour chaque lib détectée
  ```
  Ajouter `.ctx7-cache/` au `.gitignore` si absent.

- **ctx7 non installé MAIS fast-libs détectées** → WARN :
  ```
  ⚠️  ctx7 non installé — risque de code utilisant des APIs obsolètes
     sur : [liste fast-libs]
     Install : `npm install -g ctx7 && ctx7 setup --claude`
     Ou continuer sans (non recommandé pour fast-libs).
  ```
  Demander : `yes install now / continue without / skip audit`.

- **Pas de fast-lib** → skip silencieusement.

---

## STEP 4 — GRAPHIFY (si complexity ≥ 30% et pas déjà présent)

```bash
command -v graphify &>/dev/null && echo "available" || echo "not-installed"
test -f graphify-out/GRAPH_REPORT.md && echo "graph-exists"
```

- **Pas installé** → skip avec message : `graphify non installé — skip audit architectural. Install : (voir graphify/SKILL.md)`
- **Complexity < 30%** → skip silencieusement, projet trop petit pour justifier.
- **Graphe déjà présent + récent** (fichier < 7j) → skip, réutiliser l'existant.
- **Sinon** → run :
  ```bash
  graphify . --output graphify-out 2>&1 | tail -20
  ```
  Puis `test -f graphify-out/GRAPH_REPORT.md` pour valider.

Print : `🔗 Knowledge graph : graphify-out/GRAPH_REPORT.md (N nodes, M edges)`.

---

## STEP 4.5 — AUDIT WORKSPACE + ARCHETYPE CONTEXT

Créer le dossier transitoire `.onboard-audit/` à la racine projet :

```bash
mkdir -p .onboard-audit
# Gitignore (ajout idempotent)
grep -q '^\.onboard-audit/' .gitignore 2>/dev/null || \
  printf '\n# onboard audit raw outputs (consumed by /onboard STEP 7)\n.onboard-audit/\n' >> .gitignore
```

Ce dossier contient les sorties brutes des audits (L3a+L3b). STEP 7 (L4) les synthétise vers `.claude/audits/` (rapports) et `.claude/tasks/` (backlog). Peut être supprimé après L4 sans perte.

### Injection contexte archétype

Extraire de `~/.claude/lib/project-archetypes/<archetype>.md` les blocs qui rendent les audits sécu/dette **vraiment contextuels** (pas de checklist web injectée sur du firmware). Écrire dans `.onboard-audit/archetype-context.md` :

```bash
ARCH_FILE="$HOME/.claude/lib/project-archetypes/<archetype>.md"
OUT=".onboard-audit/archetype-context.md"

{
  echo "# Archetype context — <archetype>"
  echo
  # Frontmatter: name, category, public, database
  echo "## Profile"
  awk '/^---$/{n++; next} n==1' "$ARCH_FILE" | grep -E '^(name|category|public|database):'
  echo
  # Section "## Implications" (contient "Surface sécurité")
  echo "## Implications"
  awk '/^## Implications/{p=1; next} p && /^## [A-Z]/{p=0} p' "$ARCH_FILE"
  echo
  # Section "## Typical pain points" (source vérité pour audits adaptatifs)
  echo "## Typical pain points"
  awk '/^## Typical pain points/{p=1; next} p && /^## [A-Z]/{p=0} p' "$ARCH_FILE"
} > "$OUT"
```

Ce fichier est lu par les prompts cso/analyze/code-clean pour cibler leurs checks sur les vulnérabilités **réellement applicables** à l'archétype (ex: buffer overflow + secure boot pour `firmware-embedded`, supply chain + export leakage pour `library`, XSS + CSRF pour `nextjs-app-router`).

---

## STEP 5 — ANALYZE (read-only, general)

Spawn un subagent analyzer (isolé, pas de partage de contexte) :

```
Agent(
  subagent_type="analyzer",
  description="Onboard — deep read-only analysis",
  prompt="""
  Read-only factual analysis of the project at <PROJECT_ROOT>.
  ARCHETYPE context: <archetype_name> — <category, public, database>.
  Focus areas (ordered) :
    1. Architecture risks (fragile couplings, missing abstractions, cycles)
    2. Dette technique visible (TODO/FIXME/HACK markers, commented code, god files)
    3. Patterns utilisés (bons et mauvais) — cite fichier:ligne
    4. Stale code suspects (last modified > 2 ans, no refs)
    5. Test coverage visible (quels modules testés, lesquels aveugles)
    6. Config drift (multiple configs pour même chose, values en dur)
  NO solutions. NO code changes. NO write outside the report.
  Write the report to `<PROJECT_ROOT>/.onboard-audit/analyze.md` with sections:
    ## Summary (3 bullet points)
    ## Architecture risks
    ## Dette technique
    ## Patterns (good + bad)
    ## Stale code suspects
    ## Test coverage blind spots
    ## Config drift
    ## Cross-references (vers graphify-out/GRAPH_REPORT.md si présent)
  Max 500 lignes. Priorise les éléments avec preuve concrète (fichier:ligne).
  """
)
```

Attendre la fin. Vérifier que `.onboard-audit/analyze.md` existe et est non vide.

---

## STEP 6 — AUDIT DISPATCH selon archétype

Lire le bloc `audit_stack:` du fichier `~/.claude/lib/project-archetypes/<archetype>.md`.

**Mapping audit_stack entry → action :**

| Entry | Action | Livraison |
|---|---|---|
| `analyze` | Déjà fait en STEP 5 | L3a |
| `code-clean` | Spawn subagent `code-cleaner` (audit-only) | L3a |
| `cso` | Si gstack ON → Skill(cso). Sinon → Agent general-purpose avec checklist OWASP + deps audit | L3a |
| `doc` | Spawn subagent `doc-syncer` (auto-mode OFF, report-only) | L3a |
| `seo` | Subagents seo-analyzer + geo-analyzer en parallèle | L3b |
| `design-review` | Si gstack ON → Skill design-review. Sinon → Agent ui-ux-pro-max context statique | L3b |
| `perf` | Si gstack ON + URL → Lighthouse. Sinon → static bundle audit | L3b |
| `a11y` | Si gstack ON + URL → axe-core. Sinon → Agent static a11y audit | L3b |

### STEP 6 dispatch (L3a portion)

Lancer EN PARALLÈLE (un seul message, plusieurs Agent calls) les audits correspondant aux entrées de `audit_stack:` qui sont en L3a (`code-clean`, `cso`, `doc`).

#### Dispatch code-cleaner (si `code-clean` dans audit_stack)
```
Agent(
  subagent_type="code-cleaner",
  description="Onboard — code-clean audit only",
  prompt="""
  AUDIT-ONLY mode — NO fixes, NO refactoring, NO file modifications.
  Target: <PROJECT_ROOT>. ARCHETYPE: <archetype>.
  Produce a report covering:
    1. Dead code (unused exports, unreachable branches, commented-out blocks)
    2. Style violations (per project linter config if present, else per global CLAUDE.md rules)
    3. Structural issues (god files, overly deep nesting, poor separation of concerns)
    4. Stale imports / unused deps (package.json vs actual imports, pyproject.toml vs imports)
    5. Duplicate code (copy-paste patterns)
    6. Outdated deps (if manifest present — list; do NOT run npm audit unless safe)
  Write the report to `<PROJECT_ROOT>/.onboard-audit/code-clean.md` with sections matching above.
  Each issue cite fichier:ligne. Prioritise par Sévérité (Critique/Haute/Moyenne/Basse).
  Max 500 lignes. Do NOT spawn sub-subagents (refactorer). Pure audit.
  """
)
```

#### Dispatch security — `cso` (si `cso` dans audit_stack)

**Décision selon plugin state :**
```bash
# gstack actif ?
bash $HOME/.claude/lib/toggle-external.sh list 2>/dev/null | grep -E "^gstack\s+(enabled|on)"
```

- **gstack ON** → invoquer le skill cso via Skill tool en lui passant le contexte archétype :
  ```
  Skill(skill="cso", args="comprehensive --report-only --output .onboard-audit/cso.md --archetype <archetype> --context-file .onboard-audit/archetype-context.md")
  ```
  Note : le skill cso écrit son rapport lui-même ; on redirige via `--output` si supporté, sinon on capture la sortie et on écrit `.onboard-audit/cso.md` dans le skill parent. Les flags `--archetype` / `--context-file` informent le skill même s'il ne les consomme pas nativement (lisibilité + compat future).

- **gstack OFF** → fallback via Agent general-purpose, prompt **archetype-adaptive** :
  ```
  Agent(
    subagent_type="general-purpose",
    description="Onboard — security audit fallback (archetype-adaptive)",
    prompt="""
    READ-ONLY security audit. No file modifications.
    Target: <PROJECT_ROOT>. ARCHETYPE: <archetype>. Category: <category>. Stack: <stack>.

    STEP 0 — Lire <PROJECT_ROOT>/.onboard-audit/archetype-context.md.
    Il contient : le profil de l'archétype (category, public, database), les "Implications" (dont
    "Surface sécurité"), et les "Typical pain points" applicables. **Tous les checks ci-dessous
    doivent être filtrés/priorisés selon ce contexte — ne pas chercher du XSS dans du firmware.**

    Checks UNIVERSELS (toujours, quel que soit l'archétype) :
      1. Secrets en repo : git grep -iE '(API_KEY|TOKEN|PASSWORD|SECRET|PRIVATE_KEY)\\s*=' -- ':!*.md'
      2. `.env` committé ? `.env.example` présent avec placeholders ?
      3. Dépendances avec failles connues (npm audit / pip-audit / cargo audit / govulncheck — non-destructif)
      4. Runtime obsolète (Node <20, Python <3.10, PHP <8.2, Go <1.21, Rust MSRV documenté ?)
      5. Présence d'un SECURITY.md (politique disclosure)
      6. Si Dockerfile : image de base pinnée (pas `latest`), user non-root, multi-stage ?

    Checks CONDITIONNELS (appliquer SI et seulement si la catégorie matche) :

    ─── category ∈ {framework, api, ecommerce, cms} (web surface) ───
      - SQL injection : chaînes concaténées dans queries (grep 'SELECT.*\\+', f-strings SQL, string interp)
      - XSS : dangerouslySetInnerHTML, v-html, innerHTML, `{{{...}}}`, template render non-échappé
      - AuthN/AuthZ : tokens en dur, JWT sans signature vérifiée, sessions sans flags Secure/HttpOnly/SameSite
      - CORS : `Access-Control-Allow-Origin: *` sur routes auth
      - CSP : présence d'un header / meta, pas de `unsafe-inline` / `unsafe-eval`
      - HTTPS : redirect http→https forcé, HSTS header, cookies avec flag Secure
      - CSRF : tokens anti-CSRF sur forms mutants (POST/PUT/DELETE)
      - Rate limiting sur endpoints sensibles (login, reset password, signup)
      - Path traversal : `../` non validé sur uploads / file serving

    ─── category == embedded (firmware / MCU) ───
      - Buffer overflows : `strcpy`, `strcat`, `sprintf`, `gets` sans bounds check
      - `malloc` dans ISR ou section critique
      - Stack size suffisant ? Watchdog activé ?
      - Secure Boot activé ? Firmware signing ?
      - OTA : signature vérifiée avant flash ?
      - JTAG / SWD fuses disable en prod ?
      - Debug logs (`printf` UART) actifs en release ?
      - Secrets / keys compilés en dur (extractibles par flash dump) ?
      - Flags compilateur : `-Wall -Wextra -Werror` + `-fstack-protector-strong` ?
      - Downgrade attacks : version min du firmware vérifiée avant OTA ?

    ─── category == library (package réutilisable) ───
      - Supply chain : deps transitives avec CVEs (audit strict)
      - Exports publics : leakage depuis internes (`export *` abusif, __init__.py qui ré-exporte tout) ?
      - Types lâches : `any` en TypeScript sur surface publique, `py.typed` manquant, `#[non_exhaustive]` oublié sur enums Rust publics
      - Semver : changelog cohérent ? Breaking changes documentés ?
      - SECURITY.md disclosure policy obligatoire

    ─── category == cli ───
      - Argument injection : `exec`/`spawn`/`subprocess` avec interpolation d'args user sans quoting
      - Path traversal : paths user-fournis sans normalisation
      - Privilèges : nécessite sudo/admin ? Scope minimal ?
      - Binaires deps (git, docker, ffmpeg) : version vérifiée avant exec ?
      - Signal handling : SIGINT → cleanup propre (pas de state corruption) ?

    ─── category == infra (terraform / docker-compose / k8s) ───
      - Credentials hardcodées dans `.tf`, `docker-compose.yml`, helm values
      - Terraform state committé (`terraform.tfstate`, `*.tfstate.backup`) ?
      - IAM policies avec wildcards (`"Action": "*"`, `"Resource": "*"`) ?
      - Secrets : secret manager (Vault/KMS/SSM) vs env var brute ?
      - Network : security groups / firewalls ouverts (0.0.0.0/0) ?

    ─── category == data-science (notebooks) ───
      - `.ipynb` committés avec outputs contenant creds DB ou PII
      - Datasets avec PII non anonymisées committés
      - Notebook en prod (`.ipynb` exécuté directement) vs extraction en module ?

    ─── category == desktop (Electron / Tauri) ───
      - `nodeIntegration: true` + `contextIsolation: false` = RCE via XSS renderer
      - `webSecurity: false` — ne jamais désactiver
      - IPC : channels non validés côté main
      - Auto-updater : signature vérifiée ?

    Pour chaque issue trouvée : fichier:ligne, sévérité (Critique/Haute/Moyenne/Basse), rattachement
    explicite au pain point de l'archétype si c'est un mapping direct.

    Write report to `<PROJECT_ROOT>/.onboard-audit/cso.md` avec :
      - En-tête : "ARCHETYPE-ADAPTIVE mode — checklist tuned for <archetype> (<category>). gstack cso skill not active."
      - Section "Universal" puis sections conditionnelles effectivement exécutées
      - Sections non applicables : ne PAS les inclure (pas de "N/A — skip")
    Max 600 lignes (plus large que default pour accommoder les checks archetype-spécifiques).
    """
  )
  ```

#### Dispatch semgrep SAST — `security-auditor` (TOUJOURS, complément de cso)

En complément de cso (ON) OU du fallback (OFF) — un moteur SAST déterministe
à côté de l'audit grep/raisonné. cso est un submodule gstack non modifiable ;
semgrep vit dans cet agent local. Lancé dans les DEUX branches gstack.

```
Agent(
  subagent_type="security-auditor",
  description="Onboard — semgrep SAST audit (report-only)",
  prompt="""
  MODE: audit
  SCOPE: <PROJECT_ROOT>
  REPORT: <PROJECT_ROOT>/.onboard-audit/semgrep.md
  CONTEXT: <PROJECT_ROOT>/.onboard-audit/archetype-context.md
  Follow agents/security-auditor.md exactly. Pinned rulesets only, no login.
  Write ONLY to the REPORT path. End stdout with REPORT_WRITTEN: <path>.
  """
)
```
Si semgrep absent → l'agent rend DEGRADED (checklist seule) + recommande
`make plugin` ; NON bloquant en onboard (audit, pas gate).

**Onboard n'a PAS de boucle verify→dev (`lib/verify-secure-loop.md`) — par
conception.** onboard produit un RAPPORT d'audit, pas une modification à
vérifier contre une demande : il n'y a ni contract de conformité, ni diff dev,
ni verifier, ni max-3. Le contract d'onboard est un contract de SCOPE (ce que
l'interview STEP 3 + `audit_stack` définissent comme périmètre d'audit), et
`security-auditor` tourne en `MODE: audit` (report-only), jamais en `MODE:
gate`. Ne PAS ajouter la boucle des flux dev ici par symétrie — l'audit et le
flux de dev sont deux formes distinctes ([[BDR-050]] pipeline dev ≠ audit).

#### Dispatch doc-syncer (si `doc` dans audit_stack)
```
Agent(
  subagent_type="doc-syncer",
  description="Onboard — doc drift audit only",
  prompt="""
  REPORT-ONLY mode — NO edits, NO auto-sync.
  Target: full project at <PROJECT_ROOT>.
  Scope:
    1. README drift (build/test commands, install steps, usage examples vs actual code)
    2. CLAUDE.md drift (stack versions, commands)
    3. CHANGELOG.md freshness (last entry vs last commit date)
    4. INSTALL/CONFIGURE/USAGE/CONTRIBUTING drift if present
    5. Feature delta (feature added in code but not documented, feature documented but removed)
    6. Inline comments (JSDoc/docstring/rustdoc/godoc) coverage for public API
  Cross-reference with git log last 6 months.
  Write report to `<PROJECT_ROOT>/.onboard-audit/doc.md` with sections above,
  each drift cite file:line + commit-hash + date.
  Max 500 lignes.
  """
)
```

### Après les 3 dispatches

Attendre la fin des subagents. Vérifier que les fichiers existent et sont non vides
(semgrep.md inclus — DEGRADED reste non vide : il porte le résultat checklist) :
```bash
for f in .onboard-audit/{code-clean,cso,semgrep,doc}.md; do
  [ -s "$f" ] && echo "OK $f" || echo "MISSING $f"
done
```

Si un subagent a échoué : afficher l'erreur, proposer à l'utilisateur :
```
⚠️  Audit <nom> a échoué : <erreur>
Options :
  A) Retry
  B) Skip et continuer (rapport partiel en L4)
  C) Abort onboard
```

### STEP 6 dispatch (L3b portion) — seo/geo + design + perf + a11y

Pré-check ressources navigateur :
```bash
# gstack actif ?
bash $HOME/.claude/lib/toggle-external.sh list 2>/dev/null | grep -E "^gstack\s+(enabled|on)"
# URL déployée fournie par l'utilisateur en STEP 3 ?
echo "${BRIEF_deployed_url:-none}"
# dev server launchable ?
grep -E '"(dev|start|serve)":' package.json 2>/dev/null | head -3
```

Lancer EN PARALLÈLE les audits présents dans `audit_stack:` de l'archétype (multiples Agent calls dans un seul message) :

#### Dispatch SEO+GEO (si `seo` dans audit_stack)

Le skill `/seo` appelle déjà seo-analyzer + geo-analyzer en parallèle, mais pour garder la cohérence "tout dans `.onboard-audit/`", on invoque les deux agents directement :

```
Agent(
  subagent_type="seo-analyzer",
  description="Onboard — SEO audit (classical engines)",
  prompt="""
  AUDIT-ONLY mode — NO edits, NO auto-fixes. Target: <PROJECT_ROOT>.
  Classical search engines: Google, Bing, DuckDuckGo.
  Archetype: <archetype>. Public: <true/false>. Deployed URL (si fournie): <url or none>.
  Coverage:
    - meta (title, description, OG, Twitter Card)
    - robots.txt, sitemap.xml, canonical, hreflang
    - JSON-LD / Schema.org classical
    - Core Web Vitals (estimé si pas d'URL live)
    - headings hierarchy, alt attrs, images formats
    - i18n / lang attribute
  Si URL live fournie AND gstack actif: utiliser les outils live.
  Sinon: audit statique sur le code (HTML templates, Astro pages, Next Metadata API, etc.).
  Write report to `<PROJECT_ROOT>/.onboard-audit/seo.md`.
  Structure sections par catégorie, chaque issue cite fichier:ligne + sévérité.
  Max 500 lignes.
  """
)

Agent(
  subagent_type="geo-analyzer",
  description="Onboard — GEO audit (AI engines)",
  prompt="""
  AUDIT-ONLY mode — NO edits, NO auto-fixes. Target: <PROJECT_ROOT>.
  AI search engines: ChatGPT, Perplexity, Claude, Gemini, Google AI Overviews, Copilot.
  Archetype: <archetype>. Public: <true/false>. Deployed URL: <url or none>.
  Coverage:
    - AI crawler directives in robots.txt (GPTBot, ClaudeBot, PerplexityBot, etc.)
    - llms.txt / llms-full.txt presence and quality
    - Schema.org types GEO-optimised (QAPage, Speakable, HowTo, Person+Article, Organization graph)
    - Entity SEO (Wikidata QID, sameAs, @id consistency, Knowledge Panel signals)
    - Content shape for LLM extraction (Definition Lead, TL;DR, Q→A structure, citable stats, freshness)
    - AI visibility monitoring recommendations
  Write report to `<PROJECT_ROOT>/.onboard-audit/geo.md`.
  Max 500 lignes. Cite fichier:ligne, sévérité.
  """
)
```

**SEO+GEO skip rules:**
- Si archetype.public == false ET `seo` dans audit_stack → ne devrait pas arriver, mais si oui : skip silencieusement, `.onboard-audit/seo.md` et `geo.md` non créés.
- Si projet a 0 contenu HTML/template (ex: React SPA public) → lancer quand même mais signaler en haut du rapport : "⚠️ SPA détectée — SEO intrinsèquement limité, voir archetype warning dans .onboard-audit/archetype-warnings.md".

#### Dispatch design-review (si `design-review` dans audit_stack)

**Cas gstack ON + URL live OU dev server launchable :**
```
Skill(
  skill="gstack:design-review",
  args="--url <url or http://localhost:PORT> --output .onboard-audit/design.md --audit-only"
)
```
Si le skill ne supporte pas `--output`, capturer la sortie et écrire à la main vers `.onboard-audit/design.md`.

**Cas gstack OFF OU pas de site déployable (ex: react-spa sans dev server):**
```
Agent(
  subagent_type="general-purpose",
  description="Onboard — static design review fallback",
  prompt="""
  AUDIT-ONLY mode — NO edits. Static design review du code UI.
  Target: <PROJECT_ROOT>. Archetype: <archetype>.
  Context: ui-ux-pro-max plugin state = <active/inactive>.
  Si ui-ux-pro-max actif : lire ses guidelines depuis les skills ui-ux-pro-max.
  Coverage (static, depuis code uniquement) :
    1. Design system (tokens : colors, spacing, radius, typography) — présent ou absent ?
       Cohérence : toutes les couleurs sont-elles dans les tokens ou hardcodées dans les composants ?
    2. Composants réutilisables vs duplication (Button en 5 variantes dispersées ?)
    3. Dark mode support ? Responsive (breakpoints) ? État de l'a11y dans les composants ?
    4. Animations (présence, durées < 300ms, ease-out par défaut — cf. emil-design-eng si actif)
    5. État vide / loading / error dans les composants
    6. Typography hiérarchie (combien de tailles différentes ? trop ?)
    7. Couleurs : contrastes ratio (AA minimum = 4.5:1 pour texte)
    8. Interactions : focus visible, hover states, disabled states
    9. Micro-interactions (billboard design ? transform scale(0.97) on :active ?)
  Write report to `<PROJECT_ROOT>/.onboard-audit/design.md`.
  Note en haut : "STATIC MODE — gstack inactif ou pas de dev server ; audit limité au code."
  Max 500 lignes. Cite fichier:ligne.
  """
)
```

**Skip rules:**
- Si `design-review` pas dans audit_stack (backend, CLI, lib) → skip silencieusement.
- Si archetype frontend mais pas de composants détectés (tout HTML pur) → noter "pure HTML — design review réduit aux sections 3-8".

#### Dispatch perf (si `perf` dans audit_stack)

**Cas gstack ON + URL live :**
```
Skill(
  skill="gstack:browse",
  args="--lighthouse --url <url or http://localhost:PORT> --output .onboard-audit/perf-lighthouse.json"
)
```
Puis parser le JSON Lighthouse (scores perf/a11y/bp/seo/pwa + top opportunities) → écrire `.onboard-audit/perf.md`.

**Cas gstack OFF OU pas d'URL :**
```
Agent(
  subagent_type="general-purpose",
  description="Onboard — static perf audit",
  prompt="""
  AUDIT-ONLY mode — NO edits.
  Target: <PROJECT_ROOT>. Archetype: <archetype>.
  Static perf audit (pas de browser) :
    1. Bundle analyzers config présent ?
       - Next: `@next/bundle-analyzer` dans deps ?
       - Vite: `rollup-plugin-visualizer` ?
       - Webpack: `webpack-bundle-analyzer` ?
       Si NON, recommander l'install + usage.
       Si OUI et script existe, tenter execution NON-DESTRUCTIVE si safe (produit un HTML/rapport, pas de modif code).
    2. Dependencies taille — identifier les grosses deps (> 100kb) depuis package-lock.json / pnpm-lock.yaml.
    3. Images dans `public/` ou `assets/` : compter non-optimisées (PNG/JPG > 200kb sans WebP/AVIF variant).
    4. Polices web : Google Fonts via <link> (blocking) vs self-hosted ? font-display: swap ?
    5. Code splitting : dynamic imports () présents ? Chaque route a son chunk ?
    6. Lazy loading : `loading="lazy"` sur les <img> ? IntersectionObserver pour composants lourds ?
    7. React-specific: React.memo / useMemo / useCallback overuse ou sous-utilisé ?
    8. CSS: quantité totale, CSS-in-JS runtime cost, unused CSS ?
    9. SSR/SSG/ISR strategy (si Next/Astro) — cohérente avec le contenu ?
    10. Core Web Vitals estimés à partir du code (TTFB impossible, mais LCP/CLS inférables).
  Write report to `<PROJECT_ROOT>/.onboard-audit/perf.md`.
  Note "STATIC MODE" si sans browser.
  Max 500 lignes.
  """
)
```

#### Dispatch a11y (si `a11y` dans audit_stack)

**Cas gstack ON + URL live :**
```
Skill(
  skill="gstack:browse",
  args="--axe --url <url> --output .onboard-audit/a11y-axe.json"
)
```
Parser axe-core résultats (violations, incomplete, inapplicable, passes) → `.onboard-audit/a11y.md`.

**Cas statique :**
```
Agent(
  subagent_type="general-purpose",
  description="Onboard — static a11y audit",
  prompt="""
  AUDIT-ONLY mode — NO edits.
  Target: <PROJECT_ROOT>. Archetype: <archetype>.
  Static a11y audit (WCAG 2.1 AA + RGAA 4.1 France) :
    1. <html lang="…"> présent sur toutes les pages ?
    2. Landmarks (header/nav/main/footer/aside) utilisés ou encore div-soup ?
    3. Heading hierarchy (h1 unique, pas de saut h1→h3) — scanner tous les templates.
    4. Images : <img> ont tous un alt ? alt décoratif = "" ? alt redondant avec caption ?
    5. Formulaires : chaque <input> a un <label>, aria-label, ou aria-labelledby ?
    6. Boutons vs liens : <a> sans href, <div onClick>, <span role="button"> → red flags.
    7. Focus visible : outline:none sans :focus-visible alternative ? tabindex="-1" abusif ?
    8. Couleurs : contrastes (peut se vérifier depuis tokens si présents).
    9. Animations : prefers-reduced-motion respecté ?
    10. ARIA : live regions pour toasts/notifs, role="dialog" pour modals avec focus trap ?
    11. Keyboard : navigation sans souris possible sur features critiques (depuis revue statique event handlers) ?
    12. Screen reader affordances : visually-hidden class, aria-describedby ?
  Contexte France : RGAA 4.1 critères applicables + déclaration d'accessibilité obligatoire (sites publics > seuils).
  Write report to `<PROJECT_ROOT>/.onboard-audit/a11y.md`.
  Note "STATIC MODE" si pas d'axe-core.
  Max 500 lignes. Cite fichier:ligne.
  """
)
```

### Après tous les dispatches L3b

Vérification :
```bash
for f in .onboard-audit/{seo,geo,design,perf,a11y}.md; do
  [ -f "$f" ] && echo "OK $f ($(wc -l < "$f") lignes)" || echo "— $f (skipped, archétype n'a pas cet audit)"
done
```

---

## STEP 7 — SYNTHÈSE dans `.claude/audits/`

À partir des rapports bruts dans `.onboard-audit/`, générer 4 fichiers structurés dans `.claude/audits/`.

Spawn un subagent synthétiseur (isolé, chargé uniquement du contenu de `.onboard-audit/`) :

```
Agent(
  subagent_type="general-purpose",
  description="Onboard — synthèse vers .claude/audits/",
  prompt="""
  Lire tous les fichiers de <PROJECT_ROOT>/.onboard-audit/ :
    - analyze.md, code-clean.md, cso.md, doc.md (toujours)
    - seo.md, geo.md, design.md, perf.md, a11y.md (si présents)
  Contexte : archetype=<archetype>, public=<bool>, stack=<stack>, brief_interview=<summary>.

  Produire 4 fichiers dans <PROJECT_ROOT>/.claude/audits/ :

  ═══ 1. .claude/audits/ONBOARD_REPORT.md — synthèse exécutive ═══
  Structure :
    # Onboard Report — <project_name>
    ## Profile
      - Archétype: <name> (<category>)
      - Stack: <lang+framework+db+hosting>
      - Public: <yes/no>
      - Taille: <lines of code / files count>
    ## Scores par domaine (0-100, calculés depuis le nombre d'issues par sévérité)
      | Domaine         | Score | Forces majeures | Problèmes majeurs |
      | analyze (dette) | 72    | bonne séparation MVC | god file src/foo.js |
      | code-clean      | ...   |
      | cso (sécu)      | ...
      | doc             | ...
      | seo (si public) | ...
      | geo (si public) | ...
      | design          | ...
      | perf            | ...
      | a11y            | ...
    ## Top 5 priorités (choisies depuis .claude/audits/AUDIT_ISSUES.md par score sévérité × impact projet)
      1. [P0 Critique] <titre> — <domaine> — <impact en 1 phrase>
      2. ...
    ## Prochaines étapes (pointeurs vers les 3 autres fichiers)

  ═══ 2. .claude/audits/AUDIT_GOOD.md — ce qui va ═══
  Inventaire positif par domaine. Ce qu'il faut PROTÉGER en modifiant le reste.
  Structure:
    # Audit — Ce qui va
    ## Dette technique
      - <pattern sain repéré> (ex: "services layer bien isolé de l'API")
    ## Sécurité
      - <forces>
    ## [domaine par domaine]

  ═══ 3. .claude/audits/AUDIT_ISSUES.md — ce qui ne va pas ═══
  Listing par sévérité descendante (Critique → Basse).
  Structure:
    # Audit — Ce qui ne va pas
    ## Critique
      ### [domaine] <titre>
      - Fichier(s): path:line
      - Preuve: <extrait ou description concrète>
      - Impact: <une phrase>
      - Référence: .onboard-audit/<source>.md
    ## Haute
    ## Moyenne
    ## Basse
  Ne pas inventer, ne citer QUE ce qui est dans .onboard-audit/.

  ═══ 4. .claude/audits/AUDIT_PROPOSALS.md — propositions ═══
  Pour CHAQUE issue Critique et Haute du fichier ISSUES : proposer au minimum 2 options,
  avec tradeoffs. Pour les issues Moyennes : 1 option suffit.
  Structure:
    # Audit — Propositions d'amélioration
    ## [P0 Critique] <titre issue>
      Contexte: <rappel court>
      Option A — <titre> :
        - Approche: <1-3 phrases>
        - Coût: <estimation S/M/L>
        - Risque: <faible/moyen/élevé>
        - Gain: <phrase>
      Option B — <titre> :
        ...
      Option C (optionnel) :
        ...
      **Recommandation**: Option <X> — <justification 1-2 phrases>
    ## [P1 Haute] ...
    ## [P2 Moyenne] ...

  Règles de qualité :
    - Chaque fichier max 800 lignes (split si dépasse, jamais tronquer le contenu crucial)
    - Citer TOUTES les sources .onboard-audit/ utilisées (preuve traçable)
    - Pas de conseil générique — toujours relier à une preuve concrète
    - Radical honesty : si un audit révèle une faille structurelle majeure (ex: SPA public),
      le dire clairement en P0 Critique, ne pas édulcorer
  """
)
```

Vérifier que les 4 fichiers `.claude/audits/ONBOARD_REPORT.md`, `.claude/audits/AUDIT_GOOD.md`, `.claude/audits/AUDIT_ISSUES.md`, `.claude/audits/AUDIT_PROPOSALS.md` existent et sont non vides.

---

## STEP 8 — VALIDATION GATE ★ MANDATORY STOP

Afficher à l'utilisateur :

```
═══ ONBOARD — RAPPORT PRÊT ═══

Archétype: <name>
Stack: <stack>
Scores: dette:<X> · sécu:<X> · doc:<X>  [· seo:<X> · geo:<X> · design:<X> · perf:<X> · a11y:<X>]

📂 Fichiers produits dans .claude/audits/ :
  - ONBOARD_REPORT.md    (synthèse exécutive)
  - AUDIT_GOOD.md        (ce qui va)
  - AUDIT_ISSUES.md      (ce qui ne va pas, par sévérité)
  - AUDIT_PROPOSALS.md   (propositions avec options + tradeoffs)

TOP 5 PRIORITÉS :
  1. [P0 Critique] <titre>
  2. [P0 Critique] <titre>
  3. [P1 Haute]    <titre>
  4. [P1 Haute]    <titre>
  5. [P2 Moyenne]  <titre>

Prochaine étape : générer .claude/tasks/TODO.md depuis .claude/audits/AUDIT_PROPOSALS.md approuvé.

Options :
  A) Lire d'abord les 4 fichiers, je reviens te le dire (STOP)
  B) Tout est OK, génère .claude/tasks/TODO.md depuis toutes les propositions recommandées
  C) Je veux éditer .claude/audits/AUDIT_PROPOSALS.md avant de générer .claude/tasks/TODO.md (indiquer ce à changer)
  D) Réduire le scope — ne garder que P0 Critique dans .claude/tasks/TODO.md
  E) Abort — je n'utilise pas le backlog auto

Choix ? (A / B / C / D / E)
```

**STOP.** Attendre la réponse.

- **A** → stop ici, l'utilisateur relira et reviendra avec `/onboard continue`.
- **B** → continuer STEP 9 avec toutes les recommandations.
- **C** → demander les changements spécifiques, les appliquer dans .claude/audits/AUDIT_PROPOSALS.md, puis re-présenter la gate.
- **D** → continuer STEP 9 avec seulement les P0.
- **E** → arrêter sans générer .claude/tasks/TODO.md, print "Onboard rapport figé dans .claude/audits/ — tu peux t'en servir à la main ensuite."

---

## STEP 9 — BACKLOG → .claude/tasks/TODO.md

Lire `.claude/audits/AUDIT_PROPOSALS.md` (avec les "Recommandations" sélectionnées par l'utilisateur). Pour chaque proposition recommandée, générer une entrée dans `.claude/tasks/TODO.md` :

Format :
```
# TODO — onboard backlog (<date>)

<!-- Généré par /onboard — une entrée par proposition approuvée.
     Format: - [ ] [Priorité] [/skill] — description — fichiers estimés -->

## P0 — Critique
- [ ] [P0] [/hotfix] — <titre>
      Fichiers: <paths>
      Source: .claude/audits/AUDIT_PROPOSALS.md § "<titre>"
      Option recommandée: <A/B/C>
- [ ] [P0] [/bugfix] — <titre>
      Fichiers: ...

## P1 — Haute
- [ ] [P1] [/feat] — <titre>
- [ ] [P1] [/ship-feature] — <titre>

## P2 — Moyenne
- [ ] [P2] [/code-clean] — <titre>
- [ ] [P2] [/refactor] — <titre>

## P3 — Basse
- [ ] [P3] [...] — ...

## Post-MVP (non-priorisé, backlog)
- [ ] ...
```

**Règles de sélection du skill recommandé :**

| Type de proposition | Skill |
|---|---|
| Typo, CSS, config, import manquant (1-2 fichiers, cause évidente) | `/hotfix` |
| Bug avec investigation (plusieurs fichiers) | `/bugfix` |
| Petite feature (1-5 fichiers) | `/feat` |
| Grosse feature (design, multi-fichiers, architecture) | `/ship-feature` |
| Dette technique (dead code, style, dupes) | `/code-clean` |
| Refactoring sans changement de comportement | `/refactor` |
| Audit SEO/GEO à re-lancer après corrections | `/seo` ou `/geo` |
| Audit docs à re-sync après changement | `/doc` |

Ne PAS écraser `.claude/tasks/TODO.md` s'il contient déjà du contenu utilisateur : append avec un séparateur :
```
<contenu existant>

---
# Onboard backlog (généré le YYYY-MM-DD)

<nouveau contenu>
```

Print :
```
✅ .claude/tasks/TODO.md mis à jour — <N> tâches ajoutées (<P0>/<P1>/<P2>/<P3>)
Pour démarrer : lire .claude/tasks/TODO.md, choisir une tâche P0, lancer le /skill indiqué.
```

---

---

## RULES
- NO skipping STEP 0, 1, 2 — ils sont obligatoires.
- NO audit agressif : chaque subagent doit recevoir "AUDIT-ONLY, no file modifications".
- STEP 1 doit proposer un override `force-archetype:<name>` si l'utilisateur sait déjà.
- Monorepo : toujours demander le mode (A/B/C) avant STEP 2.
- Si `CLAUDE.md` existe : le lire, ne pas l'écraser sans fusion après STEP 3.
- STEP 3 : ne redemande jamais ce qui est déjà dans README ou manifests.
- STEP 3.5 : si ctx7 absent + fast-libs, WARN mais ne bloque pas.
- STEP 4 : skip si complexity < 30% ou graph récent déjà présent.
- STEP 5-6 : subagents isolés (Agent tool avec subagent_type spécifique) — pas de contexte partagé entre les audits. Chaque subagent écrit son rapport dans `.onboard-audit/<name>.md`.
- STEP 6 dispatches parallélisables : regrouper dans un seul message Agent multi-calls.
- `.onboard-audit/` gitignoré automatiquement — ne jamais commiter.
- Si un subagent échoue : proposer retry/skip/abort, ne pas auto-retry silencieusement.

---

## FINAL OUTPUT
```
ONBOARD COMPLETE: <project name>
ARCHETYPE    : <name> (confiance: <niveau>)
STACK        : <stack>
CONFIG       : ✅ CLAUDE.md, settings.json, .claudeignore, .claude/{tasks,memory,audits}/
CTX7 CACHE   : ✅ [libs] | ⚠️ not installed | — N/A
GRAPHIFY     : ✅ graphify-out/ | ⚠️ not installed | — skipped (simple)
AUDITS       :
  ✅ dette technique     (.onboard-audit/analyze.md + code-clean.md)
  ✅ sécurité            (.onboard-audit/cso.md)
  ✅ docs drift          (.onboard-audit/doc.md)
  ✅ SEO + GEO           (.onboard-audit/seo.md + geo.md)       [si public]
  ✅ design UI/UX        (.onboard-audit/design.md)              [si frontend]
  ✅ performance         (.onboard-audit/perf.md)
  ✅ accessibilité       (.onboard-audit/a11y.md)                [si frontend]

SYNTHÈSE     :
  ✅ .claude/audits/ONBOARD_REPORT.md       (exécutif)
  ✅ .claude/audits/AUDIT_GOOD.md
  ✅ .claude/audits/AUDIT_ISSUES.md         (par sévérité)
  ✅ .claude/audits/AUDIT_PROPOSALS.md      (options + tradeoffs)
  ✅ .claude/tasks/TODO.md                  (backlog priorisé avec skill recommandé)

NEXT STEPS   :
  1. Ouvrir .claude/audits/ONBOARD_REPORT.md — overview complète
  2. Démarrer par la première tâche P0 de .claude/tasks/TODO.md avec le skill indiqué
  3. /onboard add gsd — générer ROADMAP.md pour multi-session si besoin
  4. .onboard-audit/ peut être supprimé (raw data consommée en synthèse)
```
