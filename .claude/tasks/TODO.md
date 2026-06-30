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
- [x] Cleanup machine courante : $REPO/.claude/skills/darwin-skill + .agents/skills VIDE
      restent (rm bloqué par garde permission .claude/) → auto-nettoyés au prochain `make plugin`
      [reconcile 2026-06-29 : TOUJOURS présents (fs-vérifié, darwin-skill 116K daté 23/06) — `make plugin` pas rejoué depuis. Reste différé, déclencheur = prochain install.]
      [done 2026-06-30 : `make plugin` rejoué EXIT=0 (npm réparé via corepack, [[BLK-013]]) → Step 8.5 a retiré les deux ; fs-vérifié ABSENTS, vrai skills/ intact (36 entrées). Boucle fermée.]
- [x] Capitalize — LRN-042 (Bug B CWD-relatif) + BDR-030 (gstack on-demand par profil) + journal 2026-06-23
- [x] Commit (via /commit-change) — DONE (reconcile 2026-06-29 : working tree clean, travaux shippés)

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
- [x] Commit — DONE (reconcile 2026-06-29 : working tree clean, agent seo-analyzer live)

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

## Helper `--help` / `help` sur tous les skills (option C) [WON'T-BUILD 2026-06-30 — mesuré non-rentable]
> ⛔ WON'T-BUILD (2026-06-30) : ABANDON tranché après mesure. RED comportemental (6 reps, /web-validate + /harden, SANS instruction) → **6/6 rendent déjà une aide riche ET s'arrêtent sans dispatcher** (même /harden n'a pas lancé l'audit). Le comportement supposé absent est déjà spontané (convention universelle --help). Seule valeur résiduelle = cohérence de format (6 formats divergents) → ROI insuffisant pour ~5 lignes dans un CLAUDE.md compressé ([[BDR-031]]) sur repo mono-user. 3e état : NON "fait" (rien construit), NON "ouvert" (on ne le fera pas). L'option globale réalisait l'intention BDR-001 ; per-skill toujours rejeté. Voir [[BDR-001]] (won't-build), [[LRN-080]], [[LRN-075]]. Design + subtasks ci-dessous = historique, non actionnables.
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
- [x] Commit (via /commit-change quand prêt) — DONE (reconcile 2026-06-29 : working tree clean, skill audit-delta live)

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
- [x] v2 — REJETÉ (pas différé) — BDR-037 (reconcile 2026-06-29) : aucun event CC ne supporte un nag de fin-de-session (Stop = par-tour, SessionEnd = debug-log only). Vrai manque = câblage, corrigé en wirant /capitalize+/close à l'include. Aucun code à écrire.
- [x] twin chantier — doc-sync DONE (reconcile 2026-06-29) : chantier propre livré ci-dessous (2026-06-27, BDR-036). La note REFUTED était juste — doc-commit BÂTI, pas reorder-seul.

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
- [x] RESOLVED 2026-06-29 — [[BLK-010]] closed by `gitflow_init` root commit (init-project STEP 5f): scaffold/README get a deterministic commit owner + HEAD born before the worktree step. Verified (mechanism + STEP 5f wiring + T2 test); blockers.md index+body updated.
- [x] RESOLVED 2026-06-29 — [[BLK-011]] closed by REMOVAL: init-project STEP 12 (speculative gsd auto-bootstrap) deleted → orphan never created. Negative diff, not commit-plumbing ([[LRN-072]]). See chantier below.
- [x] DONE 2026-06-29 — doc-sync MINOR gate strengthened: ① shape-oracle [[BDR-040]] + ② masked-commit fix [[LRN-071]] (③ branch-guard deferred). See chantier below.

## 2026-06-29 — gitflow universal model + 6-repo migration (DONE)
Goal: universal gitflow across all `bchanot/*` Gitea repos. Lib built across prior sessions; migrated + hardened + dogfooded this session.
- [x] Lib hardened at ROOT — `gitflow_init` socle-commit made FATAL + identity precheck + `migrate_local` identity guard (BLK-012 → LRN-068); 57/57 green, abort-zero-mutation proven on identity-less repo
- [x] `lib/gitflow-migrate.sh` — probe (rights, not just identity) / local / remote, reversible→irreversible ordering, delete-master LAST
- [x] Migrated 6 repos (faunosteo, config, bchanot-cv, zenquality, game, claude): master→main, develop, Option-1 protection, master deleted — each delete behind eyeball+GO, ZERO loss, no force/`--no-verify`, settings intact
- [x] claude SELF-APPLIED — own committed lib migrated it; chantier landed C1 feat `167ea96` + C2 memory `1254643` + socle `620071b`; hook now governs claude
- [x] gstack submodule dirty (BLK-008 Playwright bump) excluded via `submodule.ignore=dirty` (LRN-070), NOT reset
- [x] Deleted merged branches: `feat/deploy-skill` (local+remote) + `cleanup/caveman-always-on` (remote)
- [x] Dogfood PROVEN: hook whitelists `.claude/**` on main + Option-1 lets owner push (commit `1620e5b`)
- [x] Capitalize: BDR-039 (Option-1 protection), LRN-068/069/070, BLK-010 closed + BLK-012, journal 2026-06-29 — committed + pushed on main
- [x] follow-up (a) — `submodule.gstack.ignore=dirty` committé dans `.gitmodules` — DONE (reconcile 2026-06-29 : commit `be1dcef` sur main, mergé via hotfix/gstack-ignore-gitmodules)
- [ ] follow-up (b) — zenquality `cleanup/post-smtp-fix` rename `<type>/<name>` ou finish+delete (AUTRE repo, optionnel)

## 2026-06-29 — MINOR-gate strengthening (doc-syncer) [DONE — merged develop, branch deleted]
Read-first cartography refuted the literal premise: "strengthen MINOR gate" = 3 problems;
the literal one (blocking gate on MINOR) contradicts engraved [[BDR-036]]. Scope: ①+②, not B,
③ deferred. Built test-first (Iron Law).
- [x] ② fix masked commit failure — `doc-commit.sh` exit 5 fail-loud ([[LRN-071]], 3rd occurrence of the swallowed-commit pattern). RED T8 proved masking, GREEN 32/32 + taxonomy (sh header/funcdoc + `doc-commit.md` rc-5 row)
- [x] ① MINOR-shape oracle — `lib/doc-shape.sh` ([[BDR-040]]) + `run-doc-shape.sh` 19/19 (boundary + env-override). Wired doc-syncer STEP A4 (escalate whole set → existing SIGNIFICANT gate; no=revert all, select=keep subset) + `doc-commit.md` ACKNOWLEDGMENTS coherence + behavioral Scenario C/D
- [x] shellcheck clean (doc-commit.sh, doc-shape.sh, both test harnesses); coherence ref-sweep clean
- [x] Capitalize — BDR-040 + LRN-071 + CHANGELOG (Added/Fixed) + journal 2026-06-29 (cont.)
- [x] FINISH — merged feature/minor-gate-strengthening → develop (`0f0bd7f`) on explicit signal
- [~] ③ branch-guard in doc-commit DEFERRED — duplicates protected-base predicate 3rd time (lib + hook + here); all migrated repos have the hook. Reconsider only for repos outside `gitflow init`

## 2026-06-29 — BLK-011 GSD ROADMAP post-FINISH [DONE — merged develop ce4391a, branch deleted]
User reframed: don't plumb a commit for the stranded ROADMAP — ask if gsd belongs at init at all.
Read refuted both option-premises (gsd ≫ roadmap; TODO ≠ gsd ROADMAP) but conclusion A held for a
stronger reason: speculative auto-bootstrap of an unused engine at creation is bad per se ([[LRN-072]]).
- [x] Resolve by REMOVAL — deleted init-project STEP 12 (negative diff −26/+13), not a commit helper
- [x] Ref-coherence sweep ("test" for a removal) — header 12→11-step, 10c note, 4 USAGE refs; zero dangling STEP-12 refs repo-wide
- [x] Scope guardrails — deliberate gsd use KEPT (onboarder PHASE 6, plugin-advisor, status-reporter)
- [x] Capitalize — [[BLK-011]] resolved (true reason + premise trace) + [[LRN-072]] + CHANGELOG Removed + journal 2026-06-29 (cont. 2)
- [x] FINISH — merged bugfix/blk-011-gsd-roadmap → develop (`ce4391a`); develop pushed to origin (6 commits, SSH)

## 2026-06-29 — prune-memory hardening (RED-7/8 + index backfill) [DONE — merged develop 73e12be, branch deleted]
LAST of 3 chantiers. Read-first cartography confirmed RED-7/8 + measured 34-row index drift.
- [x] RED-7 (example-priming) — fictionalized STEP-2 example to 9xx ids (live ids primed a wrong merge of complementary LRN-014/016); DETERMINISTIC test (run-deterministic.sh) per [[LRN-046]]. Caught its own ugrep false-green → /usr/bin/grep ([[LRN-074]]). [[LRN-073]]
- [x] RED-8 (added-negation inversion) — consciously ACCEPTED as documented limit in BACKLOG ([[LRN-047]]); no fragile guard built
- [x] Index backfill — 34 missing rows (decisions 11, learnings 21, blockers 2) composed + ID-sorted insert; drift 34→0, STEP-4 verify OK; moved pre-existing out-of-order LRN-021
- [x] Capitalize — [[LRN-073]] + [[LRN-074]] + [[EVAL-010]] + journal 2026-06-29 (cont. 3)
- [x] FINISH — merged bugfix/prune-memory-hardening → develop — DONE (reconcile 2026-06-29 : merge `73e12be`)
- [x] PUSH — develop → origin — DONE (reconcile 2026-06-29 : develop == origin/develop, 0 commit en avance)

## 2026-06-29 — skill /reconcile (RÉCONCILIATEUR file-ouverte ↔ réel) [SHIPPED 2026-06-30 — develop aede7af, pushed]
Genèse : l'inventaire manuel du 2026-06-29 a prouvé que le TODO mentait (5 cases fait-mais-non-coché
+ 1 "auto-nettoyé" qui ne l'était pas + 1 rejeté marqué "deferred"). Cet inventaire EST la spec du
skill ET son cas de test de référence (résultat manuel connu-bon à reproduire).

PRINCIPE NON NÉGOCIABLE — ce n'est PAS un grep des `[ ]` du TODO (ça reproduirait le mensonge : dirait
"ouvert" sur du fait-mais-non-coché). C'est un RÉCONCILIATEUR : confronte les sources DÉCLARATIVES à
l'état RÉEL et signale les ÉCARTS. Un lister-de-todos ne vaut rien (grep le fait) ; un "le TODO prétend
X, le réel est Y" vaut beaucoup.
- Sources DÉCLARATIVES : TODO.md ; BDR deferred/follow-ups/caveats ; BLK status=open|upstream ;
  LRN caveats "revisit if / re-run if".
- État RÉEL (oracles) : git (branche mergée/absente, commit existe, origin sync, working tree clean) ;
  fichier live = committé (skill/agent présent + linké = shippé) ; statut registre.

SORTIE = les 4 catégories de l'inventaire 2026-06-29 :
  1. actionnable maintenant (non bloqué)
  2. bloqué (condition externe — upstream)
  3. différé (déclencheur conditionnel)
  4. écart TODO↔réalité (fait-mais-non-coché / rejeté-marqué-deferred / "auto-fait" non vérifié)
  + CONTRADICTIONS inter-registres (ex. BDR-001 accepted "pas de helper par SKILL.md" vs chantier
    --help qui copie dans chaque SKILL.md).
  + réconciliation TODO **GATED** : montre les écarts, DEMANDE avant cocher/requalifier
    (modifie un fichier tracké → jamais silencieux).

Subtasks (à détailler au lancement) :
- [x] Spec : table oracle-par-source (commit existe / branche absente / tree clean / skill linké /
      statut registre) — chaque "déclaré" a son test réel — DONE (lib/reconcile.sh : reconcile_oracle_*)
- [x] Décider build : superpowers:writing-skills (TDD, RED = fixture TODO menteur reproduisant les 7 écarts) — DONE (RED a4872 miroir + RED-B Index-ignore à dents + GREEN comportemental a8404)
- [x] `skills/reconcile/SKILL.md` — DONE (skill mince : orchestration + gate A/B/C + limites honnêtes)
- [x] routage CLAUDE.md (triggers : "reconcile", "file vraiment vide ?",
      "qu'est-ce qui reste ouvert", "inventaire chantiers") — DONE (CLAUDE.md "Skill routing" + link.sh)
- [x] Détecteur de contradictions inter-registres (BDR accepted vs chantier qui le contredit) — DONE (reconcile_contradiction_candidates ; surface, n'asserte pas)
- [x] Gate de réconciliation (diff TODO proposé, A/B/C confirm avant edit) — DONE (SKILL.md "The gate" ; registres read-only)
- [x] Test final = reproduire l'inventaire 2026-06-29 (cat. 1-4 + contradiction BDR-001) comme oracle — DONE (run-reconcile.sh 20/20, fixtures neutres, RED prouvé rouge avant le vert)
- SHIPPED 2026-06-30 : feat `82e6322` + mémoire `6b512be` → merge `aede7af` (feature/reconcile-skill supprimée) → poussé origin/develop. main intact. BDR-041 + LRN-075/076/077 + EVAL-011 capitalisés.

## [SHIPPED 2026-06-30 — develop 0c0b748, released v4.0.0 (tag v4.0.0)] skill /release-candidate — orchestrateur gitflow release
Pertinent maintenant : develop ahead de main, prochaine étape gitflow = release.
VÉRIFIÉ dans lib/gitflow.sh (2026-06-30) — release CÂBLÉE, pas que hotfix :
- start base=develop (`gitflow_base_for` L49) ; `gitflow start release <ver>` positionne sur la branche (L71).
- finish fan-out (`gitflow_finish` L108-111) : merge main + merge-back develop + delete (locale, `_gitflow_delete` L96).
- GAP CONFIRMÉ (grep clean) : AUCUN `git tag` ni bump version dans tout gitflow.sh → la mécanique merge mais ne tague PAS.

Design (à la conception) : ORCHESTRATEUR au-dessus du gitflow existant — NE PAS réécrire la mécanique.
- `gitflow start release <ver>` (depuis develop) → positionne.
- prep sur la branche release : bump VERSION + CHANGELOG (Keep-a-Changelog) + RC fixes.
- `gitflow finish` (merge main + merge-back develop + delete — déjà câblé).
- FOURNIR le tag manquant : `git tag` sur main au merge-commit (le seul morceau absent de la lib).
- push gaté (ASK, [[LRN-069]]) : main + develop + tag.

Subtasks (à détailler au lancement) :
- [x] Décider : tag fourni par le skill au-dessus de gitflow (mécanique non réécrite) — d3d6ced, [[BDR-042]]
- [x] `skills/release-candidate/SKILL.md` — orchestration start→prep→finish→tag→push(gaté) + gate humain "WHEN to release" — présent (d3d6ced)
- [x] routage CLAUDE.md — présent (~/.claude/CLAUDE.md "Cut a release → release-candidate")
- [x] test — prouvé par la release réelle 4.0.0 : fan-out main (709facf) + develop (4a00a60) + tag v4.0.0

## Auto-déclenchement des skills par intention [WON'T-BUILD 2026-06-30 — mesuré : Claude discrimine déjà (3 classes)]
> ⛔ WON'T-BUILD (2026-06-30) : 3e moot de la série (après [[BDR-001]] --help + [[BDR-043]]/[[LRN-082]] darwin re-baseline). Cartographie : routing = STACK L0(design-hook)→L1(superpowers « 1%→MUST invoke », dominant)→L2(prose CLAUDE.md)→L3(frontmatter)→L4(BDR-019). L1 SUR-détermine déjà l'invocation → « auto-call ? » = déjà oui. Reframe C : la vraie question = DISCERNEMENT, risque inversé under→**OVER**-routing. Mesure en VRAIES sessions fraîches (8 prompts / 3 classes) : CLEAR→route ✓, AMBIGUË→demande (refuse de deviner, investigue pour une question utile) ✓, TRIVIALE→s'abstient ✓. Le sur-routing soupçonné (L1 vs règles Workflow) NE se matérialise PAS — le modèle équilibre. Prose de bornage L2 = valeur fantôme + risque de DÉGRADER un discernement déjà bon. Voir [[BDR-044]] (reframe + verdict), [[LRN-083]] (RED sous-agent invalide), [[LRN-080]] (mesure-first, corroboré 3-in-a-row). RED sous-agent initial (0/6) RETIRÉ comme non-discriminant (plancher artefact). Design + subtasks ci-dessous = historique, non actionnables.
> ⏭️ (historique) NEXT, mais CADRÉ : **pas de design avant la mesure**. Jumeau méthodologique de [[BDR-001]] `--help` (won't-build après RED) — même piège architectural, même garde-fou [[LRN-080]] (mesurer avant d'instruire) + [[LRN-049]] (borner le bruit avant le marqueur). Les subtasks ci-dessous s'arrêtent à la mesure ; le design ne s'ouvre QUE si le RED valide la valeur.

**Contrainte architecturale (établie pour `--help`, non négociable) :**
Aucun mécanisme n'intercepte le message utilisateur pour *lancer* un skill. La harness ne route pas avant que le modèle réponde — un skill n'est invoqué QUE par le modèle (outil Skill). Donc « auto-call déterministe » = IMPOSSIBLE. Le seul levier sur l'invocation elle-même = instruire le MODÈLE à reconnaître l'intention et appeler le bon skill → **conformité-modèle, PAS déterminisme**. C'est une instruction de routage CLAUDE.md, pas un mécanisme.
- Nuance (raffinement) : une couche déterministe existe *en amont* du call, pas *sur* le call — un hook `UserPromptSubmit` peut détecter un signal et INJECTER un rappel de routage (le `design-toolchain` hook fait déjà exactement ça pour l'UI ; le banner session-start aussi). Détection déterministe + injection advisory ; le modèle reste celui qui tire. MAIS sur des verbes d'intention (« corrige », « crée », « bug »), un hook keyword serait BRUYANT (ces mots sont partout) — le design-hook s'en sort car « design/UI » est un signal rare. Donc le levier hook est probablement non-viable pour le cas large → ce qui **renforce** le besoin de borner aux signaux rares/non-ambigus.

**Substrat déjà en place :** [[BDR-019]] a retiré `disable-model-invocation` repo-wide → le modèle PEUT déjà self-router vers les skills (défaut = activé ; user l'avait vécu live : intention feature détectée, `ship-feature` voulu, jadis bloqué). Et la section « Skill routing » de CLAUDE.md existe déjà. Donc la **baseline du RED = le routage CLAUDE.md ACTUEL tel quel** ; le chantier n'a de valeur que si le RED prouve que cette prose SOUS-déclenche sur intention claire (exactement la logique --help : baseline = convention déjà là, question = est-ce qu'instruire en plus change quoi que ce soit).

**Le chantier COMMENCE par (rien d'autre avant) :**
- [x] (a) **Cartographier** le routage CLAUDE.md actuel — quels signaux → quels skills sont déjà censés router (« Skill routing » + « Design work » + descriptions de skills). État des lieux factuel, pas de jugement.
- [x] (b) **RED comportemental** ([[LRN-080]]) — prompts d'intention IMPLICITE, naturalistes, SANS instruction renforcée : « il y a un bug, debug », « on va créer X », « corrige ceci », « refactor ce module », « cut a release »… → le modèle invoque-t-il le bon skill, ou fait-il la tâche à la main en ignorant le skill ? N reps, plusieurs intents distincts.
  - Garde-fou RED : **ne PAS amorcer**. Sessions fraîches / sous-agents, prompts naturels, zéro mention de « skill » / « routage » / « test » dans le prompt mesuré (sinon le modèle route parce qu'il SAIT qu'on le teste — contamination). Le RED `--help` était mécanique donc peu sensible à l'amorçage ; l'intent-routing l'est beaucoup plus → rigueur supérieure requise.
- [x] (c) **Décider selon le RED** :
  - déjà bon (comme --help) → chantier MINCE, voire won't-build ; capitaliser le constat (3e état : mesuré non-rentable, ni fait ni ouvert).
  - sous-déclenche → vraie valeur : renforcer la **prose de routage** (levier modèle) sur signaux CLAIRS uniquement — PAS un hook keyword (trop bruyant, cf. nuance ci-dessus).

**Scope à border au cadrage — NE PAS faire « tout skill jugé pertinent » :**
Tension réelle proactif vs intrusif. Auto-déclencher feat/bugfix sur intention CLAIRE et non-ambiguë = sain. « Déclenche tout skill jugé pertinent » = RISQUÉ (faux déclenchements, skills non sollicités, flux interrompus). Réglage cible ([[LRN-049]] borner le bruit) = déclencher sur signaux d'intention CLAIRS et non-ambigus ; **ambigu → DEMANDER, pas auto-déclencher**. À définir précisément SI (et seulement si) le RED valide : table `signal → skill` + la frontière exacte de l'ambiguïté.

## 2026-06-30 — session-close follow-ups (promoted from BLK-013 / BDR-043)
- [ ] (a) Harden install-plugins.sh Step 1 — guarantee `npm` on apt-`nodejs` hosts (detect missing npm + `corepack enable npm`), not just check `node >=22`. Fix-forward for [[BLK-013]] — stops `make plugin` Error 127 recurring on any fresh apt machine.
- [x] (b) Re-baseline darwin on the 5 ex-broken gstack skills (`benchmark-models`, `context-restore`, `context-save`, `make-pdf`, `plan-tune`) — now repaired and back in scope ([[BDR-043]], trigger cleared). Verify `results.tsv` still marks them `status=error` first. (Promoted from BDR-043's action-field — not an item the user authored.)
      [resolved-MOOT 2026-06-30 : won't-run. BDR-043 cleared only motif (a) of BDR-015's TWO exclusion grounds (symlinks repaired ✅); motif (b) external-ownership INTACT — the 5 resolve to skills-external/gstack/ (submodule), darwin optimizes by EDITING SKILL.md → would dirty the submodule (forbidden [[LRN-070]]). Re-baseline = unactionable score. + results.tsv gone (wiped by 23/06 make-plugin reinstall) → not even a re-baseline, a fresh-from-zero one. Geometric trigger lifted, value trigger intact — twin of --help [[LRN-080]]. See [[LRN-082]]. Not "done", not "open": MOOT.]
