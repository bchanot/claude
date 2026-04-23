---
type: decisions_registry
entry_prefix: BDR
schema:
  id: BDR-XXX
  date: YYYY-MM-DD
  title: string (<= 80 chars)
  decision: string (what was chosen)
  why: string (motivation, context)
  alternatives: list of strings (what was rejected + why)
  status: [proposed | accepted | deprecated | superseded]
  supersedes: BDR-XXX (optional)
rules:
  - Append-only. Never rewrite past entries - add a new one with status superseded if needed.
  - One entry per non-trivial choice. Trivial = reversible in under 10 min with no cross-file impact.
  - Capture why more carefully than what - the what rots, the why lasts.
---

# Decisions registry (BDR)

## Index

| ID | Date | Title | Status |
|----|------|-------|--------|
| BDR-001 | 2026-04-22 | --help helper uniforme via hook post-start (option C) | accepted |
| BDR-002 | 2026-04-23 | Restructurer tasks/ + memory + audits sous .claude/ | accepted |
| BDR-003 | 2026-04-23 | Gitignore pattern wildcard + négations pour .claude/ | accepted |

---

## BDR-001 — --help helper uniforme via hook post-start (option C)

- **Date** : 2026-04-22
- **Statut** : accepted
- **Décision** : tous les skills exposent `--help` via un snippet partagé injecté par le session-start hook, plutôt que dupliquer le helper dans chaque SKILL.md.
- **Pourquoi** : 25+ skills, maintenir le même helper dans chaque fichier = drift garanti. Un point d'injection = une seule source de vérité.
- **Alternatives rejetées** :
  - Option A (copier le helper dans chaque SKILL.md) — refusée : entropie de maintenance.
  - Option B (wrapper externe `/help <skill>`) — refusée : casse l'expérience "une commande = un skill".
- **Référence** : commit 3968a29.

## BDR-002 — Restructurer tasks/ + memory + audits sous .claude/

- **Date** : 2026-04-23
- **Statut** : accepted
- **Décision** : migrer `./tasks/` vers `.claude/tasks/`, créer `.claude/memory/` (5 registres BDR/LRN/BLK/journal/EVAL) et `.claude/audits/` pour les fichiers AUDIT_*. Adapter skills/agents/CLAUDE.md. Intégrer un rituel de capitalisation dans les skills de complétion (ship-feature, feat, bugfix, hotfix, commit-change) + créer un skill `/close` pour le rituel de fin de session.
- **Pourquoi** : regrouper tout le méta-projet (config IA + tâches + mémoire + audits) sous `.claude/` isole la gouvernance Claude du code réel. Alignement sur la doc officielle Claude Code memory. Sans intégration dans les skills, les registres resteraient vides (aspirational text).
- **Alternatives rejetées** :
  - Laisser `./tasks/` à la racine — refusée : encombre le repo, mélange signal code / signal gouvernance.
  - Utiliser `.claude/agent-memory/` pour tout — refusée : `agent-memory/` a un rôle distinct (déjà utilisé par d'autres outils).
  - Rituel uniquement en texte aspirationnel dans CLAUDE.md — refusée : zéro garantie d'exécution, les registres resteraient vides.
  - Hook `Stop` pour poser les 3 questions à chaque tour — refusée : trop bruyant.

## BDR-003 — Gitignore pattern wildcard + négations pour `.claude/`

- **Date** : 2026-04-23
- **Statut** : accepted
- **Décision** : utiliser `.claude/*` (wildcard match des enfants immédiats) + négations `!.claude/tasks/`, `!.claude/memory/`, etc., plutôt que `.claude/` (ignore récursif).
- **Pourquoi** : quand un parent est ignoré via `.claude/`, git n'entre pas dans le dossier (pour la perf) et les négations sur les enfants sont **ignorées** — c'est documenté dans `gitignore(5)`. Avec `.claude/*`, git match chaque enfant individuellement, ce qui rend les négations actives.
- **Alternatives rejetées** :
  - `.claude/` + `!.claude/tasks/` (naïf) — refusée : les négations n'ont aucun effet, tout reste ignoré.
  - Retirer `.claude/` du gitignore entièrement — refusée : `.claude/settings.local.json` et `.claude/agent-memory/` doivent rester ignorés (per-machine).
  - Ajouter les paths à tracker dans `.gitattributes` ou un outil externe — refusée : over-engineering, git gère nativement.
- **Référence** : commit `499cd07`, `git check-ignore -v` vérifié sur 4 paths (2 trackés, 2 ignorés).
