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

---

## LRN-001 — `rtk` shape-compression breaks downstream parsers

- **Date** : 2026-04-22
- **Pattern** : quand un outil de tracking (`rtk`) intercepte stdout et retourne une représentation schématisée/compressée au lieu du payload brut, tout parseur en aval casse silencieusement — parce que l'utilisateur (ou le LLM) ne voit jamais la sortie `rtk`, seulement l'erreur du parseur.
- **Contexte** : `rtk curl` remplace la sortie JSON brute par une version tokenisée, indépendamment du TTY vs pipe. Les hooks Claude Code réécrivent `curl` → `rtk curl` automatiquement, donc impossible à prévoir sans connaître le hook.
- **Application future** : pour tout outil qui auto-réécrit des commandes standard, vérifier explicitement le comportement en pipe. Workaround documenté : `exclude_commands=["curl"]` dans `~/.config/rtk/config.toml`, ou `rtk proxy`. Voir `BLK-001`.
