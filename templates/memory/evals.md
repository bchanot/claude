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

<!-- Append entries below. Template:

## EVAL-XXX - <output>

- **Date** : YYYY-MM-DD
- **Output** : <ce qui a été produit>
- **Méthode** : <comment cela a été évalué>
- **Anomalies** : <ce qui est faux, manquant, surprenant>
- **Action** : keep | correct | deprecate

-->
