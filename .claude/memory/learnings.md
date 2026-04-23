---
type: learnings_registry
entry_prefix: LRN
schema:
  id: LRN-XXX
  date: YYYY-MM-DD
  pattern: string (what was observed, abstracted)
  context: string (where/when it happened - concrete)
  future_application: string (when to recall this)
rules:
  - Capture learnings that apply beyond the current task.
  - Abstract from the incident - the pattern is what is reusable, not the one-shot fact.
  - Link to source (commit, file, PR) when possible.
  - Replaces the previous LESSONS.md format. Old file was empty - no content to migrate.
---

# Learnings registry (LRN)

## Index

| ID | Date | Pattern | Applies to |
|----|------|---------|------------|
| LRN-001 | 2026-04-22 | `rtk` shape-compression breaks pipes | any pipeline chaining `rtk curl/cat/read` into `jq`, `python -c`, `awk` |
| LRN-002 | 2026-04-23 | Moving report-file paths requires grepping bash READS, not just WRITES | any refactor that moves a generated file used by a dispatcher |

---

## LRN-001 — `rtk` shape-compression breaks downstream parsers

- **Date** : 2026-04-22
- **Pattern** : quand un outil de tracking (`rtk`) intercepte stdout et retourne une représentation schématisée/compressée au lieu du payload brut, tout parseur en aval casse silencieusement — parce que l'utilisateur (ou le LLM) ne voit jamais la sortie `rtk`, seulement l'erreur du parseur.
- **Contexte** : `rtk curl` remplace la sortie JSON brute par une version tokenisée, indépendamment du TTY vs pipe. Les hooks Claude Code réécrivent `curl` → `rtk curl` automatiquement, donc impossible à prévoir sans connaître le hook.
- **Application future** : pour tout outil qui auto-réécrit des commandes standard, vérifier explicitement le comportement en pipe. Workaround documenté : `exclude_commands=["curl"]` dans `~/.config/rtk/config.toml`, ou `rtk proxy`. Voir `BLK-001`.

## LRN-002 — Moving report-file paths requires grepping bash READS, not just WRITES

- **Date** : 2026-04-23
- **Pattern** : quand on déplace le chemin d'écriture d'un fichier généré (rapport, artefact, cache), il faut aussi grepper les endroits qui LISENT ce fichier — pas seulement ceux qui l'écrivent. Les dispatchers (skills orchestrateurs qui dispatchent à un agent puis parsent le résultat) contiennent typiquement des commandes bash `test -s X.md`, `grep ... X.md`, `wc -l X.md` — ces refs sont invisibles si on ne grep que pour la chaîne "write" ou "output path".
- **Contexte** : refactor `.claude/audits/` (commit `5c5e82c`). 1er pass : j'ai mis à jour les write paths dans 5 skills (seo/geo/harden/validate/code-clean) et 3 agents. Le user a demandé une verify-gate. Lui a re-grep, trouvé 10+ refs bash bare (ex: `test -s HARDEN.md`, `grep -oE ... VALIDATE.md`) que j'avais manquées — les dispatchers étaient cassés (ils cherchaient à la racine, agent écrivait dans `.claude/audits/`). Corrigé au commit `5c5e82c` (inclus dans le même commit).
- **Application future** :
  - Avant de déclarer "migration complète" d'un chemin de fichier, grep le **basename** (`grep -rn "HARDEN\.md"`) en plus du chemin complet — pour catcher les usages bash bare.
  - Si le fichier est utilisé dans des pipelines (`test`, `grep`, `wc`, `cat`, `head`), chercher ces verbes explicitement.
  - **Verify-gates sauvent** : un tour de plus demandé par l'user m'a fait re-grep de façon exhaustive. Sans ça, deux dispatchers auraient été cassés en prod.
