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
