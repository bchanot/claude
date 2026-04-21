---
name: <archetype-id>
category: <cms | static | framework | api | cli | library | mobile | desktop | game | embedded | monorepo>
public: <true | false>  # public-facing website (SEO/GEO relevant)
database: <required | optional | none>
hosting_hints:
  - <shared | vps | managed | vercel | netlify | cloudflare-pages | docker | k8s | app-store>
audit_stack:
  - analyze        # dette technique (toujours)
  - code-clean     # style/dead code (toujours)
  - seo            # uniquement si public: true
  - design-review  # uniquement si UI présente (frontend / frontend-in-CMS)
  - perf           # lighthouse + bundle analyzer
  - cso            # sécurité — toujours recommandé si DB, auth, deps externes
  - a11y           # accessibilité — uniquement si UI
  - doc            # drift docs
plugins:
  context7: <yes | no | optional>        # utile si fast-libs dans l'archétype
  ui-ux-pro-max: <yes | no | optional>   # si frontend
  gstack: <yes | no | optional>          # si site déployable navigable
---

# <Archetype Name>

## Detection signals

**Logique OR — toute combinaison ci-dessous = CANDIDAT.**
Le score final pour cet archétype = `matches / total_signals`. Plus un signal est rare/spécifique, plus il est discriminant.

### Strong signals (score × 3) — quasi-unique à cet archétype
- `FILE: <chemin exact>` — description
- `STRING_IN_FILE: <fichier> contient "<pattern>"`
- `DEP: <manifest> contient "<package>"`

### Medium signals (score × 2)
- `FILE: <chemin>` — description
- `DIR: <dossier>/`

### Weak signals (score × 1) — non discriminants seuls
- `EXT: N fichiers .<ext>`
- `TOOL: <commande> disponible`

## Implications

Liste ce que cet archétype implique automatiquement, sans questionner l'utilisateur :
- Hébergement probable : ...
- Base de données : requise / optionnelle / aucune
- SEO/GEO : critique / important / N/A
- Surface sécurité : large / moyenne / petite
- UI/UX : critique / important / aucune

## Typical pain points

Problèmes typiques que l'audit DOIT chercher pour cet archétype :
- ...
- ...

## Interview questions (adaptive)

Questions à poser EN PLUS du set minimum business (users, stade, deadlines, équipe, légal, perfs).
Chaque question a un hint `[if: <condition>]` si elle ne s'applique que conditionnellement.

- Question 1 ?
- Question 2 ? `[if: public=true]`
- Question 3 ?

## Plugin recommendations

Rationale court pour chaque plugin recommandé ou désactivé pour cet archétype.

## Example project layout

```
<tree minimal pour reconnaître l'archétype à l'œil>
```
