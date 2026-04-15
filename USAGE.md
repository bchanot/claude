# claude-config — Guide d'utilisation et cas d'usage

Ce fichier complète le README. Il documente les bonnes pratiques, les workflows typiques, et des exemples concrets pour plusieurs types de projets.

---

## Principes fondamentaux

**Tu décris, le pipeline exécute.** Le système prend en charge : l'architecture, le scaffolding, la décomposition en tâches, l'implémentation TDD, le code review, et la synchronisation du README. Tu n'interviens qu'aux deux gates de validation.

**Prompt détaillé = moins de friction.** L'interviewer (STEP 1) skip les questions si ton prompt contient déjà : nom, purpose, stack, features v1, conventions. Un prompt de 10 lignes structuré évite toute interruption.

**Plugin-check avant tout.** Soit via `/plugin-check "description"` (explicite), soit via STEP 0 de `/init-project` ou `/ship-feature` (automatique). Les plugins mal configurés dégradent silencieusement la qualité du résultat.

---

## Quel skill utiliser ?

Arbre de décision rapide face à une situation donnée :

```
Tu veux...
│
├─ Créer un nouveau projet from scratch ?
│    → /init-project "description"
│
├─ Intégrer un projet existant dans claude-config ?
│    → /onboard
│
├─ Ajouter une feature à un projet existant ?
│    ├─ Feature complète (multi-fichiers, orchestration) ?
│    │    → /ship-feature "description"
│    └─ Petite feature (1-5 fichiers, rapide) ?
│         → /feat "description"
│
├─ Corriger un bug ?
│    ├─ Bug superficiel (typo, CSS, config, max 2 fichiers) ?
│    │    → /hotfix "description"
│    └─ Bug complexe (investigation root cause nécessaire) ?
│         → /bugfix "description"
│
├─ Reprendre après une pause / orienter la session ?
│    → /status
│
├─ Comprendre du code avant de le modifier ?
│    → /analyze src/fichier.py
│    → (mode DEBUG si tu passes une erreur/stack trace)
│
├─ Améliorer la qualité sans changer le comportement ?
│    ├─ Refactoring ciblé (un fichier/module) ?
│    │    → /refactor src/module.py
│    │    ⚠️  Pour un refactoring profond (module entier) :
│    │       /analyze src/module/   ← rapport de violations d'abord
│    │       /refactor src/module/  ← corrections sur rapport
│    │       /analyze src/module/   ← vérification après (cycle complet)
│    └─ Dead code, violations de style (codebase-wide) ?
│         → /code-clean
│
├─ Docs périmées / vérifier la sync code↔docs ?
│    → /doc                    ← audit complet tous les fichiers .md
│
├─ Optimiser le SEO/GEO ?
│    → /seo
│
├─ Vérifier si les plugins sont bien configurés ?
│    → /plugin-check "description du projet"
│    → (aussi fait automatiquement en STEP 0 de /init-project et /ship-feature)
│
├─ Session GSD v2 active/interrompue ?
│    → dans le terminal: gsd → /gsd auto  (reprend depuis .gsd/)
│    → modifier le plan en cours: /gsd steer ou /gsd discuss
│    → voir la progression: /gsd status
│    → un step a échoué: /gsd forensics  (debug autonome)
│
└─ Quelque chose ne marche pas ?
     → /health    ← diagnostic complet (symlinks, plugins, permissions, token budget)
```

### Règle de décision simplifiée

| Situation | Skill recommandé |
|---|---|
| Tout nouveau | `/init-project` |
| Code existant sans config | `/onboard` |
| Feature complète | `/ship-feature` |
| Petite feature (1-5 fichiers) | `/feat` |
| Bug superficiel (typo, CSS) | `/hotfix` |
| Bug complexe (root cause) | `/bugfix` |
| Reprise de session | `/status` |
| Debug / comprendre | `/analyze` |
| Nettoyage code ciblé | `/refactor` |
| Dead code / style codebase | `/code-clean` |
| Docs périmées | `/doc` |
| SEO/GEO audit | `/seo` |
| Commit structuré | `/commit-change` |
| Navigation codebase large | `/graphify` |
| Lister ses skills | `/skills-perso` |
| Plugins OK ? | `/plugin-check` |
| Rien ne marche | `/health` |

---

## Les commandes et quand les utiliser

| Commande | Quand | Notes |
|---|---|---|
| `/init-project` | Nouveau projet from scratch | 12-13 steps, deux gates obligatoires |
| `/ship-feature` | Feature sur projet existant | 8 steps, une gate |
| `/feat` | Petite feature (1-5 fichiers) | Léger, pas d'orchestration lourde |
| `/bugfix` | Bug avec investigation root cause | Hypothèses, diagnostic, fix minimal |
| `/hotfix` | Bug superficiel (typo, CSS, config) | Max 2 fichiers, cause évidente |
| `/onboard` | Projet existant non géré par ce config | Génère CLAUDE.md + settings |
| `/plugin-check` | Avant de démarrer tout travail | Aussi embarqué en STEP 0 des orchestrateurs |
| `/analyze` | Comprendre du code avant de le modifier | Read-only, aucune solution proposée |
| `/analyze` + erreur | Diagnostiquer un test/build qui échoue | Mode DEBUG : hypothèses ordonnées |
| `/refactor` | Améliorer un fichier sans changer le comportement | Rapport de violations d'abord, modif ensuite |
| `/code-clean` | Dead code, violations de style | Audit + rapport, fixes après approbation |
| `/doc` | Docs périmées après des changements | Audit drift code↔docs, patch chirurgical |
| `/seo` | Audit SEO/GEO complet | Détecte framework, audite meta/OG/sitemap |
| `/commit-change` | Commits bien structurés | Groupe les changements par unité logique |
| `/graphify` | Navigation codebase large-scope | Knowledge graph, pour tâches multi-fichiers |
| `/skills-perso` | Lister ses skills personnels | Skills créés dans ~/.claude/skills/ |
| `/health` | Quand quelque chose ne fonctionne pas | Lance doctor.sh |
| `/status` | Reprendre après une pause | Snapshot : plugins, git, GSD milestone |

---

## Les plugins — décision rapide

```
Toujours actifs (0 token) : security-guidance, rtk

Projet avec interface     → frontend-design ON
Design élaboré/system     → ui-ux-pro-max ON
Deploy + QA browser       → gstack ON
Next.js/React/Prisma      → context7 ON (WARN si absent, pas BLOCK)
Multi-session (>1 jour)   → gsd v2 CLI (gsd dans terminal)
Swarm 5+ agents parallèles → ruflo ON

Backend/CLI seulement     → tout OFF sauf superpowers
Hotfix/quick fix          → tout OFF sauf superpowers
```

**GSD v2** n'est pas un plugin Claude Code — c'est un CLI externe. Il ne consomme pas de tokens passifs. Tu le lances dans un terminal séparé avec `gsd`, puis `/gsd auto` pour le mode autonome.

---

## Patterns de workflow

> **Budget Pro (~11k tokens/5h) :** un `/init-project` complet consomme 3000-5000t — laissant 6000-8000t pour les steps suivants. Adapter le choix de plugins actifs en conséquence. Les tokens sont indiqués à titre indicatif — varient selon la taille du projet et les plugins actifs.

### Pattern A — Nouveau projet court (≤1 session) · ~3000-5000t

```
# 1. Configurer les plugins
/plugin-check "description de ton projet"
# → Activer les plugins recommandés, puis :

# 2. Créer le projet
/init-project "description complète"
# → STEP 0  : vérifie les plugins automatiquement
# → STEP 1  : interview (skip si prompt complet)
# → STEP 4  : ★ GATE — valider l'architecture
# → STEP 7  : ★ GATE — valider le plan d'implémentation
# → STEP 8-11: implémentation TDD + review + finish
# → STEP 12 : sync README
# → STEP 13 : propose GSD v2 si multi-session détecté

# 3. Features suivantes
/ship-feature "description de la feature"
```

### Pattern B — Projet long (multi-session, plusieurs jours) · ~1500-2500t/session CC

```
# Même départ que Pattern A, mais au STEP 13 :
# → Répondre "yes" à "Initialize GSD v2?"
# → ROADMAP.md est créé avec les milestones

# À chaque reprise de session (dans Claude Code) :
/status              # snapshot : plugins + git + milestone GSD en cours

# Ensuite dans un terminal (depuis le dossier projet) :
gsd                  # démarrer une session
/gsd init            # si pas encore fait
/gsd auto            # mode autonome, walk away

# Pour suivre :
/gsd status          # dashboard progression + coût

# Pour orienter en cours de route :
/gsd discuss         # décisions d'architecture
/gsd steer           # modifier le plan en cours d'exécution

# Crash/interruption → reprendre :
gsd                  # relancer
/gsd auto            # reprend depuis l'état sauvegardé dans .gsd/
```

### Pattern C — Projet existant (onboarding) · ~500-1000t (onboard) + normal ensuite

```
cd mon-projet-existant/

# Dans Claude Code :
/onboard
# → Scanne le projet (stack, structure, commandes, deps)
# → Pose seulement les questions manquantes
# → Génère CLAUDE.md, .claude/settings.json, .claudeignore
# → Option : ROADMAP.md pour GSD v2

/status              # confirmer que l'onboarding est complet + vue d'ensemble

# Configurer les plugins pour ce projet
/plugin-check "type du projet"

# Reprendre le développement normalement
/ship-feature "prochaine feature"
```

### Pattern D — Hotfix / bugfix · ~200-800t

```
# Bug superficiel (typo, CSS, config, max 2 fichiers, cause évidente) :
/hotfix "le bouton submit est invisible sur mobile"    # ~200t

# Bug complexe (investigation root cause nécessaire) :
/bugfix "les notifications ne partent plus depuis mardi"   # ~500-800t
```

### Pattern E — Debug d'erreur de build/test · ~600-900t

```
# Copier le message d'erreur complet, puis :
/analyze "FAILED tests/test_api.py::test_create — AssertionError: 422 != 201"
# → Mode DEBUG automatique
# → Hypothèses ordonnées par probabilité
# → Fichiers à vérifier
# → Ce qu'il ne faut pas toucher

# Puis si fix nécessaire :
/ship-feature "corriger le test_create_order — cause: champ quantity manquant"
```

### Pattern F — Petite feature (1-5 fichiers) · ~300-600t

```
# Feature simple, pas d'orchestration lourde
/feat "ajouter un endpoint GET /api/v1/users/:id/stats"
# → planning léger, implémentation directe, tests
# Pas de brainstorming superpowers, pas de gate de validation
```

**Choisir entre /ship-feature et /feat :**

| Critère | `/ship-feature` | `/feat` |
|---|---|---|
| Scope | Feature complète, multi-fichiers | 1-5 fichiers max |
| Orchestration | Pipeline superpowers complet | Planning léger, direct |
| Gate de validation | Oui | Non |
| Code review auto | Oui (superpowers) | Non |
| Tokens estimés | ~1500-3000t | ~300-600t |

---

## Exemples complets

---

### Exemple 1 — Application mobile liste de courses (Expo/React Native)

**Contexte :** app mobile, offline-first, SQLite local, notifications push, iOS + Android.

**Setup plugins :**
```
/plugin-check "App mobile React Native Expo liste de courses, offline-first, SQLite, notifications push"

→ SIGNALS: frontend (mobile), fast-libs (Expo SDK)
→ ENABLE: frontend-design (composants RN)
→ WARN: context7 si Expo SDK 51+ utilisé (fast-libs)
→ OFF: gstack (mobile, pas de browser QA), ui-ux-pro-max (optionnel)
→ BLOCKING: none
```

**Prompt init (prompt complet → pas de questions) :**
```
/init-project "Application mobile 'KartApp' — liste de courses offline-first.

Stack: React Native 0.74 + Expo SDK 51 + TypeScript. SQLite via expo-sqlite. Notifications push via expo-notifications. Expo Router pour la navigation. Zustand pour le state. iOS + Android.

Features v1:
1. Création/édition/suppression de listes
2. Ajout d'articles (nom, quantité, unité, catégorie)
3. Cocher/décocher des articles
4. Partage de liste par lien (Expo Sharing)
5. Historique des 10 dernières courses

Out of scope: sync backend, collaboration, paiement.

Tests: Jest + @testing-library/react-native. Coverage >70%.
Convention: composants PascalCase, hooks use*, stores en Zustand slices."
```

**Ce que le scaffolder génère (STEP 5) :**
```
app/
  (tabs)/
    index.tsx          — liste des listes (vide)
    history.tsx        — historique (vide)
  list/[id].tsx        — détail liste (vide)
  _layout.tsx          — root layout Expo Router
components/
  ListCard.tsx         — vide
  ItemRow.tsx          — vide
  CategoryBadge.tsx    — vide
stores/
  listsStore.ts        — Zustand slice (vide)
  itemsStore.ts        — Zustand slice (vide)
db/
  schema.ts            — types SQLite (vide)
  migrations/
    001_initial.ts     — vide
hooks/
  useLists.ts          — vide
  useItems.ts          — vide
constants/
  Colors.ts            — tokens couleurs
app.json               — Expo config
package.json           — scripts: start/android/ios/test/lint
tsconfig.json
.env.example

Install : npx expo install ✅
Verify  : npx expo export --platform web --output-dir /tmp/expo-check --clear ✅
```

**Si le projet devient long (plusieurs features sur semaines) :**
```
# STEP 13 propose GSD v2 : répondre "yes"
# Puis dans terminal :
gsd
/gsd auto
# → GSD gère deck-building, sharing backend, etc. milestone par milestone
```

---

### Exemple 2 — Site vitrine graphisme élégant (Next.js)

**Contexte :** studio photographique, design premium, galerie masonry, dark mode, SEO, Vercel.

**Setup plugins :**
```
/plugin-check "Site vitrine Next.js 14 studio photo, design élaboré, animations Framer Motion, galerie, dark mode, SEO"

→ SIGNALS: frontend, design-system, fast-libs(Next.js)
→ ENABLE: frontend-design (~200t)
→ ENABLE: ui-ux-pro-max (~400t) — "design élaboré" signal fort
→ WARN: context7 non configuré → taper "force" pour continuer (ou configurer avant)
→ OFF: gstack (vitrine statique, pas de deploy complexe)
→ COST: ~1600t passif (comfortable)
```

**Prompt init :**
```
/init-project "Site vitrine 'Lumière Studio' pour photographe professionnel.

Stack: Next.js 14 App Router + TypeScript + Tailwind CSS + Framer Motion. Hébergement: Vercel. Pas de base de données.

Features v1:
1. Page d'accueil — hero animé, teaser galerie
2. Galerie masonry (>50 photos, lightbox, lazy loading)
3. Page À propos (biographie, parcours)
4. Page Contact (formulaire → Resend pour email)
5. Dark mode (system preference + toggle)
6. SEO (OpenGraph, sitemap, metadata par page)

Out of scope: blog, e-commerce, espace client, CMS.

Tests: Playwright (home, contact form, dark mode toggle). Jest/RTL pour composants.
Convention: composants dans components/, pages dans app/, assets dans public/images/."
```

**Ce que ui-ux-pro-max apporte en STEP 3 (brainstorm) :**
Avec ui-ux-pro-max actif, le brainstorming propose un système de design complet :
```
Palette    : zinc-950 (fond dark) / zinc-50 (texte) / amber-400 (accent)
Typo       : Cormorant Garant (titres serif) + Inter (corps)
Espacement : multiples de 8px, max-width 1440px
Animations : entrées scroll (Framer Motion viewport), 200ms ease-out
Masonry    : CSS columns responsive (1→2→3 colonnes), gap 16px
```
Sans ui-ux-pro-max : "Tailwind avec palette neutre, Inter". La différence est visible pour un projet où le design est le produit.

**Ajouter une feature après init :**
```
/ship-feature "Page Tarifs — 3 formules (Reportage, Portrait, Mariage) avec comparateur visuel et CTA de contact par formule"
```

---

### Exemple 3 — Jeu de puzzle avec API, auth et cartes collectibles

**Contexte :** le projet le plus complexe — React + FastAPI + PostgreSQL + Docker, auth JWT, gameplay, collection.

**Setup plugins :**
```
/plugin-check "Jeu de puzzle web React + FastAPI + PostgreSQL. Auth JWT, collection de cartes, boutique in-app, leaderboard. Multi-session, dev sur plusieurs semaines."

→ SIGNALS: frontend, fast-libs(React), deploy, multi-session
→ ENABLE: frontend-design, context7
→ ENABLE: ui-ux-pro-max (cartes visuelles, cohérence design)
→ CLI: gsd v2 RECOMMANDÉ (multi-session détecté)
→ OPTIONAL: gstack si deploy CI + browser QA prévus
→ COST: ~1800t passif (avec context7)
```

**Prompt init :**
```
/init-project "Jeu de puzzle web 'CardForge'.

Stack: React 18 + TypeScript + Vite (frontend), FastAPI + Python 3.12 (backend), PostgreSQL 16, Redis 7, Docker Compose.

Features v1:
1. Inscription/connexion (JWT + refresh tokens)
2. Gameplay puzzle grille 4x4 (pièces = cartes)
3. Collection personnelle (50 cartes de base)
4. 3 niveaux de difficulté
5. Sauvegarde de partie en cours
6. Profil + statistiques (parties, win rate)

Out of scope: boutique, PvP, cartes premium, leaderboard.

Tests: pytest backend (>80% coverage), Vitest + Testing Library frontend.
Docker: dev + prod (nginx pour frontend, uvicorn pour backend).
Convention: snake_case Python, camelCase TypeScript."
```

**Workflow long avec GSD v2 :**
```
# Après /init-project (STEP 13 → "yes")
# Le ROADMAP.md généré contient :
#   Milestone 1: Boutique in-app + Stripe
#   Milestone 2: PvP + matchmaking
#   Milestone 3: Leaderboard + saisons

# Dans un terminal :
cd cardforge/
gsd                  # démarre session GSD
/gsd auto            # GSD travaille sur Milestone 1 de façon autonome
# → research Stripe API + docs
# → plan décomposé en tâches
# → exécute chaque tâche dans fresh context window
# → commits propres avec messages clairs
# → revient quand Milestone 1 est complet ou si décision requise
```

**Quand le projet est lancé, ajouter des features ponctuelles :**
```
# Petite feature rapide (1h) → rester dans CC
/ship-feature "Ajouter un compteur de combo sur la grille de jeu"

# Feature longue (2 jours) → GSD v2
gsd
/gsd quick "Implémenter la boutique in-app avec Stripe"
# ou
/gsd auto  # si ROADMAP.md est déjà à jour
```

---

### Exemple 4 — Onboarding d'un projet existant (CLI Rust)

**Contexte :** outil CLI Rust existant sur GitHub, sans CLAUDE.md ni settings.

**Workflow :**
```bash
git clone git@github.com:user/my-rust-cli.git
cd my-rust-cli/
```

Dans Claude Code :
```
/onboard "Rust CLI"

→ PHASE 1 — Discovery:
   Cargo.toml trouvé : name="mycli", edition=2021, version=0.3.1
   Structure: src/main.rs, src/commands/, src/utils/, tests/
   Makefile: targets build, test, release, lint (clippy)
   Pas de Dockerfile (CLI pur)

→ PHASE 2 — Interview (manquant):
   Purpose ? → répondre: "CLI de gestion de projets locaux"

→ PHASE 3-5 — Génère:
   CLAUDE.md avec stack Rust 1.77, commandes exactes du Makefile
   .claude/settings.json — blocs cargo uniquement
   .claudeignore — target/, *.rlib

→ PHASE 6 — GSD v2 ? → skip (projet stable, pas de multi-session)

ONBOARD COMPLETE: mycli
→ Prêt pour /ship-feature
```

```
/plugin-check "Rust CLI, pas de frontend, pas de deploy"

→ SIGNALS: none (CLI pur)
→ DISABLE: frontend-design, ui-ux-pro-max, gstack, context7
→ KEEP: superpowers
→ COST: ~800t (minimal)
→ ACTION REQUIRED? NO
```

```
/ship-feature "Ajouter une commande 'mycli export --format json/csv' pour exporter les projets"
```

---

### Exemple 5 — Debug d'une régression (mode /analyze DEBUG)

**Contexte :** CI qui échoue après un merge, erreur de type TypeScript.

**Workflow :**
```
/analyze "src/store/cartStore.ts:47:5 - error TS2345: Argument of type 'string | undefined' is not assignable to parameter of type 'string'.

  const product = products.find(p => p.id === productId)
  addToCart(product.id)  // <-- erreur ligne 47"
```

**Output attendu (DEBUG MODE) :**
```
DEBUG ANALYSIS: TS2345 — 'string | undefined' non assignable à 'string' en ligne 47

ERROR:
  src/store/cartStore.ts:47 — product.id passé à addToCart(id: string)
  product peut être undefined car Array.find() retourne T | undefined

TRACE:
  addToCart(productId) → products.find(p => p.id === productId) → product.id → TS2345

ROOT CAUSE HYPOTHESES:
  1. [HIGH] Guard manquant après find() — product non vérifié avant utilisation
             evidence: find() retourne toujours T | undefined, jamais T seul
  2. [MED]  Type de addToCart() trop strict (devrait accepter string | undefined)
             evidence: si product peut légitimement être absent, le type est correct
  3. [LOW]  Changement récent dans le type Product (id devenu optional)
             evidence: vérifier git log sur Product type

WHAT TO VERIFY NEXT:
  - Ajouter guard: if (!product) return; avant ligne 47
  - Ou utiliser optional chaining: addToCart(product?.id ?? '')
  - Vérifier si product absent est un cas métier valide ou une erreur

DO NOT TOUCH:
  src/store/cartStore.ts dans son ensemble — corriger seulement la ligne 47
```


---

### Exemple 6 — CLI Rust from scratch (workflow minimaliste)

**Contexte :** outil en ligne de commande, pas de frontend, pas de serveur, pas de Docker. Le cas le plus simple — illustre que le système fonctionne aussi bien sur les projets petits que complexes.

**Setup plugins — zéro token inutile :**
```
/plugin-check "CLI Rust, convertisseur de fichiers JSON/CSV/TOML, pas de réseau, pas de frontend"

→ SIGNALS: none (CLI pur, pas de deploy, pas de frontend)
→ KEEP: superpowers
→ DISABLE: frontend-design, ui-ux-pro-max, gstack, context7, ruflo
→ COST: ~800t (base seulement)
→ ACTION REQUIRED? NO
```

L'intérêt ici est de voir que `/plugin-check` est aussi utile pour confirmer qu'on n'a **rien** à activer, évitant de polluer le contexte avec 3000t de plugins inutiles.

**Prompt init (complet, pas de questions) :**
```
/init-project "CLI Rust 'jsonconv' — convertisseur de formats de données.

Stack: Rust 1.77 + Cargo. Libs: serde + serde_json + csv + toml + clap (CLI args).

Features v1:
1. Conversion JSON → CSV
2. Conversion CSV → JSON
3. Conversion JSON → TOML
4. Conversion TOML → JSON
5. Lecture stdin ou fichier, écriture stdout ou fichier

Usage: jsonconv --from json --to csv input.json -o output.csv

Out of scope: XML, YAML, validation de schéma, streaming.

Tests: cargo test, unitaires par format, doctests pour les fonctions publiques.
Convention: snake_case partout, erreurs via thiserror, pas de unwrap() en dehors des tests."
```

**Ce que le scaffolder génère (STEP 5) :**
```
Cargo.toml          (serde, serde_json, csv, toml, clap pinned)
src/
  main.rs           (empty — clap parse + dispatch)
  lib.rs            (empty — re-exports)
  converter/
    mod.rs          (empty)
    json_csv.rs     (empty)
    csv_json.rs     (empty)
    json_toml.rs    (empty)
    toml_json.rs    (empty)
  error.rs          (empty — thiserror types)
tests/
  integration_test.rs (empty)
.gitignore          (target/, *.log)
.claudeignore       (target/)

Install : cargo fetch ✅
Verify  : cargo check ✅ (validates Cargo.toml + Rust syntax sans compiler)
Docker  : N/A (CLI pur)
```

**Gate #1 — architecture :**
Simple à valider. L'architecture proposée est plate, pas de surprise.

**Gate #2 — plan d'implémentation (20-25 tâches) :**
```
  1. [error.rs] Définir ConversionError avec thiserror
  2. [converter/json_csv.rs] fn json_to_csv() — tests first
  3. [converter/json_csv.rs] fn csv_to_json() — tests first
  ...
  20. [main.rs] Intégrer clap, dispatcher vers les converters
  21. [tests/integration_test.rs] Tests end-to-end avec fichiers fixtures
```

**Après init — features complémentaires :**
```
/ship-feature "Ajouter conversion YAML ↔ JSON via serde_yaml"
/ship-feature "Ajouter flag --pretty pour indentation JSON output"
/refactor src/converter/   # après plusieurs features, si violations de normes
/analyze src/converter/json_csv.rs  # avant une grosse modification
```

**Points clés de cet exemple :**
- `/plugin-check` confirme "rien à activer" — actif et utile même pour dire non
- Scaffolder génère un Cargo.toml avec deps pinned — pas de `cargo add` manuel
- `cargo check` comme verify évite un full compile sur un skeleton vide
- Pas de GSD v2 : CLI simple, toutes les features tiennent en 1-2 sessions CC

---

## Bonnes pratiques — résumé

**Plugins :** toujours vérifier avant de commencer. Les gates de validation de `/init-project` et `/ship-feature` sont des points de contrôle — ne jamais "force" une gate d'architecture sans l'avoir lue.

**Prompts :** plus le prompt initial est précis (stack, features, conventions), moins il y a de questions. Un prompt de 15 lignes structuré élimine l'interview entière.

**GSD v2 :** dès qu'une feature ou un projet dépasse une journée de développement. Le signal est : "je vais devoir ouvrir plusieurs sessions pour finir ça". GSD v2 résout la perte de contexte entre sessions.

**`/onboard` :** pour tout projet existant. Même si le projet est fonctionnel, CLAUDE.md et `.claude/settings.json` améliorent significativement la qualité des interactions suivantes.

**`/analyze` avant `/refactor` :** toujours. Le refactorer attend le rapport d'analyse avant de toucher au code. Le passer en bypass donne de moins bons résultats.

**`/readme` régulièrement :** après chaque milestone. Le mode AUDIT compare le README à l'état réel du code et liste les divergences — évite la documentation périmée.

---

---

---

### Exemple 7 — Refactoring d'un module Python legacy

**Contexte :** module `services/payment_service.py` dans un projet FastAPI existant. Écrit il y a 2 ans, jamais refactorisé. Violations connues : fonctions de 80 lignes, global state, pas de tests unitaires, logique métier mélangée avec appels HTTP.

**Setup :** projet déjà onboardé (CLAUDE.md présent), superpowers actif, plugins inutiles désactivés.

#### Étape 1 — Analyse avant toute modification

```
/analyze src/services/payment_service.py
```

**Ce que l'analyzer produit :**
```
ANALYSIS: src/services/payment_service.py

CONTEXT:
- Module de 340 lignes gérant les paiements Stripe
- Pas de tests, 3 variables globales, 2 fonctions > 80 lignes

KEY COMPONENTS:
- process_payment(): 95 lignes — logique métier + appel Stripe + logging entremêlés
- _build_stripe_payload(): 72 lignes — construction du payload + validation + mapping
- STRIPE_CLIENT: variable globale initialisée au module load (non mockable)
- retry_payment(): appelle process_payment() directement (couplage fort)

CONSTRAINTS:
- Aucun test existant — refactoring sans filet
- retry_payment() appelé par 3 endpoints différents — interface publique à préserver

RISKS:
- Modification de process_payment() peut casser les 3 appelants — probability: high
- STRIPE_CLIENT global rend les tests unitaires impossibles sans monkeypatch — probability: high
- _build_stripe_payload() mélange validation et mapping — extraction risquée — probability: medium

OPEN QUESTIONS:
- process_payment() retourne-t-il toujours un dict ou parfois None ?
- Les appelants de retry_payment() vérifient-ils le code de retour ?
```

#### Étape 2 — Refactoring guidé

```
/refactor src/services/payment_service.py
```

**Ce que le refactorer produit d'abord (rapport avant modification) :**
```
VIOLATIONS DETECTED: src/services/payment_service.py

- [NORM] process_payment(): 95 lignes → split plan: _validate_payment(), _call_stripe(), _handle_response()
- [NORM] _build_stripe_payload(): 72 lignes → split plan: _validate_payload(), _map_to_stripe()
- [NORM] STRIPE_CLIENT: global state → inject via paramètre ou dependency injection
- [QUALITY] logique métier dans process_payment() mélangée avec appel HTTP Stripe
- [QUALITY] retry_payment() appelle process_payment() directement (tight coupling)

PLAN:
1. Extraire _validate_payment() depuis process_payment() (lignes 12-28)
2. Extraire _call_stripe() depuis process_payment() (lignes 45-67)
3. Extraire _handle_response() depuis process_payment() (lignes 68-95)
4. Réécrire process_payment() comme coordinateur des 3 sous-fonctions
5. Extraire _validate_payload() et _map_to_stripe() depuis _build_stripe_payload()
6. Injecter stripe_client via paramètre (défaut = STRIPE_CLIENT global pour rétro-compat)

TESTS PRESENT: non
→ ⚠️ Aucun test existant. Le refactoring est risqué sans filet.
   Recommandation: créer des tests d'intégration minaux AVANT de toucher au code.
   Procéder malgré tout ? (yes / create tests first)
```

**User répond : "create tests first"**

Le refactorer génère d'abord `tests/test_payment_service.py` avec des tests d'intégration basiques qui capturent le comportement actuel (avant refactoring). Puis procède au refactoring fonction par fonction.

#### Étape 3 — Vérification finale

```
/analyze src/services/payment_service.py
```

Post-refactoring, l'analyzer confirme :
```
VIOLATIONS FIXED:
- process_payment(): 95 lignes → 18 lignes (coordinateur) ✅
- STRIPE_CLIENT: injectable, toujours rétro-compatible ✅
- Interface publique de retry_payment() inchangée ✅

REMAINING:
- _build_stripe_payload() : 48 lignes (sous le seuil de 25 mais proche)
  → justified: validation + mapping ne peuvent pas être séparés sans risque

TESTS: ✅ 8 tests passent (créés avant refactoring)
```

#### Points clés de cet exemple

- **`/analyze` d'abord, toujours.** L'analyzer identifie les risques (3 appelants, pas de tests) AVANT que le refactorer ne touche au code. Sans ça, le refactorer aurait pu casser l'interface publique.
- **Le refactorer s'arrête si pas de tests.** Ce comportement est intentionnel — refactorer sans tests = régression silencieuse garantie. Proposer de créer des tests d'abord est la bonne réponse.
- **Rapport de violations avant modifications.** Le refactorer produit toujours un rapport + plan, attend confirmation, puis exécute. Jamais aveugle.
- **`/analyze` après pour confirmer.** Le cycle analyse → refactor → analyse est la boucle de qualité correcte.

---

## Cas de figure — corrections v2.2.0 validées

Ces exemples valident les bugs corrigés dans la version 2.2.0.

---

### Cas A — Onboarding d'un monorepo Next.js + FastAPI

**Contexte :** repo avec `apps/web/` (Next.js 14) et `apps/api/` (FastAPI). Pas de `CLAUDE.md`. La racine n'a qu'un `package.json` de workspace vide.

**Avant v2.2.0 :** `/onboard` lisait le `package.json` racine (workspaces uniquement), ne trouvait pas de stack claire, produisait un `CLAUDE.md` incomplet ou demandait trop de questions.

**Avec v2.2.0 :**
```
/onboard

→ PHASE 1: apps/, pnpm-workspace.yaml détectés

MONOREPO DETECTED
Sub-packages: apps/web/, apps/api/
Options:
  A) Workspace entier — un CLAUDE.md à la racine
  B) apps/web seulement
  C) Chaque package séparément

[User: A]

→ Lit apps/web/package.json → Next.js 14, TypeScript, Tailwind
→ Lit apps/api/pyproject.toml → FastAPI, SQLAlchemy, alembic
→ Lit Makefile racine → make dev-web, make dev-api, make test

→ CLAUDE.md généré:
   Stack: Next.js 14 (apps/web/) + FastAPI (apps/api/) + PostgreSQL
   Build: make dev-web | make dev-api | docker compose up --build
   Structure: monorepo, 2 apps indépendantes, DB partagée
```

---

### Cas B — ship-feature : subagent en échec

**Contexte :** feature notifications email, STEP 4, tâche 3 (worker retry) échoue.

**Avant v2.2.0 :** arrêt abrupt. L'utilisateur devait diagnostiquer lui-même, relancer manuellement.

**Avec v2.2.0 :**
```
STEP 4 — Tâche 3 échoue:
  pytest FAILED test_retry_on_failure — AssertionError: worker ne retente pas

→ STEP 4b déclenché automatiquement

DEBUG ANALYSIS: Worker ne retente pas après timeout SMTP
ROOT CAUSE:
  1. [HIGH] Mock déclenche ConnectionRefusedError ≠ SMTPException — le retry handler ne s'active pas
  2. [MED]  max_retries non configuré dans le worker (valeur par défaut = 0)

SHIP FEATURE — ERROR IN STEP 4
OPTIONS:
  A) Corriger le mock (hypothesis 1)
  B) Passer cette tâche
  C) Abort

[User: A] → fix ciblé → re-run tâche 3 → passe ✅ → suite de la feature
```

---

### Cas C — Projet mobile React Native : signal correct

**Contexte :** `/init-project "App mobile KartApp React Native Expo iOS Android"`.

**Avant v2.2.0 :** signal `frontend` uniquement → `gstack` potentiellement recommandé (aberrant sur mobile).

**Avec v2.2.0 :**
```
SIGNALS: mobile (React Native + Expo détectés)

RECOMMENDATIONS:
  ⚡ ENABLE  : frontend-design — composants React Native (~200t)
  ⚠️  DISABLE : gstack — mobile, pas de browser QA ni deploy web
  ℹ️  OPTIONAL: ui-ux-pro-max — uniquement si design system complexe
  ℹ️  NOTE    : Docker N/A pour les apps mobiles

BLOCKING: none
```

---

### Cas D — STEP 13 avec GSD v2 non installé

**Contexte :** `/init-project` multi-session atteint STEP 13. `gsd` absent du PATH.

**Avant v2.2.0 :** `gsd init` → "command not found" → erreur opaque.

**Avec v2.2.0 :**
```
STEP 13 — GSD v2 INIT
→ Vérification: command -v gsd → NOT FOUND

⚠️ GSD v2 not installed.
   Run: npm install -g gsd-pi
   Then: /onboard add gsd (pour générer ROADMAP.md)

→ STEP 13 skippé proprement
→ Projet initialisé correctement ✅
→ GSD v2 peut être ajouté plus tard
```

---

### Cas E — CLI Rust : workflow minimaliste (0 plugin inutile)

**Contexte :** `/init-project "CLI Rust jsonconv, pas de réseau, pas de frontend"`.

```
/plugin-check "CLI Rust convertisseur JSON/CSV/TOML"

SIGNALS: simple, CLI pur
COST: ~800t

RECOMMENDATIONS:
  ✅ KEEP   : superpowers
  ⚠️ DISABLE: frontend-design, ui-ux-pro-max, gstack, context7, ruflo
BLOCKING: none → "proceed"

→ Scaffolder: cargo check comme verify (pas cargo build)
→ Docker: N/A (CLI pur)
→ Pipeline complet en ~800t passif, zéro bruit
```

Point clé : **`/plugin-check` est utile même pour confirmer qu'on n'a rien à activer.** Évite de polluer le contexte avec 3000t de plugins inutiles sur un projet simple.

---

## Cas de figure — corrections v2.3.0 validées

---

### Cas F — `/ship-feature` sans CLAUDE.md (nouveau repo cloné)

**Contexte :** développeur clone un repo existant, lance directement `/ship-feature` sans avoir run `/onboard`.

**Avant v2.3.0 :** le brainstorm (STEP 1) démarrait sans contexte projet → questions génériques, architecture inadaptée au projet réel.

**Avec v2.3.0 :**
```
/ship-feature "Ajouter authentification OAuth Google"

→ STEP 0  : plugin check OK
→ STEP 0b : ls CLAUDE.md .claude/CLAUDE.md → rien trouvé

⚠️ No CLAUDE.md found in this directory.
   This project has not been onboarded into claude-config.
   Run `/onboard` first, then re-run `/ship-feature`.
   STOP.
```

L'utilisateur fait `/onboard`, obtient son CLAUDE.md, relance `/ship-feature` avec le bon contexte.

---

### Cas G — Onboarding monorepo turborepo (Option C séquentielle)

**Contexte :** repo avec `apps/web/`, `apps/api/`, `packages/ui/`, `turbo.json`, `pnpm-workspace.yaml`.

**Avant v2.3.0 :** Option C non implémentée — comportement indéfini.

**Avec v2.3.0 :**
```
/onboard

MONOREPO DETECTED (turbo.json + pnpm-workspace.yaml)
Sub-packages: apps/web/, apps/api/, packages/ui/
[User: C]

── Package 1/3: apps/web ──
  Stack: Next.js 14 / TypeScript
  Genere: apps/web/CLAUDE.md + settings + .claudeignore
  OK

── Package 2/3: apps/api ──
  Stack: Express / Prisma / PostgreSQL
  Genere: apps/api/CLAUDE.md + settings + .claudeignore
  OK

── Package 3/3: packages/ui ──
  Stack: React + Storybook + Tailwind
  Genere: packages/ui/CLAUDE.md + settings + .claudeignore
  OK

Resume: 3 packages onboardes
  apps/web    | Next.js 14    | OK
  apps/api    | Express/Prisma| OK
  packages/ui | React/Storybook| OK

"Generate root-level ROADMAP.md? (yes/skip)"
```

Chaque package a son propre CLAUDE.md. Pas de CLAUDE.md racine (Option C).

---

### Cas H — plugin-advisor : signal `monorepo` evite gstack inutile

**Contexte :** monorepo Next.js (apps/web/) + FastAPI (apps/api/). Avant : signal `frontend` + `deploy` → gstack recommandé pour tout le repo.

**Avec v2.3.0 :**
```
SIGNALS: monorepo, frontend(apps/web/), fast-libs(Next.js), deploy(apps/api/)

RECOMMENDATIONS:
  OK KEEP   : superpowers
  ENABLE    : frontend-design — apps/web/ uniquement (~200t)
  WARN      : context7 — Next.js detecte dans apps/web/
  DISABLE   : gstack — apps/api/ n'a pas de browser-qa
              (NOTE: gstack aurait ete recommande si browser-qa present)
  DISABLE   : ui-ux-pro-max — pas de design-system signal

Cout total: ~1200t (au lieu de ~4400t avec gstack)
```

---

### Cas I — doctor.sh detecte templates/ manquant (installation pre-v2.0.0)

**Contexte :** installation ancienne (avant v2.0.0), `link.sh` n'avait pas de templates dans la boucle.

**Avant v2.3.0 :** `/init-project` echouait silencieusement en STEP 5 (scaffolder ne trouvait pas `~/.claude/templates/project-CLAUDE.md`).

**Avec v2.3.0 :**
```
bash doctor.sh

── Symlinks ──
  OK  ~/.claude/CLAUDE.md
  OK  ~/.claude/settings.json
  OK  ~/.claude/agents
  OK  ~/.claude/skills
  MISSING: ~/.claude/templates    ← nouveau check
  OK  ~/.claude/hooks/session-start.sh

Fix: cd /path/to/claude-config && bash link.sh
```

L'utilisateur voit exactement ce qui manque et la commande pour corriger.

---

### Cas J — session-start : box ne deborde pas avec 5 plugins actifs

**Avant v2.3.0 :** avec `gstack frontend-design ui-ux-pro-max context7 ruflo` tous actifs, la ligne `ON` depassait la largeur de la box.

**Avec v2.3.0 :**
```
┌─ Claude Code config ──────────────────────────────────┐
│  ✅ ON  : security-guidance rtk superpowers            │
│  🟢 ON  : gstack frontend-design ui-ux-pro-ma...      │  <- tronque a 37+...
│  ⚫ OFF : none                                         │
│  💰 ~5350t passif (48% budget)                        │
│  📦 v2.3.0                                            │
└───────────────────────────────────────────────────────┘
```

La box reste alignee. L'utilisateur voit qu'il y a plus de plugins (les `...` indiquent la troncature) et peut faire `/health` pour la liste complete.

---

## Cas de figure — corrections v2.4.0 validées

---

### Cas K — `/init-project` sur un projet avec CLAUDE.md existant

**Contexte :** projet FastAPI avec un `CLAUDE.md` minimal (stack documenté, features absentes). L'utilisateur veut ajouter un module de facturation.

**Avant v2.4.0 :** STEP 1 posait toutes les questions (stack, purpose, features, conventions) même si le stack était déjà documenté.

**Avec v2.4.0 :**
```
/init-project "Ajouter un module de facturation au projet"

STEP 1 — ls CLAUDE.md → FOUND
📄 Existing CLAUDE.md found — using as context.

Questions posées (manquantes seulement):
  → Features v1 du module facturation ?
  → Stratégie de tests ?
  → Conventions spécifiques ?

Questions SKIP (déjà dans CLAUDE.md):
  → Stack (Python 3.12 / FastAPI / PostgreSQL) ✓
  → Architecture ✓
```
3 questions au lieu de 6. Gain de temps significatif sur les projets déjà documentés.

---

### Cas L — `/status` en début de session (projet multi-semaines)

**Contexte :** projet CardForge repris après 3 jours. GSD v2 initialisé, milestone 2 en cours.

```
/status

PROJECT STATUS
==============

CONFIG
  Version   : v2.4.0
  Plugins ON: superpowers, frontend-design, context7 (~1200t)
  GSD v2    : installed (2.64.0)

PROJECT
  CLAUDE.md : found
  Stack     : React 18 + FastAPI + PostgreSQL + Docker
  Branch    : feature/stripe-integration
  Uncommitted: 3 files

RECENT COMMITS (last 5):
  a1b2c3d feat: add card collection schema
  e4f5g6h fix: jwt refresh token expiry
  ...

GSD v2
  Status    : initialized
  Milestone : Milestone 2 — Boutique in-app
  Progress  : 2/5 slices done

QUICK ACTIONS
  /ship-feature "..."  — next feature
  /health              — full diagnostic
```

Vue complète en une commande. Utile après un break pour se réorienter avant de taper `/gsd auto`.

---

### Cas M — plugin-advisor depuis un sous-package de monorepo

**Contexte :** l'utilisateur est dans `apps/web/` et lance `/plugin-check`. Le monorepo a `turbo.json` et `pnpm-workspace.yaml` à la racine (`../`).

**Avant v2.4.0 :** pas de détection monorepo → plugins recommandés comme pour un projet standalone Next.js.

**Avec v2.4.0 :**
```
/plugin-check "Next.js frontend"  (depuis apps/web/)

PHASE 1 — upstream detection:
  ls ../turbo.json → FOUND
  ls ../pnpm-workspace.yaml → FOUND

SIGNALS: monorepo (upstream), frontend, fast-libs(Next.js)
NOTE: dans apps/web/ d'un monorepo (détecté via parent dir)

RECOMMENDATIONS:
  ENABLE: frontend-design — apps/web/ uniquement
  WARN: context7 — Next.js détecté
  DISABLE: gstack — pas de browser-qa dans ce package
```

La recommandation est correcte même sans être à la racine du monorepo.

---

### Cas N — doctor.sh avec compteur de symlinks

**Contexte :** installation avant v2.0.0 — `templates/` n'est pas symlinké.

```
bash doctor.sh

── Symlinks ──
  ✓ ~/.claude/CLAUDE.md
  ✓ ~/.claude/settings.json
  ✓ ~/.claude/agents
  ✓ ~/.claude/skills
  ✗ ~/.claude/templates — MISSING
  ✓ ~/.claude/hooks/session-start.sh
  → Symlinks: 5/6 OK

Fix: cd /path/to/claude-config && bash link.sh
```

Le compteur `5/6 OK` indique exactement le problème sans lire toutes les lignes.

---

### Cas O — session-start avec 5 toggles actifs

**Avant v2.4.0 :** avec gstack + frontend-design + ui-ux-pro-max + context7 + ruflo actifs, la ligne débordait la box.

**Avec v2.4.0 :**
```
┌─ Claude Code config ──────────────────────────────────┐
│  ✅ ON  : security-guidance rtk superpowers            │
│  🟢 ON  : gstack frontend-design +3 more              │
│  ⚫ OFF : none                                         │
│  💰 ~5350t passif (48% budget)                        │
│  📦 v2.4.0                                            │
│  💡 /plugin-check  before starting a new project   │
│  🩺 /health  to run full diagnostic               │
└───────────────────────────────────────────────────────┘
```

`+3 more` indique qu'il y a 3 plugins actifs supplémentaires. `/health` donne la liste complète.

---

---

### Exemple 8 — Reprise d'une session interrompue avec GSD v2

**Contexte :** projet CardForge (React + FastAPI), milestone 2 "Boutique Stripe" en cours. Travail interrompu 4 jours plus tôt. GSD v2 initialisé, 3/7 slices terminées.

#### Étape 1 — Orientation rapide

```
/status

PROJECT STATUS
==============

CONFIG
  Version   : v2.5.0
  Plugins ON: superpowers, frontend-design, context7 (~1200t)
  GSD v2    : installed (2.64.0)

PROJECT
  CLAUDE.md : found
  Stack     : React 18 + FastAPI + PostgreSQL + Docker
  Branch    : feature/stripe-integration
  Uncommitted: 1 file (src/components/checkout/CartSummary.tsx)

RECENT COMMITS:
  b3c4d5e feat: add cart persistence to localStorage
  f6g7h8i feat: implement card collection display
  j9k0l1m chore: setup Stripe SDK

GSD v2
  Status    : initialized
  Milestone : Milestone 2 — Boutique in-app
  Progress  : 3/7 slices done (43%)
```

En 5 secondes : je sais où j'en suis, ce qui était en cours, et qu'il reste 4 slices à faire.

#### Étape 2 — Reprendre GSD v2 (terminal)

```bash
cd cardforge/
gsd                   # relance une session GSD
```

GSD v2 lit `.gsd/` et reconstruit le contexte :
```
GSD v2 — Resume session
Current milestone: Milestone 2 — Boutique in-app
Last completed   : Slice 3 — Cart UI
Next up          : Slice 4 — Stripe checkout integration

Previous session crash detected? No — clean shutdown.
State loaded from .gsd/state.db ✓

/gsd auto    → reprendre en mode autonome
/gsd         → reprendre en step mode (recommandé après longue pause)
```

#### Étape 3 — Reprendre en step mode (recommandé après pause longue)

```
/gsd

── Slice 4 — Stripe checkout integration ──
Tasks:
  [ ] 4.1 — Implement PaymentIntent creation (backend)
  [ ] 4.2 — Add Stripe Elements to CartSummary.tsx
  [ ] 4.3 — Handle payment confirmation + webhook
  [ ] 4.4 — Integration test: checkout flow

Research: Stripe docs fetched (context7 active)
Plan: ready

Execute slice 4? (yes / review plan / modify)
```

Le step mode permet de relire le plan avant d'exécuter — critique après une pause où les décisions peuvent avoir changé.

#### Étape 4 — Si une décision d'architecture a changé pendant la pause

```
/gsd discuss

"Je veux utiliser Stripe Payment Element au lieu de CardElement —
 c'est l'API recommandée depuis 2023"

GSD v2 integrates your input into the current plan.
Updated: Slice 4 plan — Payment Element instead of CardElement
Continue? (yes)
```

GSD v2 met à jour le plan dans `.gsd/ROADMAP.md` sans perdre le travail déjà fait.

#### Ce que ce workflow démontre

- **`/status`** est le point d'entrée naturel après une pause — snapshot complet en 1 commande.
- **GSD v2 `step mode`** est préférable à `auto` après une longue pause — permet de vérifier que les décisions sont toujours valides.
- **`.gsd/ROADMAP.md`** est la source de vérité du progress — parsé par `/status` et par GSD lui-même.
- **`/gsd discuss`** permet de modifier l'architecture en cours de route sans recommencer depuis zéro.

---

## Cas de figure — corrections v2.5.0 validées

---

### Cas P — `/init-project` détecte `.claude/CLAUDE.md`

**Contexte :** projet Node.js/Express avec CLAUDE.md dans `.claude/` (pas à la racine).

**Avant v2.5.0 :** `ls CLAUDE.md` ne trouvait rien → 6 questions pour redécouvrir le stack.

**Avec v2.5.0 :**
```
/init-project "Ajouter notifications push"

STEP 1: ls CLAUDE.md .claude/CLAUDE.md → .claude/CLAUDE.md FOUND
📄 Existing CLAUDE.md found — using as context.

Questions posées (manquantes seulement):
  → Service push ? (Firebase/OneSignal/APNs ?)
  → Types ? (in-app/email/mobile ?)

Questions SKIP (déjà dans .claude/CLAUDE.md):
  → Stack (Node.js 20 / Express / MongoDB) ✓
  → Purpose ✓
```
2 questions au lieu de 6.

---

### Cas Q — `/status` avec GSD v2 et ROADMAP.md présent

**Contexte :** projet CardForge avec `.gsd/ROADMAP.md` contenant des checkboxes GSD.

**Avant v2.5.0 :** `cat .gsd/STATUS.md` → fichier inexistant → `"no STATUS.md"`.

**Avec v2.5.0 :**
```
/status

PHASE 3 — parse ROADMAP.md:
  - [x] Slice 1 — Schema DB      ✓
  - [x] Slice 2 — Auth JWT        ✓
  - [x] Slice 3 — Collection cards ✓
  - [ ] Slice 4 — Boutique Stripe  (en cours)
  - [ ] Slice 5 — PvP
  ...

GSD v2
  Status    : initialized
  Milestone : Milestone 2 — Boutique in-app
  Progress  : 3/7 slices done (43%)
```

---

### Cas R — `/status` avec `.gsd/` vide (pas de ROADMAP.md)

**Contexte :** `gsd init` fait mais `/gsd discuss` pas encore lancé.

```
/status

GSD v2
  Status    : initialized
  Milestone : N/A
  Progress  : N/A

  GSD v2 initialized — no ROADMAP.md yet.
  Run /gsd init or /gsd discuss to create one.
```

Message actionnable au lieu d'une erreur silencieuse.

---

### Cas S — `doctor.sh` détecte `status-reporter.md` manquant

**Contexte :** installation v2.3.0 ou antérieure — `status-reporter.md` n'existait pas.

```
bash doctor.sh

── Consistency ──
  ✓ All skills have disable-model-invocation
  ⚠ Missing agents: status-reporter.md — run: bash link.sh
  ✓ No CRLF line endings detected
```

Sans ce check : `/status` chargerait un agent inexistant → erreur cryptique.

---

### Cas T — session-start avec 6 plugins actifs (tous affichés)

**Avant v2.5.0 :** `gstack frontend-design +4 more` — 4 plugins masqués.

**Avec v2.5.0 :**
```
┌─ Claude Code config ──────────────────────────────────┐
│  ✅ ON  : security-guidance rtk superpowers            │
│  🟢 ON  : gstack frontend-design ui-ux-pro-max context7│
│         + ruflo plugin-dev                          │
│  ⚫ OFF : none                                         │
│  💰 ~5750t passif (52% budget)                        │
│  📦 v2.5.0                                            │
└───────────────────────────────────────────────────────┘
```

Tous les noms visibles, box alignée.

---

### Cas U — onboarder crée `.gitignore` pour protéger `settings.local.json`

**Contexte :** monorepo, Option B (apps/api/), aucun `.gitignore` dans le package.

```
/onboard B apps/api

PHASE 5b — .gitignore check:
  ls .gitignore → absent

  Créé: apps/api/.gitignore
    # claude-config — personal settings (never commit)
    .claude/settings.local.json

📝 Created .gitignore with .claude/settings.local.json entry
```

Sans ce check : `settings.local.json` risquait d'être commité avec les clés API et credentials.

---

---

### Exemple 9 — Firmware C/C++ embarqué (workflow sans superpowers)

**Contexte :** firmware pour microcontrôleur STM32 (C, bare-metal). Pas de réseau, pas de frontend, pas de Docker. L'outillage standard de superpowers (brainstorming Socratique, subagent pipeline) est surdimensionné pour ce contexte.

**Setup plugins :**
```
/plugin-check "Firmware C STM32, bare-metal, pas de réseau, pas de frontend, pas de Docker"

SIGNALS: simple, CLI/embedded
COST: ~800t (superpowers seul)

RECOMMENDATIONS:
  OK KEEP   : superpowers (peut être utile pour brainstorm initial)
  DISABLE   : frontend-design, ui-ux-pro-max, gstack, context7, ruflo
  NOTE      : Pour un firmware vraiment simple (hotfix, modification ciblée),
              même superpowers peut être désactivé → ~0t passif
```

**Workflow minimaliste — modification d'un driver existant :**

```
# Pas de /init-project, pas de GSD, pas de superpowers

# 1. Comprendre avant de modifier
/analyze src/drivers/uart.c

OUTPUT:
  ANALYSIS: src/drivers/uart.c
  CONTEXT: Driver UART pour STM32F4, DMA en mode circulaire
  KEY COMPONENTS:
    uart_init(): 45 lignes — config registres + DMA
    uart_send(): 12 lignes — écriture dans ring buffer
    UART_IRQHandler(): 28 lignes — ISR, gère overrun
  RISKS:
    - uart_init() dépasse 25 lignes → split candidat
    - Accès non-atomique à ring_buffer_head dans ISR — probability: high
  OPEN QUESTIONS:
    - Quid si DMA transfer pas terminé avant appel uart_send() ?
```

**Modification chirurgicale :**
```
/ship-feature "Corriger l'accès non-atomique au ring_buffer_head dans l'ISR"

STEP 0b — CLAUDE.md found
STEP 0  — plugin check: superpowers OK (ou désactivé si YOLO mode)

STEP 1 — BRAINSTORM (rapide, contexte déjà clair depuis /analyze):
  Design: protéger ring_buffer_head avec __disable_irq()/__enable_irq()
  ou utiliser un flag volatile + memory barrier

STEP 3 — VALIDATION GATE:
  TASKS: 2
    1. [src/drivers/uart.c] Ajouter protection atomique dans UART_IRQHandler
    2. [tests/test_uart.c] Ajouter test simulant ISR concurrent

STEP 4 — IMPLEMENT (subagents légers, modifications chirurgicales)
```

**Alternative : workflow encore plus minimaliste (sans /ship-feature) :**
```
# Pour un hotfix ultra-ciblé, ignorer l'orchestrateur
/analyze src/drivers/uart.c    # comprendre
# → modifier directement avec Edit tool
# → vérifier avec make + flash sur hardware
```

**Points clés :**
- `/plugin-check` confirme "superpowers seulement" → aucun plugin inutile actif.
- `/analyze` est particulièrement utile sur du code C bas-niveau : l'analyzer identifie les accès non-atomiques, les race conditions, les violations de normes, **sans proposer de fix**.
- Pour un firmware, le workflow `analyze → ship-feature` peut se réduire à `analyze → edit direct` si la modification est triviale.
- GSD v2 n'est jamais pertinent pour du firmware : les sessions sont courtes et les tâches atomiques.

---

## Cas de figure — corrections v2.6.0 validées

---

### Cas V — `/status` compte les slices, pas les tasks

**Contexte :** `.gsd/ROADMAP.md` avec 3 milestones, chacun subdivisé en slices (`###`) contenant des tasks (`- [ ]`).

**Avant v2.6.0 :** comptait `- [x]` = nombre de tasks terminées → résultat faux (ex: `6/8 "slices"` alors que c'était des tasks).

**Avec v2.6.0 :**
```
ROADMAP.md:
  ## Milestone 1 — Auth [x]
  ### Slice 1 — JWT setup [x]      ← slice terminée
  ### Slice 2 — Login UI [x]       ← slice terminée
  ## Milestone 2 — Boutique
  ### Slice 3 — Cart UI [x]        ← slice terminée
  ### Slice 4 — Stripe checkout    ← en cours
  ### Slice 5 — Webhook handler    ← en attente

/status → GSD v2 : Progress = 3/5 slices done (60%)
          Milestone actuel : Milestone 2 — Boutique
```

3/5 correspond exactement au dashboard GSD v2.

---

### Cas W — `/ship-feature` affiche le contexte projet dès STEP 0b

**Avant v2.6.0 :** STEP 0b trouvait CLAUDE.md → continuait silencieusement. Pas de rappel de contexte.

**Avec v2.6.0 :**
```
/ship-feature "Ajouter webhook Stripe"

STEP 0b — CLAUDE.md found
📋 PROJECT CONTEXT
  Project : CardForge
  Stack   : React 18 + FastAPI + PostgreSQL + Docker
  Branch  : feature/stripe-integration
  Recent  : feat: add cart persistence
             feat: implement collection display
             chore: setup Stripe SDK
  GSD     : Milestone 2 — Boutique (3/5 slices)

→ STEP 1 — BRAINSTORM
```

Developer se réoriente instantanément — pas de risque d'implémenter sur la mauvaise branche.

---

### Cas X — session-start : 6 plugins actifs, tous affichés

```
┌─ Claude Code config ──────────────────────────────────┐
│  ✅ ON  : security-guidance rtk superpowers            │
│  🟢 ON  : gstack frontend-design ui-ux-pro-max context7│
│             ruflo plugin-dev                        │
│  ⚫ OFF : none                                         │
│  💰 ~5750t passif (52% budget)                        │
│  📦 v2.6.0                                            │
└───────────────────────────────────────────────────────┘
```

Tous les 6 plugins actifs visibles. Ligne de continuation alignée avec la ligne principale.

---

### Cas Y — Exemple 8 en action : reprise de session CardForge

```
# Dans Claude Code
/status
→ 3/5 slices, branche feature/stripe-integration, 1 fichier uncommitted

# Dans un terminal
gsd
/gsd         (step mode — relire le plan avant d'exécuter)

# Architecture change détectée pendant la pause
/gsd discuss "Je veux PaymentElement pas CardElement"
→ Plan mis à jour

# Reprendre l'exécution autonome
/gsd auto
→ GSD exécute Slice 4 avec le plan mis à jour, commits propres
```

Cycle complet : orientation → vérification plan → décision → exécution. Zero perte de contexte.

---

## Cas de figure — corrections v2.7.0 validées

---

### Cas Z1 — `/status` détecte le bon milestone courant

**Avant v2.7.0 :** `grep -E '^## ' | tail -5` → retournait les 5 derniers headings `##`, pouvait inclure des milestones **terminés** comme courant.

**Avec v2.7.0 :**
```
ROADMAP.md:
  ## Milestone 1 — Auth [x]
  ### Slice 1 — JWT [x]
  ## Milestone 2 — Boutique
  ### Slice 3 — Cart UI [x]
  ### Slice 4 — Stripe checkout    ← première slice en attente

awk scan top-to-bottom:
  → Slice 4 n'a pas [x] → milestone courant = "Milestone 2 — Boutique" ✓
```

---

### Cas Z2 — `/status` affiche l'état des tests

**Contexte :** projet Python, dernier pytest avec 1 test échoué.

```
/status

PROJECT
  CLAUDE.md   : found
  Stack       : FastAPI / PostgreSQL
  Branch      : feature/notifications
  Uncommitted : 2 files
  Tests       : 1 failing (test_email_worker.py::test_retry)
```

Developer voit immédiatement le test cassé avant de relancer GSD.

---

### Cas Z3 — `/ship-feature` : commits tronqués à 50 chars

```
📋 PROJECT CONTEXT
  Recent  : a1b2c3d feat: add Stripe PaymentIntent creation wi...
             e4f5g6h fix: jwt token refresh not working on mobi...
             i7j8k9l chore: update all dependencies to latest v...
```

Messages complets disponibles via `git log` — le contexte PROJECT affiche uniquement les 50 premiers caractères.

---

### Cas Z4 — `doctor.sh` détecte `lib/` non symlinké

```
bash doctor.sh

── Symlinks ──
  ✓ ~/.claude/CLAUDE.md
  ...
  ⚠ ~/.claude/lib exists but is NOT a symlink
  ✓ ~/.claude/hooks/session-start.sh
  → Symlinks: 6/7 OK

Fix: mv ~/.claude/lib ~/.claude/lib.bak && bash link.sh
```

Si `lib/` n'est pas un symlink vers le repo, `detect-plugins.sh` sourcé est la version installée localement — potentiellement périmée.

---

### Cas Z5 — plugin-advisor warn sur plugin-dev inactif

**Contexte :** projet React SaaS, `plugin-dev` resté actif par oubli.

```
/plugin-check "React SaaS avec FastAPI"

SIGNALS: frontend, deploy, fast-libs(React)

WARN: plugin-dev ON — aucun signal skill-creation détecté
      → ~100t économisés si désactivé
      → Activer uniquement quand vous créez des skills custom
```

---

### Cas Z6 — Firmware C STM32 : aucun plugin inutile

```
/plugin-check "Firmware C STM32, bare-metal, I2C driver"

SIGNALS: simple, embedded
COST: ~800t (superpowers seul)

DISABLE: frontend-design, ui-ux-pro-max, gstack, context7, ruflo, plugin-dev
NOTE: Pour hotfix ultra-ciblé, superpowers aussi optionnel
```

Pipeline complet disponible : `/analyze` → `/ship-feature` avec 0 overhead de plugins inutiles. Voir Exemple 9 pour le détail.

---

## Cas de figure — corrections v2.8.0 validées

---

### Cas AA — awk portable : milestone courant sur macOS et Linux

```
ROADMAP:
  ## Milestone 1 — Auth [x]
  ### Slice 1 — JWT [x]
  ## Milestone 2 — Boutique
  ### Slice 3 — Cart UI [x]
  ### Slice 4 — Stripe checkout   ← pas de [x]

awk scan (index() au lieu de regex):
  ## Milestone 2 → ms = "## Milestone 2 — Boutique"
  ### Slice 3 [x] → index = 14 ≠ 0 → skip
  ### Slice 4 → index = 0 → PRINT "## Milestone 2" → EXIT ✓
```

Fonctionne identiquement sur GNU awk (Linux) et nawk (macOS).

---

### Cas AB — Tests field : fallback sur la commande de test

```
Projet Node.js, pas de run récent, mais package.json présent:

/status → Tests: run 'jest --coverage' to check

Projet Rust (pas de CI log):
/status → Tests: run 'cargo test' to check

Firmware C (pas de test infra du tout):
/status → Tests: N/A
```

Plus jamais "unknown" quand il y a un test script défini.

---

### Cas AC — signal `embedded` sur firmware ESP32

```
/plugin-check "Firmware ESP32 WiFi driver, FreeRTOS, C"

SIGNALS: embedded (ESP32, Firmware, FreeRTOS détectés)
NOTE: embedded project detected — minimal plugin footprint

RECOMMENDATIONS:
  superpowers OPTIONAL
  DISABLE: tout le reste (frontend-design, gstack, context7, ruflo, plugin-dev)
  gsd v2: NOT recommended

Workflow: /analyze src/wifi_driver.c → /ship-feature si multi-fichiers
COST: ~800t (ou 0 si superpowers désactivé)
```

---

### Cas AD — doctor.sh liste les 8 agents

```
── Consistency ──
  ✓ All 8 agents present (analyzer, interviewer, plugin-advisor, readme-updater,
                           refactorer, scaffolder, onboarder, status-reporter)
```

Confirme visuellement la présence de `onboarder` et `status-reporter` (ajoutés en v2.4.0).

---

### Cas AE — Arbre de décision "Quel skill utiliser ?"

| Situation | Skill |
|---|---|
| Bug dans API FastAPI existante | `/ship-feature` |
| Comprendre un module avant modifier | `/analyze` |
| Reprise après 4 jours | `/status` |
| Install Claude Code cassée | `/health` |
| App Flutter from scratch | `/init-project` |
| Quels plugins pour React ? | `/plugin-check` |

L'arbre de décision est maintenant disponible en début de USAGE.md (section "Quel skill utiliser ?").

---

## Cas de figure — corrections v2.9.0 validées

---

### Cas AF — signal `embedded` détecté depuis le filesystem

**Contexte :** dossier firmware ESP32, `platformio.ini` présent, `src/*.c`, pas de `package.json`. L'utilisateur tape `/plugin-check` sans argument.

**Avant v2.9.0 :** aucun signal détecté → recommandations génériques.

**Avec v2.9.0 :**
```
/plugin-check   (sans argument, depuis le dossier firmware)

PHASE 1 filesystem scan:
  platformio.ini → FOUND → signal embedded

SIGNALS: embedded (platformio.ini)
NOTE: embedded project detected — minimal plugin footprint

KEEP   : superpowers (optional)
DISABLE: frontend-design, ui-ux-pro-max, gstack, context7, ruflo, plugin-dev
gsd v2 : NOT recommended (sessions courtes, tâches atomiques)
```

---

### Cas AG — ROADMAP.md flat (pas de `###` slices)

**Contexte :** GSD v2 initialisé avec un ROADMAP minimal : tasks directement sous `##`, sans `### Slice`.

**Avant v2.9.0 :** awk ne trouvait aucun `###` → retournait `"all milestones complete"` → faux.

**Avec v2.9.0 :**
```
ROADMAP:
  ## Milestone 2 — Core
  - [x] Create models
  - [ ] Implement CRUD   ← task en attente

awk fallback flat:
  → "## Milestone 2 — Core (flat)"

/status → GSD v2: Milestone 2 — Core (flat)
```

---

### Cas AH — pytest cache `{}` = all passing

**Avant v2.9.0 :** `cat .pytest_cache/.../lastfailed` affichait `{}` littéralement.

**Avec v2.9.0 :**
```python
d = json.load(open('.pytest_cache/v/cache/lastfailed'))
# d = {} → n = 0
# Output: "pytest: all passing"
```

---

### Cas AI — Refactoring profond : cycle `/analyze` → `/refactor` → `/analyze`

```
# Étape 1 : comprendre avant de toucher
/analyze src/payment/
→ RISKS: process_payment 95 lignes, global non-mockable, 0 tests

# Étape 2 : corriger sur la base du rapport
/refactor src/payment/
→ split, injection, tests ajoutés

# Étape 3 : confirmer que les violations sont résolues
/analyze src/payment/
→ VIOLATIONS FIXED: 95→18 lignes, injectable ✓
→ TESTS: 8 passing
```

Ce cycle est maintenant documenté dans l'arbre de décision ("Quel skill utiliser ?").

---

### Cas AJ — README renvoie vers USAGE.md

```
# claude-config

Global Claude Code configuration...

> Guide d'utilisation complet : voir USAGE.md — workflows typiques, exemples
> par type de projet, arbre de décision, cas validés...
```

Un nouvel utilisateur trouve immédiatement le guide pratique.

---

## Cas de figure — corrections v3.0.0 validées

---

### Cas AK — Rust FFI : plus de faux positif embedded

**Contexte :** bibliothèque Rust avec bindings C (FFI). `tests/c_binding_test.c` présent mais c'est du Rust, pas du firmware.

**Avant v3.0.0 :** présence de `.c` → signal embedded → recommandations firmware inutiles.

**Avec v3.0.0 :**
```
PHASE 1: ls platformio.ini → absent, ls *.ld → absent
Signal embedded: NOT detected ✓

SIGNALS: none (Rust library)
→ workflow normal Rust, superpowers + context7
```

Seuls `platformio.ini` ou un linker script `*.ld` déclenchent le signal embedded.

---

### Cas AL — ROADMAP avec `## Prerequisites` (faux positif évité)

**Contexte :** ROADMAP.md avec sections `## Overview`, `## Prerequisites`, puis `## Milestone 1`.

**Avant v3.0.0 :** awk flat matchait `## Prerequisites → - [ ] Node 22` → fausse progression.

**Avec v3.0.0 :**
```
awk scoped:
  ## Overview → ms="" (non-Milestone)
  - [ ] review → ms="" → SKIP ✓
  ## Prerequisites → ms="" (non-Milestone)
  - [ ] Node 22 → ms="" → SKIP ✓
  ## Milestone 1 — Auth → ms="## Milestone 1"
  - [ ] Login UI → PRINT "## Milestone 1 (flat)" ✓
```

---

### Cas AM — Projet Go : commande de test affichée

```
/status (projet Go avec go.mod)

Tests: run 'go test ./...' to check
```

Couverture: Python (`pytest`), Node.js (`jest`), Rust (`cargo test`), Go (`go test ./...`).

---

### Cas AN — `/analyze` : mode DEBUG découvrable via argument-hint

```
Dans Claude Code, argument-hint visible:
  /analyze <file/area — OR paste error/stack trace for DEBUG mode>
  
→ /analyze "TypeError at CartSummary.tsx:47 — Cannot read 'map' of undefined"
→ DEBUG MODE activé automatiquement ✓
```

---

### Cas AO — GSD v2 interrompu : reprise depuis l'arbre de décision

```
Arbre: "Session GSD v2 interrompue ?"
→ gsd → /gsd auto    (reprend depuis .gsd/)
→ /gsd steer         (modifier le plan)
→ /gsd forensics     (analyser un échec)
```

GSD v2 reprend automatiquement depuis `.gsd/` — l'utilisateur n'a pas besoin de recommencer.

---

## Cas de figure — corrections v3.1.0 validées

---

### Cas AP — STM32 avec Makefile+C : signal embedded retrouvé

**Contexte :** firmware STM32, `Makefile` + `src/main.c`, pas de `platformio.ini`, pas de `*.ld` séparé (linker inline dans Makefile).

**Avant v3.1.0 :** `Makefile` retiré en v3.0.0 → signal absent → recommandations génériques.

**Avec v3.1.0 :**
```
PHASE 1: ls Makefile → FOUND, ls src/*.c → 3 fichiers C
         ls package.json Cargo.toml go.mod → absent

Signal embedded: DETECTED (Makefile + .c + no ecosystem)
→ DISABLE all toggles, superpowers optional ✓
```

---

### Cas AQ — Rust FFI : toujours pas de faux positif

```
Cargo.toml présent + src/ffi.c
→ Signal embedded: NOT detected (Cargo.toml = contre-indicateur) ✓
```

---

### Cas AR — Onboarder PHASE 6 : ROADMAP.md généré même sans GSD installé

**Avant v3.1.0 :** `gsd init` échouait silencieusement si GSD absent.

**Avec v3.1.0 :**
```
PHASE 6 — command -v gsd → NOT FOUND

⚠️ GSD v2 not installed — run: npm install -g gsd-pi
ROADMAP.md generated (ready to use once GSD is installed).
After installing: gsd → /gsd auto
```

ROADMAP.md est utile même sans GSD installé — l'utilisateur peut l'installer plus tard.

---

### Cas AS — `doctor.sh` détecte skill `/status` manquant

```
bash doctor.sh

── Consistency ──
  ⚠ Missing skills: status/ — run: bash link.sh
  ✓ All 8 agents present (...)
```

---

### Cas AT — Token cost visible sur les patterns

```
### Pattern A — Nouveau projet court (≤1 session) · ~3000-5000t

Budget Pro note:
  /init-project ≈ 3000-5000t ≈ 30-45% d'une session Pro (~11k tokens)
  Planifier les grosses features sur des sessions séparées.
```

---

## Erreurs fréquentes — diagnostic rapide

| Erreur / Symptôme | Cause probable | Solution |
|---|---|---|
| `⚠️ No CLAUDE.md found` | `/ship-feature` dans un projet non onboardé | `/onboard` d'abord, puis relancer |
| `command not found: gsd` | GSD v2 non installé ou pas dans PATH | `npm install -g gsd-pi` puis `source ~/.bashrc` |
| `MISSING: ~/.claude/templates` dans doctor.sh | Installation pre-v2.0.0, `link.sh` pas rejoué | `cd /path/to/claude-config && bash link.sh` |
| Scaffolder échoue sur projet Flutter | `flutter` non installé ou pas dans PATH | Installer Flutter SDK, puis `flutter doctor` |
| Scaffolder échoue sur projet Expo | `npx` non disponible ou Node < 18 | `node --version` → mettre à jour Node si < 18 |
| Plugin-check recommande gstack sur mobile | Signal `mobile` non détecté (manque RN/Expo/Flutter dans description) | Ajouter "React Native" ou "Flutter" explicitement dans le prompt |
| Plugin-check recommande gstack sur monorepo sans browser QA | Signal `monorepo` non détecté | Vérifier que `apps/` ou `turbo.json` est détecté ; relancer depuis la racine du monorepo |
| Session-start box mal alignée | Version < v2.3.0 | Mettre à jour depuis l'archive v2.3.0+ |
| `/init-project` pose des questions déjà dans le prompt | Prompt incomplet (stack ou features manquants) | Ajouter stack, features v1, et conventions dans le prompt initial |
| STEP 13 `gsd init` : "command not found" | GSD v2 non installé au moment de init-project | `npm install -g gsd-pi`, puis `/onboard add gsd` |
| Plugin-check recommande plugins web sur firmware | signal `embedded` non détecté | Vérifier: `platformio.ini` ou `*.ld` présent, ou `Makefile` + `.c` + pas de `package.json`/`Cargo.toml`/`setup.py` |
| `detect_ruflo` retourne faux positif | Ancien MCP config resté dans `~/.claude.json` | Vérifier que `ruflo --version` fonctionne ; ignore les vieux configs MCP |
| `doctor.sh` : deny rules count mismatch | `settings.json` modifié manuellement | Vérifier avec `python3 -c "import json; print(len(json.load(open('~/.claude/settings.json'))['permissions']['deny']))"` — attendu : 100 |
| Subagent échoue en STEP 4, pas de guidance | Version < v2.2.0 | Mettre à jour, le STEP 4b est ajouté en v2.2.0 |
| `/analyze` ne passe pas en mode DEBUG | L'erreur n'est pas passée en argument | Copier l'erreur exacte dans l'argument : `/analyze "FAILED test_foo — TypeError: ..."`|
| GStack skills/ manquant | Submodule initialisé mais `./setup` pas exécuté | `cd skills-external/gstack && ./setup` |

---

## Référence rapide — signaux → plugins

```
Description contient...    →  Plugin
─────────────────────────────────────────────────────
React / Vue / Svelte       →  frontend-design ON
Next.js 13+ / App Router   →  context7 WARN
Prisma / Supabase          →  context7 ON
"design élaboré" / tokens  →  ui-ux-pro-max ON
Docker + QA browser        →  gstack ON
"plusieurs semaines"       →  gsd v2 CLI
"5+ agents parallèles"     →  ruflo ON
Rust / Python / Go / C     →  tout OFF sauf superpowers
Mobile / Flutter / RN      →  frontend-design ON, gstack OFF
Hotfix / script rapide     →  tout OFF sauf superpowers
```
