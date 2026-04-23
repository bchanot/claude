---
type: evals_registry
entry_prefix: EVAL
schema:
  id: EVAL-XXX
  date: YYYY-MM-DD
  output: string (what was produced)
  method: string (how it was evaluated - manual read, test, benchmark, user feedback)
  anomalies: list of strings (what was wrong, missing, surprising)
  action: [keep | correct | deprecate]
rules:
  - Log an eval whenever you validate the quality of something Claude produced (report, audit, plan, generated code).
  - Action keep - the output is fit for purpose as-is.
  - Action correct - needs revision; capture what.
  - Action deprecate - the approach itself is flawed; link to the decision that replaces it.
---

# Evals registry (EVAL)

## Index

| ID | Date | Output | Action |
|----|------|--------|--------|
| EVAL-001 | 2026-04-23 | Plan de restructuration .claude/ (STEP 2 de ship-feature) | keep |

---

## EVAL-001 — Plan de restructuration `.claude/`

- **Date** : 2026-04-23
- **Output** : plan 21 tâches pour migrer `tasks/` vers `.claude/tasks/` + créer `.claude/memory/` + `.claude/audits/` + intégrer CAPITALIZE dans 5 skills + créer `/close`.
- **Méthode** : relecture manuelle des 5 skills/agents impactés, vérification que rtk est path-agnostic, symlink `~/.claude/CLAUDE.md` → projet confirmé (un seul fichier à éditer). Radical-honesty check sur le ritual "session-close" : confirmé comme aspirationnel sans intégration dans les skills → scope élargi à Option D.
- **Anomalies** : aucune bloquante. Note : `tasks/LESSONS.md` était vide (101B, juste un header) — migration vers `learnings.md` symbolique.
- **Action** : keep — plan validé, prêt pour exécution.
