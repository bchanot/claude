# TODO

## 2026-06-23 — install self-sufficient + gstack on-demand par profil
Goal: `make install`/`make plugin`/`make update` installent TOUT sans étape
manuelle. Plus le profil-driven gstack on-demand (option 1 user : gstack OFF
par défaut, mais `set <profil>` qui a besoin de gstack l'active pour ce profil).
Root causes trouvées (logs install-20260623-181416.log) :
- Bug A : install.sh lance link.sh (étape 5) AVANT install-plugins.sh (étape 6),
  qui n'a jamais re-lancé link.sh → symlinks npx/externes jamais créés au 1er run
  (LRN-022 documentait déjà le trou). update-all.sh re-link déjà (L364).
- Bug B : `npx skills add` + gstack ./setup résolvent leur cible relativement au
  CWD (repo) → darwin-skill atterrit dans $REPO/.agents/skills + $REPO/.claude/skills
  au lieu de $HOME/.agents/skills. Auto-entretenu une fois $REPO/.agents créé.
- Bug C : profile.sh "missing — try: bash link.sh" trompeur (link.sh ne crée pas
  les skills gstack) ; full.profile liste 35 skills gstack jamais posés dans skills/.

- [x] Edit 1 — install-plugins.sh Step 8.5 : `npx skills add` depuis $HOME (subshell cd)
- [x] Edit 2 — install-plugins.sh : cleanup parasites $REPO/.agents/skills + $REPO/.claude/skills (gitignorés)
- [x] Edit 3 — install-plugins.sh : Step 10 final re-lance `bash "$REPO/link.sh"` (idempotent)
- [x] Edit 4 — update-all.sh Step 7.5 : `npx skills add` depuis $HOME (même Bug B)
- [x] Edit 5 — lib/profile.sh : GSTACK_SRC var + enable_skill gstack branche on-demand
      (symlink skills/<name> → skills-external/gstack/<name>) + message honnête
- [x] Verif — shellcheck/bash -n propres ; migré darwin → $HOME/.agents/skills + `bash link.sh`
      (skills/darwin-skill OK) ; `profile.sh set full` → 0 "missing", 35 gstack on-demand ;
      cycle minimal↔full OK ; git propre (symlinks gstack gitignorés) ; profil full restauré
- [~] Cleanup machine courante : $REPO/.claude/skills/darwin-skill + .agents/skills VIDE
      restent (rm bloqué par garde permission .claude/) → auto-nettoyés au prochain `make plugin`
- [x] Capitalize — LRN-042 (Bug B CWD-relatif) + BDR-030 (gstack on-demand par profil) + journal 2026-06-23
- [ ] Commit (via /commit-change)

## profile.sh — verbe `gstack on|off`
- [x] Extraire helper `enable_all_gstack()` (boucle de cmd_reset) — anti-duplication
- [x] Extraire helper `disable_gstack_not_in(prof)` (boucle gstack de cmd_set) — anti-duplication
- [x] Extraire helper `parked_gstack_count()` (réutilise pattern cmd_current)
- [x] Refactor cmd_reset + cmd_set pour utiliser les helpers (comportement préservé)
- [x] `cmd_gstack()` : `on` = enable tout gstack (garde label active-profile), `off` = disable gstack hors profil actif
- [x] Wire main() dispatch `gstack)` + usage() + bloc header
- [x] Doc : SKILL.md argument-hint + exemples + output-policy (Makefile générique suffit)
- [x] shellcheck propre + tests (help/bad-action/none-error/on/off cycle) — état live restauré exact
- [x] Investigué "fix" full.profile : PAS un bug — curation par design (BDR-017 caveat). Aucun fix code.
- [x] FOLLOW-UP (BLK-007 résolu) : linké `spec` (symlink chirurgical) + ajouté à full/web-full ; iOS NON linké (Linux, besoin Mac+Tailscale) ; `.gitignore` allowlist gstack complété (12 ajouts + checkpoint stale retiré) → `gstack on` git-clean ; LRN-025 capitalisé
- [x] Capitalize : BDR-018, LRN-024, BLK-007, EVAL-002, journal 2026-06-02 + backfill index (BDR-017, BLK-005/006)

## README.md overhaul
- [x] Plan
- [x] Corriger section install ctx7 (retirer MCP, clarifier CLI + API key)
- [x] Marquer ruflo comme désactivé
- [x] Supprimer section Troubleshooting/bugs courants
- [x] Simplifier stacks tierces (gstack, ruflo, ctx7, GSD) — juste description + lien
- [x] Ajouter section skills personnels (skills-perso)
- [x] Ajouter section système d'autogestion (plugin-advisor, tokens, synergies)
- [x] Nettoyer section Updating (retirer instructions manuelles par outil)
- [x] Nettoyer section Maintenance (retirer doublon updating)
- [x] Mettre à jour table Plugins reference (ctx7 row, ruflo OFF)
- [x] Corriger lien USAGE.md dans l'intro (retirer mention cas/erreurs)

## USAGE.md cleanup
- [x] Supprimer tous les "Cas de figure — corrections vX.X.X validées"
- [x] Supprimer table "Erreurs fréquentes"
- [x] Corriger `/readme` → `/doc` dans bonnes pratiques
- [x] Supprimer séparateurs orphelins

## Skill /doc
- [x] Mettre à jour doc-syncer.md pour gérer ajouts/suppressions de features
- [x] Mettre à jour SKILL.md description pour mentionner feature delta

## Auto-activation ui-ux-pro-max sur détection design
- [x] Créer `lib/design-gate.md` — snippet réutilisable (detect design signals + ask to activate ui-ux-pro-max)
- [x] Intégrer dans feater.md — STEP 0.5 entre scope check et mini-plan
- [x] Intégrer dans hotfixer.md — STEP 1.5 (si CSS/style/animation)
- [x] Intégrer dans bugfixer.md — STEP 1.5 (si bug UI/style)
- [x] Mettre à jour plugin-advisor.md — PHASE 4 : cohérence avec le design gate
- [x] Mettre à jour CLAUDE.md skill routing — documenter le comportement auto

## Refonte agents/seo-analyzer.md
- [x] Lire agent actuel + plugin-advisor + interviewer + feater + hotfixer + analyzer
- [x] Réécrire l'agent complet v1 (11 étapes)
- [x] Ajouter orchestration sub-agents (hotfixer/feater) + triage par batches
- [x] Déplacer plugin-advisor après détection stack (STEP 3 au lieu de STEP 0)
- [x] Ajouter 2 niveaux d'audit (LOCAL code-only / FULL live+externe)
- [x] Adapter scoring, legal, GEO aux deux niveaux
- [x] Renumeroter proprement (0-14) + corriger toutes les refs internes
- [ ] Commit

## /onboard — cso archetype-aware
Problème : prompt cso fallback est non-adaptatif — cherche XSS/SQLi/CORS même sur firmware.
Objectif : charger `## Typical pain points` + `Surface sécurité` de l'archétype et les injecter dans le prompt cso.
- [x] STEP 4.5 → ajouter extraction de archetype-context.md (pain points + Surface sécurité + category) — validé sur firmware-embedded / nextjs-app-router / library
- [x] STEP 6 dispatch cso fallback → re-écrire prompt : universal checks + sections conditionnelles par category (web / embedded / library / cli / infra / data / desktop)
- [x] STEP 6 dispatch cso gstack ON → passer `--archetype <name> --context-file .onboard-audit/archetype-context.md` dans args
- [ ] OUT-OF-SCOPE ce fix : étendre le pattern à analyze/code-clean/doc (déjà reçoivent `ARCHETYPE: <name>`, juste pas le context-file). À faire dans un 2e passage si besoin.

## /validate — nouveau skill W3C + WCAG (option A)
Scope : W3C HTML validity (validator.nu API) + W3C CSS validity (jigsaw API) + WCAG a11y (axe-core CLI / pa11y / WAVE API / fallback statique). Même pattern que /harden (audit par défaut, --fix avec confirmation A/B/C/D). Rapport = VALIDATE.md racine. Complémentaire à /onboard (qui audite a11y au setup initial — /validate est l'outil on-demand réutilisable).

Design décisions :
- **Agent dédié** : `agents/validator-analyzer.md` (nouveau). Pas de réutilisation de seo-analyzer — scope différent (validité syntaxique vs indexabilité).
- **Depth** : LOCAL (fichiers HTML/CSS statiques, tools npm locaux si dispo) | FULL (URL live + APIs distantes W3C/WAVE).
- **External validators** : validator.nu/?out=json (HTML), jigsaw.w3.org/css-validator (CSS), WAVE API optionnelle (quota gratuit ~100/mois), axe-cli local, pa11y-cli local.
- **Tools fallback order** : npm tools locaux → APIs distantes → agent général statique (cas onboard). Aucun install forcé.
- **--fix conservateur** : `alt=""` sur images décoratives évidentes, `lang` sur `<html>`, fermetures de tags manquantes, sauts de niveau heading renumérotés. PAS : labels forms, contraste couleurs, landmarks (demandent décision humaine).
- **Out of scope** : meta tags/SEO → /seo ; JSON-LD → /geo ; security headers → /harden ; code linting générique (ESLint/Prettier) → hors scope web standards.

Subtasks :
- [x] Créer `agents/validator-analyzer.md` — spec 6 étapes (478 lignes)
- [x] Créer `skills/validate/SKILL.md` — dispatcher (378 lignes)
- [x] Ajouter routage `/validate` dans `~/.claude/CLAUDE.md` section "Skill routing"
- [x] Mettre à jour `skills/harden/SKILL.md` — W3C/a11y redirigé vers /validate
- [x] Mettre à jour `skills/seo/SKILL.md` — cross-ref /validate pour W3C/WCAG
- [x] Grep cohérence : refs /validate correctes, skill détecté par la harness

## Animation lib (`motion`) — install + détection

Problème : `motion` (ex-`framer-motion`, rebrandé nov 2024) n'est ni installé par les scripts ni détecté par plugin-advisor / design-gate. Ajouter détection + install conditionnel.

Décisions :
- **Package** : `motion` (npm `motion`, import `motion/react`). `motion-v` pour Vue 3 (package séparé). Svelte/vanilla → `motion`.
- **Éligibilité** : tout projet qui peut consommer l'API. ✅ React/Next/Remix/Astro+React, Vue3/Nuxt, Svelte. ❌ Backend, CLI, embedded, Flutter, WordPress/Drupal/Strapi, RN (réservé `react-native-reanimated`).
- **init-project** STEP 5 : auto-install si éligible + absent (l'utilisateur a déjà validé scaffold).
- **onboard** STEP 2.5 : propose + attendre OK (projet existant, opt-in).
- **plugin-advisor** : read-only — détecte + reporte ("✅ motion installed" ou "ℹ️ eligible but absent — run /onboard").
- **design-gate** : ajouter motion/motion-v/framer-motion (legacy) dans filesystem signals.

Subtasks :
- [x] Créer `lib/animation-lib-check.sh` — fonctions `detect_anim_eligibility()` + `is_anim_lib_installed()` + `recommend_anim_install_cmd()`
- [x] Patcher `agents/scaffolder.md` PHASE 4 — note (le scaffolder n'installe PAS, l'orchestrateur init-project STEP 5e gère)
- [x] Patcher `skills/init-project/SKILL.md` — STEP 5e ANIMATION LIB (auto-install si éligible)
- [x] Patcher `skills/onboard/SKILL.md` — STEP 2.5 ANIMATION LIB (propose + attendre yes/skip)
- [x] Patcher `agents/plugin-advisor.md` PHASE 1 (sourcing du helper) + PHASE 2 (signaux `anim-lib-eligible`/`anim-lib-installed`) + PHASE 3 (section ANIMATION LIB read-only)
- [x] Patcher `lib/design-gate.md` — ajouter motion/motion-v/framer-motion + autres anim-libs dans filesystem signals
- [x] Tester : shellcheck OK ; matrix React/Vue/RN/backend/with-motion/no-package/pnpm tous corrects

## Helper `--help` / `help` sur tous les skills (option C)
Problème : aucun skill ne gère `--help` aujourd'hui. `argument-hint` affiche juste la syntaxe en autocomplétion, pas de description/exemples. L'utilisateur doit lire le SKILL.md ou deviner.

Objectif : `/<skill> --help` (ou `/<skill> help`) affiche un bloc standardisé (description, args, exemples, cross-refs) et exit SANS dispatcher l'agent ni modifier quoi que ce soit.

Design :
- **Lib partagée** : créer `skills/lib/help-handler.md` — snippet réutilisable "if $ARGUMENTS contains --help|help|-h, extract frontmatter fields (description, argument-hint, cross-refs) + afficher bloc d'aide standardisé + STOP".
- **Format d'aide** standardisé :
  ```
  /<skill> — <titre court>

  DESCRIPTION
    <extrait de la frontmatter description, dépouillé des Triggers>

  USAGE
    /<skill> <argument-hint>

  ARGUMENTS
    <liste détaillée de chaque flag avec son effet — nouvelle section
     dans les SKILL.md, ou parsée depuis STEP 0 arg parsing>

  EXAMPLES
    <3-4 exemples concrets>

  SEE ALSO
    <extrait des "For X → use /Y" de la frontmatter>
  ```
- **Intégration** : ajouter STEP 0.5 ("Handle --help") dans chaque SKILL.md juste après STEP 0 parsing args. Ordre : parse args → check --help → si oui afficher + exit → sinon continuer.
- **Skills à patcher** : `~/Documents/claude/skills/` = ~20 skills persos + skills-perso list pour référence. Ne PAS toucher skills-external/gstack (ownership externe) ni example-skills.

Subtasks :
- [ ] Créer `skills/lib/help-handler.md` — snippet réutilisable (détection + extraction + affichage)
- [ ] Définir format d'aide standard + section "ARGUMENTS" vs reuse de argument-hint
- [ ] Décider : sections ARGUMENTS/EXAMPLES doivent-elles être dans la frontmatter (nouveau champ YAML) ou dans le corps du SKILL.md (nouvelle section `## Help`) ?
- [ ] Patcher un skill pilote (`/validate`) — valider UX  _(désormais `/web-validate` — renommé e5e673a)_
- [ ] Patcher les skills perso restants : analyze, bugfix, code-clean, commit-change, doc, feat, geo, graphify, harden, hotfix, init-project, make-pdf, onboard, plan-tune, plugin-check, refactor, seo, ship-feature, skills-perso, status, benchmark-models, context-save, context-restore
- [ ] Mettre à jour `~/.claude/CLAUDE.md` — mentionner convention --help disponible sur tous les skills perso
- [ ] Note : skills-external/gstack ont leur propre convention, ne pas toucher

## Skill profiles (partition gstack par usage)
- [x] Plan
- [x] `lib/profile.sh` — list/show/current/apply/set/reset/diff via symlink toggle
- [x] `lib/profiles/{design,dev,qa,audit,minimal}.profile` — 5 profils
- [x] `skills/profile/SKILL.md` — slash command `/profile`
- [x] Wire `agents/plugin-advisor.md` — DETECT call profile.sh current + OUTPUT line PROFILE + nouvelle section "Skill profiles" dans TOGGLING EXTERNAL TOOLS
- [x] Wire `lib/toggle-external.sh` — header pointer vers profile.sh
- [x] `Makefile` — targets profile/profile-list/profile-current/profile-reset
- [x] Tests : list/show/current/diff/set/reset/apply tous OK, shellcheck propre, symlinks bien restaurés après reset

## Profile system v2 — extension plugins/MCPs/CLIs
- [x] Inventaire complet : 7 plugins (4 ON / 3 OFF), 0 MCP local, 4 CLIs installés
- [x] Définir `MANAGED_PLUGINS` (ui-ux-pro-max, plugin-dev, pr-review-toolkit) + `PROTECTED_PLUGINS` (caveman, security-guidance, superpowers)
- [x] `profile.sh` étendu : nouveau type `plugin@<marketplace>` (auto-toggle via `claude plugin enable/disable`), `mcp` (delegate à toggle-external.sh pour magic), `cli` (advisory only)
- [x] `cmd_set` désactive aussi les MANAGED_PLUGINS hors profil
- [x] `cmd_reset` ne touche PAS aux plugins (info line explicite — re-enable manuel ou via apply)
- [x] `cmd_current` : compte `enabled` + `installed`, tiebreaker = total le plus grand
- [x] `cmd_show` : colonne TYPE élargie à 30 chars pour `plugin@ui-ux-pro-max-skill`
- [x] 4 nouveaux profils : `web`, `seo`, `web-full`, `backend`
- [x] Profils existants raffinés (design, dev, qa, audit) avec `plugin@<marketplace>` + `cli`
- [x] `skills/profile/SKILL.md` : table profils mise à jour + table mécanisme par type
- [x] `agents/plugin-advisor.md` : table de recommandations étendue avec web/seo/web-full/backend
- [x] Tests : `set web` enable ui-ux-pro-max+magic, `set seo` disable ui-ux-pro-max, `set minimal` épargne always-on, `reset` restaure 64 skills
- [x] Memoire : BDR-008 (v2 décision) + journal entry 2026-05-04
- [x] Shellcheck propre

## /audit-delta — skill audit incrémental multi-axes (2026-06-11)
But : 1 skill, 4 axes cochables (conformité CLAUDE.md, erreurs/améliorations,
code mort, sécurité), scope = diff depuis dernier run (marqueur SHA persistant,
par axe), boucle par axe : audit → gate approbation → fix → re-vérification
obligatoire avant axe suivant. Construit via superpowers:writing-skills (TDD).
- [x] RED : baseline subagent sans skill (worktree isolé) — 7 gaps documentés
      (boundary par date de fichier, checkpoint en prose, pas de marqueur par
      axe, zéro gate, lint=verify, passe unique mélangée, registres auto-écrits)
- [x] GREEN : skills/audit-delta/SKILL.md — pass sous pression (state file
      utilisé, gate tenu malgré "fix tout + meeting", marqueurs par axe OK)
- [x] REFACTOR : trou trouvé (premier run + user injoignable, aucune règle) →
      patch : défaut full codebase report-only, jamais "from HEAD" ; re-test pass
- [x] Vérif finale : skill découvrable (~/.claude/skills/audit-delta via symlink
      skills/), frontmatter valide, worktrees de test nettoyés
- [x] Capitalize : BDR-020 + LRN-027 + journal 2026-06-11
- [ ] Commit (via /commit-change quand prêt)

## 2026-06-11 — darwin eval: 4 confirmed bugs fix (branch auto-optimize/*-bugfixes)

- [x] geo-analyzer.md: unreachable user → ALL file fixes report-only (STEP 12/13 triage gate)
- [x] init-project SKILL.md: repoint readme-updater.md (absent) → doc-syncer.md x2
- [x] analyzer.md: resolve "Update project memory" vs "Do not modify files" contradiction
- [x] onboard SKILL.md: allowed-tools += Agent, Skill (workflow STEPs 5-7 need them)
- [x] re-test geo fixture (unreachable) → expect zero source edits; 2 blind judges on geo-analyzer diff
- [x] commit per fix, results.tsv rows, merge if green

## 2026-06-19 — cleanup/caveman-always-on (full plugin purge)
Goal: disable caveman plugin + delete every repo dep on it. Plugin.json
self-declares always-on hooks → "enabled w/o always-on" impossible → full
purge. Keep memory-registry terse-format rule (separate subsystem); only
replace dead `/caveman:compress` cmd refs w/ "Legacy entries
(pre-format-rule): compress manually or via claude.ai on demand."
Version 3.4.0 → 3.5.0.
- [x] RUNTIME (user, no TTY): plugin disable + uninstall caveman@caveman; mcp list check
- [x] PHASE 2: settings.json (2 hook blocks + enabledPlugins + marketplace); hooks/ files delete; .gitignore block; session-start.sh L134
- [x] PHASE 3: install-plugins.sh STEP 5.5; update-all.sh block; plugins.lock.json; doctor.sh; lib/detect-plugins.sh; lib/profile.sh; plugin-advisor.md; skills/profile/SKILL.md
- [x] PHASE 4: README row; USAGE always-on line; CHANGELOG; CLAUDE.md cmd ref; skills/capitalize+prune-memory cmd refs; version.txt
- [x] PHASE 5: shellcheck clean (SC1091 info only); full diff reviewed → committed + merged to master

## 2026-06-26 — coupled-capitalize invariant v1 (Frame 2)
Plan: [.claude/tasks/2026-06-26-coupled-capitalize-invariant.md](2026-06-26-coupled-capitalize-invariant.md)
Goal: every dev flow commits its memory automatically (1 commit/flow) via shared
include; ship-feature reordered (capitalize before FINISH = PR-bug fix). Hook v2,
doc-sync twin chantier deferred. Safety in the pathspec, never `git add -A`.
- [x] Task 1 — `lib/memory-commit.sh` + tests T1/T2/T2-bis/T3/T4/T5/T6/T7 (real exec, outputs reported) — 58cb91d + bbef41c
- [x] Task 2 — `lib/capitalize-commit.md` include — b44791b
- [x] Task 3 — wire feater/hotfixer/bugfixer/commit-changer — 2763678
- [x] Task 4 — ship-feature reorder (capitalize before FINISH) — e8eff7e
- [x] Task 5 — init-project founding-decisions capitalize (F5) — df60df6
- [x] Task 6 — behavioral verify + shellcheck + CHANGELOG + BDR/LRN — this commit
- [ ] v2 (deferred) — Stop hook (non-blocking, BDR-033 style) reusing the detector
- [~] twin chantier — doc-sync → own plan (2026-06-27). NOTE: "reorder before FINISH" REFUTED — doc-syncer commits nothing, needs reorder + NEW doc-commit mechanism.

## 2026-06-27 — doc-sync coupled (twin of coupled-capitalize)
Plan: [.claude/tasks/2026-06-27-doc-sync-coupled.md](2026-06-27-doc-sync-coupled.md)
Goal: orchestrators commit the docs doc-sync patched, on the branch, BEFORE FINISH.
Same PR-bug class as memory, NOT same fix: doc-syncer commits nothing (proven) →
reorder + CREATE doc-commit.sh/.md (mirror memory-commit, 4 deltas). Surface-don't-block.
- [x] Task 1 — `lib/doc-commit.sh` + `lib/tests/run-doc-commit.sh` — 24/24 real-exec pass, shellcheck clean. T1a/b/c (guard catches .claude/+CLAUDE.md, mixed→refuse-all-loud) + T2 dynamic pathspec + T3/T4/T5/T6. Exit taxonomy 0/2/3/4 (4=scope violation).
- [x] Task 2 — `lib/doc-commit.md` include — 4a54a65. 4-exit report table (rc 4 = loud upstream anomaly), visible surface w/ agent-composed summary (attribution locked 3×), 2 conscious acks.
- [x] Task 3 — `agents/doc-syncer.md` `PATCHED_FILES:` OUTPUT — fb1f359. Newline (one path/line), both STEP 9 + AUTO A4; NONE silent. Separator contract aligned producer↔consumer, argv space-safe, T7 proves it (28/28). Additive, callers unaffected.
- [x] Task 4 — ship-feature reorder — 636b491. DOC SYNC 9→8 (+doc-commit), FINISH 8→9, HTML comment deleted. Ref-coherence: 159/189 STEP 8→9 FINISH + README:152-153 illustration completed (stale since e8eff7e). Historical records left (append-only).
- [x] Task 5 — init-project reorder — e81f629. SYNC README 12→10c (+doc-commit), GSD 13→12, /13→/12. Order 10b→10c→11→12. Ref-coherence: USAGE ×5 (table, illustration, 3 GSD refs) each verified post-swap. Latent-bug check: none (10b was non-shifting). BLK-011 record left (append-only), TODO locator→12.
- [x] Task 6 — ref-sweep — clean (no old headers; live refs fixed in Task 4/5; historicals left; USAGE:256 non-ordering). Caught inline-flow gap → Task 6b.
- [x] Task 6b — wire doc-commit into feat/bugfix/hotfix DOC SYNC — 1b01b95. commit-change exempt (no DOC SYNC); hotfix wired (include no-ops on empty).
- [x] Task 7 — close: `run-doc-behavioral.md` + shellcheck clean + 28/28 + CHANGELOG + BDR-036 / LRN-058-060 / EVAL-008. surface-replaces-gate + partial-init + scope-expansion engraved honestly.
- [ ] flagged separate — [[BLK-010]] scaffold/bootstrap commit gap (init-project, unborn HEAD + worktree)
- [ ] flagged separate — [[BLK-011]] GSD ROADMAP.md post-FINISH (now STEP 12 after Task 5 renumber; BLK-011 record itself left at STEP 13 — append-only)
- [ ] flagged separate — strengthen doc-sync MINOR gate (own doc-syncer chantier)
