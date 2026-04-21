# ARCHETYPE DETECTOR

Logique de détection d'archétype projet consommée par `/onboard` STEP 1.
Aucune exécution autonome — ce fichier documente l'algorithme que le skill applique.

---

## Inputs

1. Répertoire projet (cwd)
2. Résultat filesystem scan (manifests, structure, deps)
3. Liste des archétypes disponibles : `~/.claude/lib/project-archetypes/*.md` (hors `_TEMPLATE.md`)

## Algorithme

### PHASE A — Collect signals

Lire chaque archétype. Pour chaque archétype, charger les blocs :
- Strong signals (weight=3)
- Medium signals (weight=2)
- Weak signals (weight=1)

Types de signaux (syntaxe à matcher) :

| Syntaxe | Vérification |
|---|---|
| `FILE: <path>` | `test -f <path>` (relatif au projet root) |
| `DIR: <path>/` | `test -d <path>` |
| `STRING_IN_FILE: <path> contient "<pattern>"` | `grep -q "<pattern>" <path>` (fichier existe requis) |
| `DEP: <manifest> contient "<pkg>"` | parse manifest, vérifie clé `dependencies` OU `devDependencies` contient pkg |
| `EXT: N fichiers .<ext>` | `find . -name "*.<ext>" -not -path "*/node_modules/*" -not -path "*/.git/*" \| wc -l` → >= N |
| `TOOL: <cmd>` | `command -v <cmd>` existe |
| `REGEX: <path> matches "/<pattern>/"` | grep regex sur fichier |

### PHASE B — Score each archetype

Pour chaque archétype :

```
score_raw = Σ (signal_matched ? signal_weight : 0)
score_max = Σ signal_weight_total
score_pct = score_raw / score_max  (si score_max > 0, sinon 0)
```

Aussi compter `strong_hits` : nombre de strong signals matchés.

### PHASE C — Rank + select

Classer archétypes par `score_raw` décroissant.

**Règles de sélection** (dans l'ordre) :

1. **Un seul archétype avec score_raw ≥ 6 ET strong_hits ≥ 1** → SELECTED, confiance HAUTE.
2. **Top archétype dépasse le 2ème de ≥ 50% ET strong_hits ≥ 1** → SELECTED, confiance MOYENNE.
3. **2-3 archétypes avec scores proches (delta < 30%)** → AMBIGUOUS → demander à l'utilisateur.
4. **Aucun archétype avec score_raw ≥ 3** → UNKNOWN → demander manuellement ou partir d'un gabarit "generic".

### PHASE D — Composition

Certains projets sont combinés. Cas de composition détectés AUTOMATIQUEMENT :

- **WordPress + WooCommerce** : archétype `wordpress` + overlay `woocommerce` (si détecté)
- **Next.js + backend séparé dans monorepo** : plugin-advisor détecte déjà `monorepo`, on applique l'archétype par package
- **Astro + React islands** : archétype principal `astro-static`, noter la présence d'islands React dans les signaux
- **Drupal multi-site** : archétype `drupal` avec flag multisite

Ne pas inventer de compositions non listées.

---

## Output format

```
ARCHETYPE DETECTION
─────────────────────
Scores (top 5) :
  1. <name>  score: XX/YY (zz%) — strong: N, medium: N, weak: N  [SELECTED | CANDIDATE | REJECTED]
  2. ...

SELECTED     : <name>  (confiance : HAUTE | MOYENNE | BASSE | AMBIGU)
COMPOSITION  : <overlay si applicable, sinon "none">

JUSTIFICATION (signaux déterminants) :
  ✓ [strong] <signal>
  ✓ [medium] <signal>
  ✗ [strong] <signal> (attendu pour cet archétype, absent)

IMPLICATIONS AUTO-APPLIQUÉES :
  - public     : true | false
  - database   : required | optional | none
  - audit_stack: [liste]
  - plugins    : [recommandations]
```

Si AMBIGUOUS :

```
⚠️  ARCHÉTYPE AMBIGU — plusieurs candidats proches :
  A) <name>  score: XX (signaux: ...)
  B) <name>  score: XX (signaux: ...)
  C) <name>  score: XX (signaux: ...)
  D) None of the above — I'll describe it manually

Which one? (A / B / C / D)
```

Si UNKNOWN :

```
⚠️  AUCUN ARCHÉTYPE RECONNU
Je vois : <signaux détectés, ex : PHP files, no manifest, custom Makefile>
Questions manuelles :
  1. Quel type de projet ? (web / API / CLI / lib / desktop / mobile / game / firmware / autre)
  2. Public-facing (visible en recherche) ? (yes / no)
  3. Utilise une base de données ? (yes / no / depends)
  4. Stack principale ? (libre)
```

---

## Règles de robustesse

- **Ne jamais inventer un archétype** non présent dans `~/.claude/lib/project-archetypes/`.
- **Exclure** les dossiers `node_modules`, `.git`, `vendor`, `target`, `dist`, `build`, `.next`, `__pycache__` de tous les scans.
- **Timeout** : si un grep prend > 2s, l'abandonner et marquer le signal non-testé (ne compte pas dans le score).
- **Archétype non-monorepo** : si `monorepo` est détecté par plugin-advisor, passer la détection par package (un archetype par sous-package, pas un archetype global).

---

## Extension

Ajouter un nouvel archétype :
1. Créer `~/.claude/lib/project-archetypes/<name>.md` en respectant `_TEMPLATE.md`.
2. Tester avec `/onboard` en dry-run sur un projet connu de ce type.
3. Ajuster les weights si un signal s'avère trop discriminant/pas assez.

Retirer un archétype :
1. Supprimer le fichier.
2. Si des projets existants s'y référaient, migrer leur `CLAUDE.md` manuellement.
