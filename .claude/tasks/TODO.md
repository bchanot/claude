# TODO

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
- [ ] Patcher un skill pilote (`/validate`) — valider UX
- [ ] Patcher les skills perso restants : analyze, bugfix, code-clean, commit-change, doc, feat, geo, graphify, harden, hotfix, init-project, make-pdf, onboard, plan-tune, plugin-check, refactor, seo, ship-feature, skills-perso, status, benchmark-models, context-save, context-restore
- [ ] Mettre à jour `~/.claude/CLAUDE.md` — mentionner convention --help disponible sur tous les skills perso
- [ ] Note : skills-external/gstack ont leur propre convention, ne pas toucher
