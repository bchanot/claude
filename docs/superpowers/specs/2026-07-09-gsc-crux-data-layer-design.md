# Spec — Couche data GSC + CrUX pour `/seo` (+`/geo`) FULL

- **Date** : 2026-07-09
- **Statut** : Design validé — prêt pour `/writing-plans`
- **Auteur** : Bastien Chanot (design assisté)
- **Repo** : claude-config (`~/Documents/claude`, symlinké dans `~/.claude` via `link.sh`)
- **Cycle de vie** : document de travail **transitoire** — à supprimer une fois la feature livrée,
  documentée (`/document-release` ou `/doc`) et capitalisée (`decisions.md`). Ne pas conserver à long terme.

---

## 1. Contexte & objectif

L'audit comparatif entre les skills perso `/seo` + `/geo` et l'outil marketplace
`agricidaniel/claude-seo` a isolé **un seul gap structurel** : les skills perso ne
peuvent pas lire la **donnée Google réelle** d'un site (requêtes/positions/impressions
de la Search Console, statut d'indexation, Core Web Vitals **terrain**). Ils se limitent
à l'API PageSpeed anonyme (données *labo*) et à `WebSearch`.

**Objectif** : combler ce gap **sans** installer l'outil tiers (860 KB de Python, mainteneur
unique, surface supply-chain + credentials OAuth à confier). On ajoute une couche data
minimale, isolée, sous contrôle, branchée sur les analyzers existants.

**Ce que ça débloque concrètement** :
- CWV **terrain** (CrUX, 75e percentile, mobile + desktop, historique) au lieu du seul labo.
- Requêtes GSC : le pattern « **positions 4-10 à fort volume d'impressions** » = quick wins
  que les skills ne pouvaient pas voir.
- Indexation réelle par URL (GSC URL Inspection) au lieu d'une déduction.

---

## 2. Principes directeurs (non négociables)

1. **Sécurité avant tout.** Secrets hors git, permissions `0600`, scope OAuth **lecture seule**,
   redaction systématique, aucun secret dans un rapport/log. Toute surface secret nouvelle sous
   `~/.claude` est **explicitement allowlistée** dans `.gitleaks.toml`.
2. **Dégradation gracieuse (fail-open audit).** Creds absents / token révoqué / quota 429 →
   l'audit FULL **continue** en retombant sur PageSpeed anonyme + une action utilisateur.
   Jamais de crash.
3. **Consentement OAuth one-shot, runs silencieux ensuite.** Le consentement navigateur ne se
   fait qu'au setup (ou à l'ajout d'un compte). Les audits suivants sont non-interactifs.
4. **Multi-compte, zéro conflit.** Plusieurs comptes Google connectables ; deux audits de deux
   sites en simultané sont **isolés par construction** (compte + propriété = paramètres explicites
   par appel, jamais un état global mutable).
5. **Isolation.** Le moteur ne connaît rien du SEO (rend du JSON) ; les analyzers ne connaissent
   rien d'OAuth (consomment du JSON). Deps Python isolées dans un venv dédié.

---

## 3. Décisions actées

| # | Décision | Choix |
|---|---|---|
| Auth GSC | OAuth2 installed-app, consentement one-time, refresh token stocké | **OAuth2** |
| Scope data v1 | GSC Search Analytics + URL Inspection + CrUX field | **oui** (GA4/Ads/Indexing hors v1) |
| Surface | Fold dans `/seo` (+`/geo`) FULL ; pas de nouveau skill d'audit | **oui** (setup = `make seo-connect`, pas un skill d'audit) |
| Langage | Helper Python + `google-auth`, venv isolé | **oui** |
| Multi-compte | Store keyé par compte ; sélection à **chaque** audit FULL | **oui** |
| Persistance token | Auto-écriture idempotente dans le store (write-temp→rename) | **oui** |
| Déclencheur consentement | `install.sh` (proposé) **et** `make seo-connect` (toujours dispo) | **oui, les deux** |
| Gitleaks | Allowlister le token store (comme `~/.claude/.env`) | **oui** |

---

## 4. Architecture

### 4.1 Vue d'ensemble

```
lib/seo-data/                        ← LE MOTEUR (nouveau, isolé, sans logique SEO)
├── fetch.sh          entrypoint bash : source ~/.claude/.env → active venv → dispatch
│                     sous-commandes → JSON sur stdout → dégrade proprement si creds absents
├── google_seo.py     appels GSC (Search Analytics, URL Inspection, sites.list) + CrUX,
│                     refresh OAuth via google-auth, normalisation JSON
├── connect.py        consentement OAuth one-time (InstalledAppFlow) + écriture store
├── tokenstore.py     lecture/écriture atomique du store keyé (partagé par connect+fetch)
├── requirements.txt  deps épinglées : google-auth, google-auth-oauthlib, requests
└── README.md         contrat d'usage + sous-commandes

~/.claude/.venv-seo-data/            ← venv isolé (deps hors système, reproductible)
~/.claude/seo-data/tokens.json       ← store keyé par compte (0600, hors git)

CONSOMMATEURS (existants, patchés) :
agents/seo-analyzer.md   STEP 4 (CWV) → data terrain CrUX quand dispo ; nouvelle
                         sous-section « Performance GSC » ; STEP 9 axe Technical nourri au réel.
skills/seo/SKILL.md      STEP 0 → sélection compte + propriété (main loop, interactif).
```

### 4.2 Composants & frontières

| Unité | Rôle unique | Utilisée comment | Dépend de |
|---|---|---|---|
| `fetch.sh` | orchestre env→venv→python, dégrade, redige | `bash fetch.sh <cmd> --account … --property …` → JSON | `~/.claude/.env`, venv, tokenstore |
| `google_seo.py` | appelle GSC + CrUX, normalise en JSON | appelé par `fetch.sh` | google-auth, requests |
| `connect.py` | consentement OAuth one-time + découverte propriétés | `make seo-connect` / STEP 0 | google-auth-oauthlib, tokenstore |
| `tokenstore.py` | I/O atomique du store keyé | importé par connect + google_seo | stdlib (json, os, fcntl) |
| seo-analyzer (patch) | consomme le JSON, score, rapporte | inchangé pour l'utilisateur | `fetch.sh` (optionnel) |
| seo/SKILL.md (patch) | sélectionne compte+propriété en STEP 0 | interactif, main loop | `fetch.sh accounts` |

---

## 5. Authentification & secrets (multi-compte)

### 5.1 Modèle OAuth

- **Type** : OAuth2 « installed app » (client Desktop créé dans la console GCP par l'utilisateur).
- **Scope unique** : `https://www.googleapis.com/auth/webmasters.readonly` (GSC lecture seule).
  Least privilege strict : le token ne peut **rien modifier** sur GSC, révocable côté Google.
- **Flow** : `connect.py` construit la config client **en mémoire** (`InstalledAppFlow.from_client_config`)
  à partir des vars d'env — **aucun `client_secret.json` sur disque**. Le consentement ouvre un
  serveur local + navigateur ; au retour, on obtient un `refresh_token` (durable) écrit dans le store.
- **Runs d'audit** : `google_seo.py` échange le `refresh_token` contre un `access_token` **éphémère
  en mémoire** (jamais persisté). Donc **aucune écriture disque pendant un audit**.

### 5.2 Vault `~/.claude/.env` (app partagée + CrUX)

Ne contient que ce qui est **commun à tous les comptes** :

```
# ── Google SEO data layer (lib/seo-data) ──
# App OAuth Desktop partagée (console GCP → APIs & Services → Identifiants).
# Scope demandé : webmasters.readonly. Setup : make seo-connect
GOOGLE_OAUTH_CLIENT_ID=<votre-client-id.apps.googleusercontent.com>
GOOGLE_OAUTH_CLIENT_SECRET=<votre-client-secret>
# Clé API CrUX + PageSpeed (console GCP → clé API restreinte à ces deux APIs).
# Get it: https://developer.chrome.com/docs/crux/api  (bouton "Get a key")
CRUX_API_KEY=<votre-cle-crux>
```

Les **refresh tokens ne sont PAS ici** (multi-compte → store dédié).

### 5.3 Token store keyé

`~/.claude/seo-data/tokens.json`, permissions `0600`, dossier `0700` :

```json
{
  "version": 1,
  "accounts": {
    "client-a": {
      "refresh_token": "<opaque>",
      "scopes": ["https://www.googleapis.com/auth/webmasters.readonly"],
      "granted_at": "2026-07-09T…",
      "properties": ["sc-domain:site-a.com", "https://www.site-a.com/"]
    },
    "client-b": { "…": "…" }
  }
}
```

- Clé = **label choisi par l'utilisateur** au moment du `connect` (ex. `client-a`), **pas** l'email.
  Raison sécurité : keyer par email obligerait à élargir le scope OAuth (`userinfo.email`) juste pour
  l'identification. On reste à `webmasters.readonly` strict ; le label suffit à distinguer les comptes.
  Collision de label → `connect` demande confirmation (écraser / renommer).
- `properties` = propriétés GSC accessibles (via `sites.list`, **déjà** dans le scope
  `webmasters.readonly`), pré-remplies au `connect` pour la sélection en STEP 0.
- Écriture **uniquement** au `connect` (jamais pendant un audit), **atomique** : write vers
  `tokens.json.tmp` → `fsync` → `rename` ; verrou `fcntl` exclusif le temps de l'échange
  read-modify-write pour couvrir deux `connect` simultanés.

### 5.4 Gitleaks allowlist + gitignore

- `~/.claude/seo-data/tokens.json` vit **hors du repo** (le repo ne symlink que
  `hooks agents skills lib templates rules`). Il n'entre donc jamais en git directement.
- Mais `make scan-secrets` (gitleaks) balaie `~/.claude` à la recherche de copies de secrets.
  On **ajoute une entrée d'allowlist** dans `.gitleaks.toml` `[allowlist].paths`, exactement
  comme `~/.claude/.env` l'est déjà :
  ```toml
  # Token store OAuth de la couche seo-data — secret local légitime (BDR-026 pattern),
  # hors git, 0600. On l'allowliste pour ne pas noyer scan-secrets de faux positifs.
  '''(^|/)\.claude/seo-data/tokens\.json$''',
  ```
- `.gitignore` : ajouter `.venv-seo-data/` et `seo-data/tokens.json` par prudence (au cas où un
  chemin relatif les ferait apparaître sous le repo), en complément de l'exclusion `.env*` existante.

---

## 6. Sélection de compte & propriété (STEP 0, main loop)

Interactif → se déroule **dans le dispatcher `/seo` (main loop)**, jamais dans le subagent
(qui ne peut pas interagir). Uniquement en **FULL** (LOCAL n'a pas de donnée live).

1. Lister les comptes connectés : `bash lib/seo-data/fetch.sh accounts` → JSON `{accounts:[…]}`.
2. Présenter à l'utilisateur (label + propriétés découvertes) :
   ```
   COMPTE GOOGLE pour cet audit FULL :
     1) client-a   (sc-domain:site-a.com, https://www.site-a.com/)
     2) client-b   (sc-domain:site-b.com)
     N) Connecter un nouveau compte (choisir un label)
     S) Ignorer (audit sans donnée GSC — CWV terrain via CrUX seulement)
   ```
3. « Connecter un nouveau compte » → demande un **label**, lance `connect.py` dans le main loop
   (consentement navigateur), puis auto-découverte des propriétés (`sites.list`) → re-liste.
4. Compte choisi → si plusieurs propriétés, demander **laquelle** correspond au site audité.
5. Le couple `(account, property)` retenu est passé **explicitement** dans le contexte de
   l'analyzer (bloc BUSINESS CONTEXT du dispatch, STEP 1), qui appellera
   `fetch.sh queries|inspect --account <a> --property <p>`.

CrUX ne demande pas de compte (clé API publique) → toujours tenté si `CRUX_API_KEY` présent,
indépendamment du choix de compte.

---

## 7. Sûreté concurrentielle (2 sites en parallèle)

Garantie **par construction**, pas par verrou global :

- **Pas d'état « compte courant ».** Le compte + la propriété sont des **arguments explicites**
  de chaque `fetch.sh`. Deux audits (2 sessions Claude, ou 2 sites) ne partagent aucune variable
  mutable de sélection.
- **Audits = lecture seule** du store. Les access tokens sont éphémères en mémoire, jamais écrits.
  Donc deux audits concurrents ne s'écrivent jamais dessus.
- **Écriture = seulement au `connect`**, atomique (`tmp`→`fsync`→`rename`) sous verrou `fcntl`,
  pour couvrir le cas rare de deux consentements simultanés.
- Le venv est en lecture seule à l'exécution (créé/maj uniquement par `make seo-connect`).

---

## 8. Périmètre data & mapping dans le rapport

| Donnée | Source | Sous-commande | Atterrit dans `SEO.md` |
|---|---|---|---|
| CWV terrain (LCP/INP/CLS 75e pct, mobile+desktop, historique) | CrUX API | `fetch.sh crux` | §2 Audit technique — **note primaire** ; PageSpeed labo gardé en secondaire diagnostic |
| Requêtes (impressions, clics, CTR, position) | GSC Search Analytics | `fetch.sh queries` | §2/§8 — sous-section « Performance GSC » + **quick wins position 4-10** |
| Pages (perf par URL) | GSC Search Analytics | `fetch.sh queries --dim page` | idem — top pages |
| Indexation par URL | GSC URL Inspection | `fetch.sh inspect` | §2 indexabilité — **fait** vs déduction |

- **Scoring** : l'axe *Technical* (STEP 9 de `seo-analyzer`) se calcule sur le **terrain** quand
  dispo ; sinon labo (dégradation).
- **Nouveau contenu de rapport** : une sous-section « Performance GSC (90 j) » dans §2, listant top
  requêtes + les quick wins position 4-10. Reste en **français**, cohérent avec l'existant.

---

## 9. Interface du moteur (`fetch.sh`)

Contrat stable que les analyzers consomment (JSON sur stdout, exit 0 même en dégradé) :

```bash
fetch.sh accounts
  → {"status":"ok","accounts":[{"email":"…","properties":[…]}]}
  → {"status":"empty"}                       # aucun compte connecté

fetch.sh crux    --url https://ex.com [--strategy mobile|desktop]
  → {"status":"ok","source":"crux","metrics":{"lcp_p75_ms":…,"inp_p75_ms":…,"cls_p75":…}, "history":[…]}
  → {"status":"degraded","reason":"no_crux_key"|"no_field_data"}

fetch.sh queries --account a@x --property sc-domain:ex.com [--days 90] [--dim query|page]
  → {"status":"ok","source":"gsc","rows":[{"key":"…","clicks":…,"impressions":…,"ctr":…,"position":…}]}
  → {"status":"degraded","reason":"no_credentials"|"token_revoked"|"rate_limited"}

fetch.sh inspect --account a@x --property … --url https://ex.com/page
  → {"status":"ok","source":"gsc","indexed":true,"coverage":"…","last_crawl":"…"}
  → {"status":"degraded","reason":"…"}
```

Règles : **jamais** de secret dans la sortie ; messages d'erreur génériques ; exit 0 en dégradé
(l'analyzer décide de la suite), exit ≠ 0 uniquement sur mauvais usage (args invalides).

---

## 10. Dégradation gracieuse & posture sécurité

- **Fail-open audit / fail-closed data** : creds manquants, refresh échoué, 429 → `{"status":"degraded"}`,
  exit 0. L'analyzer bascule sur PageSpeed anonyme et émet en §11 « Connecter GSC : `make seo-connect` »
  (réutilise la formulation `automation-catalog.md`).
- **Redaction** : `fetch.sh` ne logge jamais les variables d'env ni le token ; stdout = JSON de
  données uniquement ; stderr = messages génériques.
- **Least privilege** : scope `webmasters.readonly` seul ; clé CrUX restreinte à CrUX + PageSpeed.
- **Supply-chain maîtrisée** : 3 libs Google officielles, **épinglées** dans `requirements.txt`,
  isolées dans un venv — surface auditablement listée, sans commune mesure avec l'outil tiers.
- **Reprise sur token révoqué** : `doctor.sh` signale, message pointe vers `make seo-connect` pour re-consentir.

---

## 11. Install & déploiement (touch-list)

Séquence respectant l'ordre critique **`link.sh` → vault joignable → consentement** (évite le
blocker connu : le symlink `~/.claude/.env` est créé par `link.sh`, absent sur machine fraîche ;
tout lecteur de creds vise le **canonical `~/.claude/.env`**, pas `$REPO/.env`).

| Fichier | Modification |
|---|---|
| `.env.example` | Ajouter les 3 vars (client id/secret, CrUX key) au format existant (`# Used by:` / `# Get it:` + placeholder). **Seul fichier versionné touché côté secrets.** |
| `install.sh` | Après `link.sh` (§5) et `claude login` (§3) : étape **optionnelle idempotente** (moule « Press Enter to connect… ») → si aucun compte dans le store, propose `make seo-connect` ; skip sinon. |
| `Makefile` | Cible user-facing `seo-connect` : crée/maj le venv + `pip install -r lib/seo-data/requirements.txt`, lance `connect.py` (consentement + découverte propriétés). Rejouable. `make test` ramasse déjà le nouveau test. |
| `doctor.sh` | Nouveau check (lit `~/.claude/.env` canonical) : venv + deps présents ? au moins un compte dans le store ? `CRUX_API_KEY` présent ? → **PASS / WARN, jamais fatal**. |
| `.gitleaks.toml` | Allowlist du token store (cf. §5.4). |
| `.gitignore` | Ajouter `.venv-seo-data/` et `seo-data/tokens.json` (ceinture + bretelles). |

---

## 12. Tests

`lib/tests/seo-data.test.sh`, convention du repo (`tf`/`tr_`/`tn` + compteurs PASS/FAIL,
découvert par `make test`), **sans appel réseau** :

- Parsing des sous-commandes/args de `fetch.sh` (bons/mauvais usages, exit codes).
- Parsing de forme JSON sur **fixtures commitées** (réponses GSC/CrUX mockées) → shape attendue.
- **Redaction** : erreur simulée (token bidon) → aucune valeur secrète dans stdout/stderr.
- **Dégradation** : creds absents → `{"status":"degraded"}` + **exit 0** (pas 1).
- Isolement : deux invocations `--account` différentes → sélections indépendantes (pas d'état partagé).

Fixtures sous `lib/tests/fixtures/seo-data/` (réponses synthétiques, aucun vrai secret/PII).

---

## 13. Hors périmètre (YAGNI v1)

- GA4 (trafic organique), Google Ads / Keyword Planner, Indexing API.
- Modification de `geo-analyzer` (le GSC pourrait plus tard éclairer quelles requêtes déclenchent
  des AI Overviews — v2).
- Audit multi-propriétés en un seul run (une propriété par audit en v1).
- Monitoring/drift dans le temps (SQLite) — l'outil tiers le fait ; hors scope v1.
- Nouveau skill d'audit dédié `/gsc` (le setup passe par `make seo-connect`, l'usage par `/seo` FULL).

---

## 14. Liste des fichiers touchés

**Créés**
- `lib/seo-data/fetch.sh`
- `lib/seo-data/google_seo.py`
- `lib/seo-data/connect.py`
- `lib/seo-data/tokenstore.py`
- `lib/seo-data/requirements.txt`
- `lib/seo-data/README.md`
- `lib/tests/seo-data.test.sh`
- `lib/tests/fixtures/seo-data/*.json`

**Modifiés**
- `.env.example` (3 vars)
- `install.sh` (étape consentement optionnelle post-link)
- `Makefile` (cible `seo-connect`)
- `doctor.sh` (check creds non-fatal)
- `.gitleaks.toml` (allowlist token store)
- `.gitignore` (venv + token store)
- `agents/seo-analyzer.md` (STEP 4 CWV terrain + sous-section Performance GSC ; STEP 9 axe Technical)
- `skills/seo/SKILL.md` (STEP 0 sélection compte + propriété en FULL)
- `agents/resources/automation-catalog.md` (section « Google Search Console — connexion OAuth » réutilisable en §11)

**Hors repo (générés au setup, jamais commités)**
- `~/.claude/.venv-seo-data/`
- `~/.claude/seo-data/tokens.json`

---

## 15. Risques & mitigations

| Risque | Mitigation |
|---|---|
| Symlink `~/.claude/.env` absent sur machine fraîche | Lecture du **canonical** `~/.claude/.env` ; consentement **après** `link.sh` |
| Deux `connect` simultanés corrompent le store | Écriture atomique `tmp`→`rename` + verrou `fcntl` |
| Deux audits sur 2 sites se marchent dessus | Compte+propriété **explicites par appel** ; audits en lecture seule |
| Secret loggé par erreur | Redaction imposée + test dédié |
| Token store flaggé par scan-secrets | Allowlist gitleaks explicite (§5.4) |
| `python3`/venv absent | `doctor.sh` warn ; `make seo-connect` crée le venv ; dégradation si absent |
| Quota GSC/CrUX (429) | Traité comme `degraded` → audit continue |

---

## 16. Questions ouvertes résolues

- **Scopes** → `webmasters.readonly` seul.
- **CrUX vs PageSpeed** → les deux : CrUX terrain primaire, PageSpeed labo secondaire/fallback.
- **Forme data en §2** → terrain 75e pct primaire, labo en secondaire.
- **GSC obligatoire ?** → non, optionnel, dégradation gracieuse ; proposé à chaque FULL.
- **Token expiré** → `degraded` + `doctor.sh` pointe `make seo-connect`.
- **Locale** → rapports en français, cohérent avec l'existant.
- **Multi-compte** → store keyé par **label utilisateur** (scope inchangé) ; sélection par audit ;
  isolation par arguments explicites.
```
