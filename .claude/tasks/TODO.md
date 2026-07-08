# TODO

## 2026-07-08 — full back-merge release/1.0.0→develop (chore/backmerge-release-full)
Genèse : la revue avait porté ~5/19 commits ; back-merge complet demandé. Cherry-pick par
catégorie, 1 commit atomique/item, make test après chaque code. Branche non mergée (gate humain).
- [x] A CODE (5 cherry-picks, make test GREEN chacun) : 095d881 drop find-skills (5a1fff5),
      a1093ca TTY-guard make-update (ce07e55, prouvé EOF exit1→exit0), 4c5e862 rtk version-guard
      (3049250, complète le pont e58037c déjà porté — fichiers/concerns distincts), c76479f
      design-motion sync (82ce02c), e65796f SC1091 lint (fcdb157, shellcheck 0 SC1091).
- [x] B JOURNAL : cherry-pick direct conflicte (tails journal divergents) → STOP honoré,
      fallback note consolidée sous journal 2026-07-08. TODO /deploy ca9fa8f skip (release-specific).
- [x] C DÉCISION/DOUBLON tous skip vérifiés : 93e43c0 attribution + ae8ad86 model (opus[1m]=Opus4.8)
      déjà sur develop ; a623514/74d3804/2b4e740 registres déjà backfillés (run revue) ;
      188a9a7 docs → backlog /doc ci-dessous.
- [x] D fork version 1eb5b08/eb93050 intouchés — version.txt reste 4.0.0.
- [x] GATE FINAL : 23/23 commits release-only classifiés, 0 code orphelin, 0 entrée registre
      manquante ; make test GREEN + review-guards 5/0. Capitalize [[LRN-117]] structurel.

### Backlog (issu du back-merge)
- [ ] **/doc** — README develop ne documente pas semgrep / scan-secrets / verify+secure pipeline /
      ctx7 (delta de 188a9a7, non porté car base README divergente job3 + CHANGELOG version-entangled).
      Une passe /doc doit combler ces sujets sur le README réécrit de develop.
- [ ] **release-drift advisory** ([[LRN-117]]) — check qui liste les commits `develop..release/*`
      touchant du CODE fonctionnel (exclut merges, `.claude/**`, version.txt/CHANGELOG) pour revue
      de back-merge. Advisory, PAS un gate make-test dur : les cherry-picks landent avec de nouveaux
      SHA → le commit source reste dans le range → équivalence "déjà porté ?" non fiable automatiquement
      (faux positifs). Cible : étape release-finish ou /reconcile, pas run-review-guards.

## 2026-07-08 — review remediation (chore/review-remediation)
Genèse : `.audit/review-release-1.0.0.md` (revue adversariale des 9 jobs). GO user,
ordre imposé. Déviation justifiée : 1 branche (pas 1/EP) car le gate fil-rouge (step 6)
grep toute la surface et n'est vert qu'avec A1/A4/A5 déjà appliqués. Commits atomiques,
branche non mergée (gate humain). EP-A3/A6 = décisions user tranchées (combler / option b).
- [x] EP-A1 (BLOQUANT) trailer bugfixer/feater/hotfixer (56018df) + grep étendu = 0 autre
- [x] EP-A2 (P0) hook réinstallé gitleaks (d4526e6) + 3 gates verts + root-cause (générateur édité, jamais réinstallé)
- [x] EP-A4 quote YAML seo-analyzer:3 + security-auditor:3 (5a0fc16) + gate yaml.safe_load tous agents
- [x] EP-A5 geo own-policy PERMISSIVE (f0111e1), user-approved, grep==0
- [x] EP-A8 smoke /seo+/geo réel PROUVÉ — AUTO llms.txt + sitemap.xml atterrissent sur disque (no-op infirmé)
- [x] FIL-ROUGE run-review-guards.sh 5 gardes (4e83f39), user-approved, à dents
- [x] EP-A3 backfill LRN-098/101 (7cd82cf/a01250b) + EVAL-015 (38cc821) + BLK-016 (8e9ff33) + PORT rtk e58037c (416b68f) car fix absent+bug live sur develop
- [x] EP-A6 (option b) seuil 280→320 + BDR-062 (1be9036)
- [x] EP-A7 documentaire + M5 → EVAL-022 (capitalize cc4f161)
- [x] Capitalize LRN-113/114/115/116 + BDR-062 + EVAL-021/022 + journal (cc4f161)
- [x] GATE FINAL : make test GREEN (exit 0) + A2 secret BLOCKED (gitleaks) + A8 AUTO landed + review-guards 5/0
- Branche chore/review-remediation NON mergée (gate humain). Résidu noté : e65796f (SC1091 lint) non back-mergé, hors scope.

## 2026-07-08 — job9 sub-agent architecture corrections (chore/job9-agents)
Genèse : `.audit/job9-report.md` (agents/*.md frontmatter+body, verify-loop,
dispatch graph, read-only). Premise correction confirmed CC v2.1.203 : nesting
SUPPORTED since v2.1.172, cap 5, `Agent` tool required in `tools:` to nest.
User decision: **path b (version-robust)** for the version-floor. One commit/item.

PART 1 — MISROUTED (trivial frontmatter):
- [x] A — commit-changer: drop unused `Agent` from tools (0ede52c)
- [x] B — verifier: pin `model: sonnet` (ea6c126)
- [x] C — security-auditor: pin `model: sonnet` (1c270e6)
- [x] D — plugin-advisor: `haiku` → `sonnet` (5ab6c21)
- [x] GATE P1 — smoke green: verifier CONFORME, sec-auditor BLOCK(2), advisor
      ACTION REQUIRED; verdict grammar intact, mode honored. No revert.

PART 2 — VERSION-FLOOR (path b) — CONTRACT APPROVED, DONE:
- [x] 5 — seo+geo analyzers → fix-bundle→L1 (a5a7b54/6df42e4); /seo STEP 1.5
      (c498b93), /geo dispatch+apply (70fb3b4), dispatcher tier-tolerance
      (212f9aa); /harden already path-b (untouched), /onboard audit-only
      (untouched). GATE PASSED: make test green + 4 smokes (A bundle-no-edit,
      B AUTO lands on disk no-confirm, C GATED withheld→applied post-accord,
      D onboard report-only zero-fix).
- [x] 6 — BDR-060 orchestration floor v2.1.172 supersedes implicit v2.1.83
      premise (BDR-004:133 kept — auto-mode floor, append-only + factually
      correct). BDR-061 path-b doctrine.
PART 3 — IMPLICIT-HANDOFF (tight scope, 2 sites) — DONE:
- [x] 7 — H2 INLINE-LOAD verb @ code-cleaner + scaffolder (87d63bf/af9656f),
      drop unused Agent from code-cleaner
- [x] 8 — H1 code-cleaner→refactorer named artifact .claude/audits/CODE-CLEAN-SCOPE.md

Capitalize DONE: LRN-112 (nesting) + BDR-060 (floor) + BDR-061 (path-b) + journal.
- [x] commit-changer template Co-Authored-By stripped (5a3de92, isolated) —
      contradicted no-attribution ban since creation
- [ ] FOLLOW-UP next cycle: cross with J4-16 (lib-layer lock) — verify no other
      agent/template carries a banned attribution trailer (Co-Authored-By/
      Claude-Session/--trailer)
Branch unmerged, human gate.

## 2026-07-07 — job8 third-party security hardening (chore/job8-hardening)
Genèse : `.audit/job8-report.md` (magic MCP/plugins/gstack/external skills/trust
chain, read-only). A/B/C/D exécutés (3 commits), branche non mergée, gate humain.

- [x] A — `permissions.ask` += 4 `mcp__magic__*` tools, allow reste vide (BDR-059)
- [x] B — component_builder couvert par A ; risque documenté README + LRN-110
- [x] C — darwin-skill réinstallé pinné (tree complet, HEAD détaché SHA
      7c7b790), git-commit large-scope documenté comme risque accepté (pas de
      patch sur code tiers pinné) — BDR-058, LRN-109
- [x] D — pr-review-toolkit / example-skills inchangés, confirmé

- [ ] Re-audit surfaces C/D (ui-ux-pro-max, autres plugins) — single-observer
      CLEAN sans passe verifier (Fable-5 épuisé mi-job8), à re-vérifier au
      prochain cycle d'audit sécurité si le scope magic/darwin revient.
- [ ] MAGIC_API_KEY rotation toujours en attente (résiduel job7, non job8)

## 2026-07-07 — job7 secrets: triage backstops (chore/job7-secrets)
Genèse : `.audit/job7/ALL-REDACTED.json` (triage secrets multi-repo + ~/.claude).
GITEA_TOKEN déjà rotaté (transcript 960bd2cf). MAGIC rotation prévue après (A).
Fixtures git-game #5/#6 confirmées synthétiques (test-secret-*). Règle : jamais
manipuler une valeur de secret — edits sur les mécanismes seulement.

- [x] A.1 Provenance MAGIC_API_KEY dans `~/.claude.json` : confirmée —
      seul writer = `lib/toggle-external.sh:191` (`claude mcp add magic --scope
      user --env API_KEY="$MAGIC_API_KEY"`), appelé par `install-plugins.sh`
      (jamais un `claude mcp add` direct). Aucun autre writer (grep repo-wide).
- [x] A.2 Doc Claude Code (agent claude-code-guide) : `${VAR}` supporté dans
      `env`/`command`/`args`/`url`/`headers` de mcpServers, y compris scope
      user (`~/.claude.json`). Pas de `envFile`, pas de flag `mcp add` pour une
      référence — édition manuelle requise. Voie SUPPORTÉE retenue.
      Décision utilisateur : wiring `MAGIC_API_KEY` → wrapper `claude()` scopé
      dans `~/.bashrc` (source `.env` en subshell, jamais exporté globalement)
      plutôt qu'un export global (surface minimale, cohérent BDR-026).
  - [x] `~/.bashrc` : fonction `claude()` wrapper (subshell source ~/.claude/.env,
        exec — vérifié : la var n'atteint QUE le subshell/exec, jamais le shell
        parent). Hors repo (dotfile perso).
  - [x] `~/.claude.json` mcpServers.magic.env.API_KEY → `"${MAGIC_API_KEY}"`
        (diff keys-only montré avant écriture ; jq surgical edit, jamais Read
        direct — la valeur n'a jamais traversé mon contexte). Backup fait
        pendant l'édition supprimé aussitôt vérifié (aurait été un 6e leak).
  - [x] `lib/toggle-external.sh:191-192` — `--env 'API_KEY=${MAGIC_API_KEY}'`
        (référence littérale, single-quoted). `claude mcp add` direct au flag
        bloqué par le classifieur auto-mode (self-modification non sollicitée,
        respecté) — non testé live ; `claude mcp list` confirme la syntaxe
        est bien reconnue ("Missing environment variables: MAGIC_API_KEY" —
        attendu, cette session a démarré avant le wrapper bashrc).
  - [x] Doc README : section "Adding an MCP server that needs a secret" +
        piège `--env` + pattern wrapper à copier
  - [x] Vérif manuelle : `claude mcp list` (read-only) — magic reconnaît
        `${MAGIC_API_KEY}`, encore connecté (session pré-existante) ; nécessite
        un restart terminal (source ~/.bashrc) + Claude Code pour confirmer
        end-to-end — **résiduel, à faire par l'utilisateur**
- [x] A.3 Scrub backups `.claude.json.backup.*` — les 5 originaux (78af0e36 @
      job7 triage) déjà auto-rotés (ring-buffer natif) ; des 5 COURANTS, 2
      encore en clair (créés avant le fix, pendant cette session) → scrubbés
      jq (mode 600 restauré, changé par erreur via mv). grep 78af0e36 : 0 hors
      `.env` (backups + .claude.json confirmés propres).
- [ ] A.4 Signaler à l'utilisateur : rotation MAGIC maintenant (après commit A)
- [x] B. Redaction dumps d'env — `hooks/rtk-rewrite.sh` étendu : pipeline simple
      (pas de `;`/`&`/`||`) + `printenv`/`env` en tête sans `VAR=... cmd` derrière
      → append `| sed -E 's/^([A-Za-z_]*(TOKEN|API_KEY|SECRET|PASSWORD|PASSWD)
      [A-Za-z_]*)=.*/\1=REDACTED/'`. `env VAR=x cmd` intact. Compound bail
      (`;`/`&`/`||`) — jamais de pipe attaché au mauvais segment.
  - [x] `lib/tests/rtk-rewrite.test.sh` — 3 cas + garde compound
  - [x] `make test` vert (96/96 gitflow-test + suite complète)
- [x] C. Backstop gitleaks (8.30.1 confirmé installé — `protect` non listé
      dans `--help` mais fonctionne encore ; `gitleaks git --staged` =
      sous-commande documentée retenue à la place)
  - [x] `.gitleaks.toml` racine — allowlist 3 classes job7 (vérifiées
        empiriquement contre les vrais fichiers : marketplace.json sha
        40-hex, ws-protocol nonce, test-secret-[0-9-]+) + 4e entrée
        `(^|/)\.env$` (pas un faux positif — c'est le vault canonique
        BDR-026 ; exclu du bruit, pas de la détection)
  - [x] pre-commit gitflow (`lib/gitflow.sh` `_gitflow_emit_pre_commit`) —
        `gitleaks git --staged` après guard root/merge, non-bloquant si absent
  - [x] `lib/gitflow-test.sh` T16 — faux secret (AKIA random) sur feature
        branch → bloqué ; commit propre passe ; PATH sans gitleaks → warn
        + pass. 96/96 vert.
  - [x] `make scan-secrets` — repo (git history) + dir ~/.claude, redacted
        JSON → `.audit/` (`--redact` vérifié : Match/Secret redacted dans
        le report, pas juste les logs). Repo : 0 (attendu). ~/.claude : 18
        hits restants, 8 fichiers — voir D (5 déjà dans le triage job7,
        3 NOUVEAUX non couverts par la spec initiale, à trancher)
- [x] D. Purge (GO explicite par item) — état réel après `make scan-secrets` :
  - [x] transcript 960bd2cf…jsonl (generic-api-key, GITEA déjà rotaté) — GO
        utilisateur → rm fait
  - [x] `ide/27929.lock` — déjà rotée toute seule (fichier absent, session
        finie). REMPLACÉE par `ide/20429.lock` (NOUVEAU, session active en
        cours) — NE PAS rm (verrou live) ; candidat allowlist de classe
        (`ide/*.lock` structurel, pas un secret) si le pattern se confirme
  - [x] `cleanupPeriodDays` — champ confirmé exact (agent claude-code-guide,
        code.claude.com/docs/en/settings.md) : défaut 30, min 1, scope doc
        = "session files" (transcripts + orphaned subagent worktrees) —
        PAS explicitement backups/file-history/paste-cache (gap doc, donc
        ne remplace pas les scrubs manuels A.3/D). Diff montré, confirmé
        via AskUserQuestion (1er essai bloqué par le classifieur auto-mode :
        diff affiché en texte ne vaut pas confirmation explicite — correct)
        → `settings.json` 30→7 appliqué.
  - [x] **NOUVEAU (hors spec initiale, découvert par `make scan-secrets`)** :
        `paste-cache/7d48f52c7499c1a7.txt` (sourcegraph-access-token, 2) —
        GO utilisateur ("Claude rm maintenant") → rm fait, jamais lu.
        Transcript `f1c9c474-...jsonl` (generic-api-key, 8) — PAS choisi
        par l'utilisateur parmi les options (auto-inspect / TODO / rm) →
        **laissé intact, à trancher** ; ni lu ni caractérisé (règle job7).
  - [x] **NOUVEAU (bruit, pas un item D)** : transcript de CETTE session
        (`4b5c02a9-...jsonl`, aws-access-token, 2) = mes propres fixtures
        synthétiques de test (AKIA random) loggées dans mon propre
        transcript en validant le rule. Pas un vrai secret, rien à purger.
- [ ] Gate final : `make test` + `make scan-secrets` propre + table
      étape/commit/gate + capitalize (BDR secrets-par-référence, MAJ BDR-026,
      LRN piège `claude mcp add --env`). NOTE : `make scan-secrets` sur
      ~/.claude ne sera pas "propre" tant que `f1c9c474-...jsonl` (8 hits,
      non tranché) reste — résiduel connu, pas un échec du job.

## 2026-07-05 — /deploy UX patch (feature/deploy-next-style)
Feedback user au 1er run réel (bchanot-cv, [[EVAL-016]]) : NEXT.sh une commande
par ligne (style session — ssh ouvre la box, la suite s'exécute dessus, local =
"(from your machine)") + hand-back AFFICHE la checklist inline (aussi aux
re-hand-back). Step = bloc (header + lignes jusqu'à ligne vide), @delta
gouverne le bloc entier.
- [x] skills/deploy/SKILL.md — grammaire bloc-étape + shape rule + print inline
- [x] templates/deploy/PROCEDURE.md — restylé session
- [x] bchanot-cv runbook restylé, committé, pushé (bd7f6e4, develop sync)
- [x] settings.json +inputNeededNotifEnabled (layout committé inchangé)
- [x] Capitalize EVAL-016 + journal
- [x] Re-dogfood run 2 (résidus bchanot-cv) : le print inline AVANT
      AskUserQuestion ne s'affichait PAS → leçon [[LRN-102]] (texte avant un
      tool call peut ne jamais rendre ; le dernier texte du tour est le seul
      affichage garanti)
- [x] PASS 2 (feature/deploy-inline-checklist) : checklist DISPLAY-ONLY —
      plus de fichier NEXT.sh du tout (jetable, PENDING+runbook régénèrent
      partout) ; hand-back TERMINE le tour par la checklist, aucun tool call
      après ; resume à froid = régénère + ré-affiche. Skill+template+CHANGELOG.
- [x] Re-dogfood pass 2 VALIDÉ (deploy run 2, b24c58b marqué 2026-07-05-2) :
      checklist copiée depuis la conversation, deploy OK, CSP hash live sans
      unsafe-inline. Resume à froid + STEP 4 (learn) toujours vierges

## 2026-07-05 — impeccable install chain (feature/impeccable-install)
Décision (user a délégué) : COMPLÉMENTAIRES → les deux. frontend-design garde
la direction esthétique au build ; impeccable (pbakaus, 43.6k⭐, Apache-2.0,
actif) apporte l'UNIQUE manquant : 45 règles déterministes anti-slop (CLI
`impeccable detect`, exit 0/2, --json — le semgrep du design, doctrine
backstop-déterministe) + 23 verbes sous UN skill (/impeccable) + contexte
design persistant (DESIGN.md/PRODUCT.md). Faits vérifiés : npm CLI 3.2.0
(skill dist = track séparé), `skills install -y --providers=claude
--scope=project --no-hooks`, **Node ≥ 24 requis (hôte = 22.22)** → step
fail-soft + décision bump Node à l'user. Classifier a bloqué npx (code tiers)
→ dogfood via `make plugin` côté user.
Pattern : ctx7/machine-owned (skills-external/impeccable gitignoré, synced
par installeur, symlinké par link.sh EXTERNAL_SKILLS, profils type external).
PAS en GATE-BLOCK design.profile tant que Node<24 + pas dogfoodé.
- [x] plugins.lock.json — entry impeccable pin 3.2.0
- [x] install-plugins.sh — Step 8d staged npx install → skills-external
- [x] update-all.sh — step miroir pin-honored (Node<24 → skip, dist gardée)
- [x] link.sh — EXTERNAL_SKILLS += impeccable
- [x] .gitignore — skills/impeccable + skills-external/impeccable/
- [x] profils design/web/web-full/full — impeccable external (show design →
      « impeccable missing » = statut honnête pré-install)
- [x] plugin-advisor.md + CLAUDE.md Design work + lib/design-gate.md
- [x] README table + CHANGELOG Unreleased
- [x] Verify — bash -n ×3 OK, shellcheck clean (SC1091 info only), lock JSON
      valide, profile parse OK. Dogfood DIFFÉRÉ : classifier bloque npx code
      tiers en auto-mode → user lance `make plugin` (une fois Node ≥ 24)
- [x] Bump Node baseline 22→24 LTS (install-plugins Step 1, 24cce6a) — la
      dépendance dure est résolue à l'install, plus une décision différée
- [ ] Follow-up (hors scope) : doctor.sh check (fichier gardé) ; GATE-BLOCK
      promotion après dogfood ; dogfood réel = prochain `make plugin`

## 2026-07-04 — skill /tour (tir groupé multi-projets, feature/tour-skill)
Goal: 1 orchestrateur = clean-code + sécurité (security-auditor/semgrep [+cso si
gstack ON]) + reconcile + doc, mode auto, sur 1..N projets. Boucle de convergence
(fixes peuvent invalider l'audit précédent) BORNÉE 3× (LRN-083). Build via
superpowers:writing-skills (TDD, pattern audit-delta/reconcile) + guidance
skill-creator (structure, description trigger-pushy).
Design verrouillé :
- auto = fixes committés sur `chore/tour-<date>` par repo (gitflow lib), JAMAIS
  finish/merge (signal humain only). Tree sale ou pas de develop → report-only.
- ordre par repo : sécurité → clean → re-verify (checks projet, fail=revert
  fail-closed) → reconcile (REPORT-ONLY, jamais d'auto-coche TODO) → doc
  (mode silencieux doc-syncer) → re-audit convergence.
- convergence = 1 passe complète à zéro finding nouveau + checks verts ;
  sinon re-boucle, max 3 itérations, résidus rapportés honnêtement.
- rapport `.claude/audits/TOUR.md` par repo + synthèse inline multi-repos.
- registres : offre capitalize gatée en fin, jamais silencieux.
- [x] RED : fixture repo → baseline SANS skill. 6 gaps : TODO cible ré-écrit
      silencieusement ; registres écrits de façon autonome ; sécu = grep ad-hoc
      sans semgrep ; zéro rapport persistant ; scope creep (.gitignore +
      registres bootstrap) ; boucle sans borne déclarée. (Bien fait : branche
      gitflow via lib, pas de merge, commits atomiques, convergence passe 2.)
- [x] GREEN : skills/tour/SKILL.md — run avec skill sur fixture-green,
      6/6 gaps fermés VÉRIFIÉS sur disque (TODO zero-diff, 0 registre,
      semgrep chaque itération, TOUR.md committé 18 findings, 0 scope
      creep, 3 it. bornées convergées, chore branch non mergée)
- [x] REFACTOR : 2 trous du GREEN patchés (scratch semgrep non trackés →
      auto-blocage du prochain run, STEP 3.2 cleanup ; fix sécu cassant
      non signalé → tag BREAKING structurel dans template). Additions
      template-structurelles NON re-testées par un 3e run complet (coût) —
      re-test au premier usage réel.
- [x] Routage CLAUDE.md (ligne « Grouped all-axes sweep → tour »)
- [x] Commit branche + capitalize (BDR-052, LRN-099/100, EVAL-014, journal)
- [x] GO user 2026-07-05 : merge develop + release/1.0.0 ; settings.json
      restauré (Opus 4.8 1M défaut, backstop attribution conservé)

## 2026-07-03 — verify loops + semgrep gate + contract (chantier orchestrateurs)
Archi validée au gate (session 2026-07-03). Cible : contract sur DISQUE dès
création (fichier de run, pattern DIAGNOSIS) + verifier frais (verdict structuré
CONFORME/écarts, preuve-qu'il-a-regardé LRN-048, 2 échecs structurels = escalade
humaine — verifier muet ≠ PASS) + gate sécu semgrep (rulesets ÉPINGLÉS
p/security-audit + p/secrets — pas --config auto, classe LRN-077 ; BLOCK
HIGH/CRITICAL only, LRN-047) + boucles bornées 3× décidées en boucle principale
(LRN-083). cso = symlink submodule gstack → non modifiable → greffes locales
(onboard cso-fallback, audit-delta, agent neuf ; complément semgrep même
gstack ON). Verdicts user : dev inline conservé feat/bugfix/hotfix (verify+sécu
= sous-agents frais) ; hotfix garde revert-escalade ; PIN version semgrep dans
plugins.lock.json (gate bloquante — upgrade silencieux = nouveaux BLOCK sur code
inchangé ; pattern gsd-pin, saut affiché par update-all).

LOT 1 — feature/semgrep-install (GO)
- [x] plugins.lock.json — pin semgrep 1.168.0 (pattern gsd, note gate bloquante)
- [x] install-plugins.sh STEP 7.5 — pipx pinned, command -v guard + version echo, login guide-only (jamais auto)
- [x] update-all.sh step 6.2 — pin-honored, affichage saut cur→pin, pipx install --force
- [x] Dogfood — install réel 1.168.0 via bloc extrait + idempotence (re-run = skip) + pin-match + saut affiché (1.168.0→9.9.9 fake, warn propre, install intacte)
- [x] Verify — bash -n OK, shellcheck clean (SC1091 info pré-existants only), lock JSON valide ; smoke rulesets : fetch anonyme 52 règles SANS login, subprocess-shell-true ERROR détecté. Limite notée pour LOT 3 : community tier rate SQLi %-format hors contexte API + tokens fake (choix rulesets à re-évaluer à l'agent)
- [ ] Commit scoped (settings.json dirty pré-existant JAMAIS stagé) + GATE lot 1

LOT 2 — feature/contract-verifier : specs montrées AVANT écriture. lib/contract-interview.md + agents/verifier.md.
LOT 3 — feature/security-auditor : agents/security-auditor.md + greffe audit-delta + onboard fallback + complément gstack-ON.
LOT 4 — feature/loops-light : câblage feat/bugfix/hotfix.
LOT 5 — feature/loops-heavy : câblage ship-feature + init-project + onboard.
Rien poussé ; gate par lot ; suites après chaque lot.

## 2026-07-03 — design-toolchain trigger fix (bugfix/design-toolchain-trigger)
Root cause (NOT a kill-switch, per user): ed2408e (07-02) dropped ultra-generic
tokens but left bare tokens common in non-UI talk → ~6× false-fire THIS session
(design, dashboard via ecc_dashboard.py, component, frontend, theme, transition,
palette). Fix = tighten the trigger only + a fire-log counter for measured
re-fire decisions.

- [ ] hooks/design-toolchain-reminder.sh — drop bare design|component|composant|theme|thème|transition|frontend|front-end|palette; dashboard→\bdashboard\b; keep animation; add "front-?end design" bigram; + fire-log (time+token+excerpt)
- [ ] lib/tests/design-toolchain-reminder.test.sh — 8 dropped tokens quiet; button/navbar/landing/glassmorphism/redesign/"frontend design"/"admin dashboard"/animation fire; ecc_dashboard.py quiet; fire logged
- [ ] Verify — shellcheck + bash -n + test PASS + live dogfood (hook now quiet on session tokens)
- [ ] GATE before finish (user); sentinel one-shot to edit the now-guarded hook

## 2026-07-03 — config-protection hook (feature/config-protection-hook)
Goal: PreToolUse hook blocks Edit/Write to this config's quality-gate files
(guardrails an agent must not weaken to make an error pass). Adaptation from ECC
second-look (BDR-047 corrob, Opus 4.8 re-audit) — MY idiom (~15-line bash), NOT
ECC's Node dispatcher. Extends config's own doctrine ("backstops déterministes
car l'advisory s'oublie"). Guarded: settings.json (+ .claude/settings*.json),
lib/gitflow.sh, .githooks/*, doctor.sh, lint configs (preemptive, absent today).
Bypass: CONFIG_EDIT_OK="reason" (logged). Mid-session env caveat flagged at gate.

- [x] hooks/config-protection.sh — case-match guarded path, exit 2 else 0; fail-open
- [x] Guarded: settings.json(+.claude/settings*), lib/gitflow.sh, .githooks/*, doctor.sh, hooks/*.sh (self-guard), lib/tests/* (T6c/LRN-077), lint (preemptive)
- [x] Bypass: one-shot sentinel .claude/.config-edit-ok (non-empty reason, logged+consumed) — NOT env-var (launch-time env = set-and-forget = garde mort)
- [x] lib/tests/config-protection.test.sh — block/allow/self-guard/near-miss/fail-open/sentinel-one-shot/empty-refuse (17 checks)
- [x] settings.json — register PreToolUse matcher Edit|Write|MultiEdit -> hook
- [x] Verify — shellcheck clean + 17/17 PASS + bash -n + bootstrap-safe (hook fires on Edit/Write only, not shell cp/ln)
- [x] GATE passed — guarded list +2 (hooks/, tests/), sentinel over env-var
- [ ] Capitalize (BDR-047 corrob + LRN-090 câblé>déclaratif) + finish this branch only

## 2026-06-23 — install self-sufficient + gstack on-demand par profil
Goal: `make install`/`make plugin`/`make update` installent TOUT sans étape
manuelle. Plus le profil-driven gstack on-demand (option 1 user : gstack OFF
par défaut, mais `set <profil>` qui a besoin de gstack l'active pour ce profil).
Root causes trouvées (logs install-20260623-181416.log) :
- Bug A : install.sh lance link.sh (étape 5) AVANT install-plugins.sh (étape 6),
  qui n'a jamais re-lancé link.sh → symlinks npx/externes jamais créés au 1er run
  (LRN-022 documentait déjà le trou). update-all.sh re-link déjà (L364).
- Bug B : `npx skills add` + gstack ./setup résolvent leur cible relativement au
  CWD (repo) → darwin-skill atterrit dans $REPO/.agents/skills + $REPO/.claude/skills
  au lieu de $HOME/.agents/skills. Auto-entretenu une fois $REPO/.agents créé.
- Bug C : profile.sh "missing — try: bash link.sh" trompeur (link.sh ne crée pas
  les skills gstack) ; full.profile liste 35 skills gstack jamais posés dans skills/.

- [x] Edit 1 — install-plugins.sh Step 8.5 : `npx skills add` depuis $HOME (subshell cd)
- [x] Edit 2 — install-plugins.sh : cleanup parasites $REPO/.agents/skills + $REPO/.claude/skills (gitignorés)
- [x] Edit 3 — install-plugins.sh : Step 10 final re-lance `bash "$REPO/link.sh"` (idempotent)
- [x] Edit 4 — update-all.sh Step 7.5 : `npx skills add` depuis $HOME (même Bug B)
- [x] Edit 5 — lib/profile.sh : GSTACK_SRC var + enable_skill gstack branche on-demand
      (symlink skills/<name> → skills-external/gstack/<name>) + message honnête
- [x] Verif — shellcheck/bash -n propres ; migré darwin → $HOME/.agents/skills + `bash link.sh`
      (skills/darwin-skill OK) ; `profile.sh set full` → 0 "missing", 35 gstack on-demand ;
      cycle minimal↔full OK ; git propre (symlinks gstack gitignorés) ; profil full restauré
- [x] Cleanup machine courante : $REPO/.claude/skills/darwin-skill + .agents/skills VIDE
      restent (rm bloqué par garde permission .claude/) → auto-nettoyés au prochain `make plugin`
      [reconcile 2026-06-29 : TOUJOURS présents (fs-vérifié, darwin-skill 116K daté 23/06) — `make plugin` pas rejoué depuis. Reste différé, déclencheur = prochain install.]
      [done 2026-06-30 : `make plugin` rejoué EXIT=0 (npm réparé via corepack, [[BLK-013]]) → Step 8.5 a retiré les deux ; fs-vérifié ABSENTS, vrai skills/ intact (36 entrées). Boucle fermée.]
- [x] Capitalize — LRN-042 (Bug B CWD-relatif) + BDR-030 (gstack on-demand par profil) + journal 2026-06-23
- [x] Commit (via /commit-change) — DONE (reconcile 2026-06-29 : working tree clean, travaux shippés)

## profile.sh — verbe `gstack on|off`
- [x] Extraire helper `enable_all_gstack()` (boucle de cmd_reset) — anti-duplication
- [x] Extraire helper `disable_gstack_not_in(prof)` (boucle gstack de cmd_set) — anti-duplication
- [x] Extraire helper `parked_gstack_count()` (réutilise pattern cmd_current)
- [x] Refactor cmd_reset + cmd_set pour utiliser les helpers (comportement préservé)
- [x] `cmd_gstack()` : `on` = enable tout gstack (garde label active-profile), `off` = disable gstack hors profil actif
- [x] Wire main() dispatch `gstack)` + usage() + bloc header
- [x] Doc : SKILL.md argument-hint + exemples + output-policy (Makefile générique suffit)
- [x] shellcheck propre + tests (help/bad-action/none-error/on/off cycle) — état live restauré exact
- [x] Investigué "fix" full.profile : PAS un bug — curation par design (BDR-017 caveat). Aucun fix code.
- [x] FOLLOW-UP (BLK-007 résolu) : linké `spec` (symlink chirurgical) + ajouté à full/web-full ; iOS NON linké (Linux, besoin Mac+Tailscale) ; `.gitignore` allowlist gstack complété (12 ajouts + checkpoint stale retiré) → `gstack on` git-clean ; LRN-025 capitalisé
- [x] Capitalize : BDR-018, LRN-024, BLK-007, EVAL-002, journal 2026-06-02 + backfill index (BDR-017, BLK-005/006)

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
- [x] Commit — DONE (reconcile 2026-06-29 : working tree clean, agent seo-analyzer live)

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

## Helper `--help` / `help` sur tous les skills (option C) [WON'T-BUILD 2026-06-30 — mesuré non-rentable]
> ⛔ WON'T-BUILD (2026-06-30) : ABANDON tranché après mesure. RED comportemental (6 reps, /web-validate + /harden, SANS instruction) → **6/6 rendent déjà une aide riche ET s'arrêtent sans dispatcher** (même /harden n'a pas lancé l'audit). Le comportement supposé absent est déjà spontané (convention universelle --help). Seule valeur résiduelle = cohérence de format (6 formats divergents) → ROI insuffisant pour ~5 lignes dans un CLAUDE.md compressé ([[BDR-031]]) sur repo mono-user. 3e état : NON "fait" (rien construit), NON "ouvert" (on ne le fera pas). L'option globale réalisait l'intention BDR-001 ; per-skill toujours rejeté. Voir [[BDR-001]] (won't-build), [[LRN-080]], [[LRN-075]]. Design + subtasks ci-dessous = historique, non actionnables.
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
- [-] Créer `skills/lib/help-handler.md` — snippet réutilisable (détection + extraction + affichage)
- [-] Définir format d'aide standard + section "ARGUMENTS" vs reuse de argument-hint
- [-] Décider : sections ARGUMENTS/EXAMPLES doivent-elles être dans la frontmatter (nouveau champ YAML) ou dans le corps du SKILL.md (nouvelle section `## Help`) ?
- [-] Patcher un skill pilote (`/validate`) — valider UX  _(désormais `/web-validate` — renommé e5e673a)_
- [-] Patcher les skills perso restants : analyze, bugfix, code-clean, commit-change, doc, feat, geo, graphify, harden, hotfix, init-project, make-pdf, onboard, plan-tune, plugin-check, refactor, seo, ship-feature, skills-perso, status, benchmark-models, context-save, context-restore
- [-] Mettre à jour `~/.claude/CLAUDE.md` — mentionner convention --help disponible sur tous les skills perso
- [-] Note : skills-external/gstack ont leur propre convention, ne pas toucher

## Skill profiles (partition gstack par usage)
- [x] Plan
- [x] `lib/profile.sh` — list/show/current/apply/set/reset/diff via symlink toggle
- [x] `lib/profiles/{design,dev,qa,audit,minimal}.profile` — 5 profils
- [x] `skills/profile/SKILL.md` — slash command `/profile`
- [x] Wire `agents/plugin-advisor.md` — DETECT call profile.sh current + OUTPUT line PROFILE + nouvelle section "Skill profiles" dans TOGGLING EXTERNAL TOOLS
- [x] Wire `lib/toggle-external.sh` — header pointer vers profile.sh
- [x] `Makefile` — targets profile/profile-list/profile-current/profile-reset
- [x] Tests : list/show/current/diff/set/reset/apply tous OK, shellcheck propre, symlinks bien restaurés après reset

## Profile system v2 — extension plugins/MCPs/CLIs
- [x] Inventaire complet : 7 plugins (4 ON / 3 OFF), 0 MCP local, 4 CLIs installés
- [x] Définir `MANAGED_PLUGINS` (ui-ux-pro-max, plugin-dev, pr-review-toolkit) + `PROTECTED_PLUGINS` (caveman, security-guidance, superpowers)
- [x] `profile.sh` étendu : nouveau type `plugin@<marketplace>` (auto-toggle via `claude plugin enable/disable`), `mcp` (delegate à toggle-external.sh pour magic), `cli` (advisory only)
- [x] `cmd_set` désactive aussi les MANAGED_PLUGINS hors profil
- [x] `cmd_reset` ne touche PAS aux plugins (info line explicite — re-enable manuel ou via apply)
- [x] `cmd_current` : compte `enabled` + `installed`, tiebreaker = total le plus grand
- [x] `cmd_show` : colonne TYPE élargie à 30 chars pour `plugin@ui-ux-pro-max-skill`
- [x] 4 nouveaux profils : `web`, `seo`, `web-full`, `backend`
- [x] Profils existants raffinés (design, dev, qa, audit) avec `plugin@<marketplace>` + `cli`
- [x] `skills/profile/SKILL.md` : table profils mise à jour + table mécanisme par type
- [x] `agents/plugin-advisor.md` : table de recommandations étendue avec web/seo/web-full/backend
- [x] Tests : `set web` enable ui-ux-pro-max+magic, `set seo` disable ui-ux-pro-max, `set minimal` épargne always-on, `reset` restaure 64 skills
- [x] Memoire : BDR-008 (v2 décision) + journal entry 2026-05-04
- [x] Shellcheck propre

## /audit-delta — skill audit incrémental multi-axes (2026-06-11)
But : 1 skill, 4 axes cochables (conformité CLAUDE.md, erreurs/améliorations,
code mort, sécurité), scope = diff depuis dernier run (marqueur SHA persistant,
par axe), boucle par axe : audit → gate approbation → fix → re-vérification
obligatoire avant axe suivant. Construit via superpowers:writing-skills (TDD).
- [x] RED : baseline subagent sans skill (worktree isolé) — 7 gaps documentés
      (boundary par date de fichier, checkpoint en prose, pas de marqueur par
      axe, zéro gate, lint=verify, passe unique mélangée, registres auto-écrits)
- [x] GREEN : skills/audit-delta/SKILL.md — pass sous pression (state file
      utilisé, gate tenu malgré "fix tout + meeting", marqueurs par axe OK)
- [x] REFACTOR : trou trouvé (premier run + user injoignable, aucune règle) →
      patch : défaut full codebase report-only, jamais "from HEAD" ; re-test pass
- [x] Vérif finale : skill découvrable (~/.claude/skills/audit-delta via symlink
      skills/), frontmatter valide, worktrees de test nettoyés
- [x] Capitalize : BDR-020 + LRN-027 + journal 2026-06-11
- [x] Commit (via /commit-change quand prêt) — DONE (reconcile 2026-06-29 : working tree clean, skill audit-delta live)

## 2026-06-11 — darwin eval: 4 confirmed bugs fix (branch auto-optimize/*-bugfixes)

- [x] geo-analyzer.md: unreachable user → ALL file fixes report-only (STEP 12/13 triage gate)
- [x] init-project SKILL.md: repoint readme-updater.md (absent) → doc-syncer.md x2
- [x] analyzer.md: resolve "Update project memory" vs "Do not modify files" contradiction
- [x] onboard SKILL.md: allowed-tools += Agent, Skill (workflow STEPs 5-7 need them)
- [x] re-test geo fixture (unreachable) → expect zero source edits; 2 blind judges on geo-analyzer diff
- [x] commit per fix, results.tsv rows, merge if green

## 2026-06-19 — cleanup/caveman-always-on (full plugin purge)
Goal: disable caveman plugin + delete every repo dep on it. Plugin.json
self-declares always-on hooks → "enabled w/o always-on" impossible → full
purge. Keep memory-registry terse-format rule (separate subsystem); only
replace dead `/caveman:compress` cmd refs w/ "Legacy entries
(pre-format-rule): compress manually or via claude.ai on demand."
Version 3.4.0 → 3.5.0.
- [x] RUNTIME (user, no TTY): plugin disable + uninstall caveman@caveman; mcp list check
- [x] PHASE 2: settings.json (2 hook blocks + enabledPlugins + marketplace); hooks/ files delete; .gitignore block; session-start.sh L134
- [x] PHASE 3: install-plugins.sh STEP 5.5; update-all.sh block; plugins.lock.json; doctor.sh; lib/detect-plugins.sh; lib/profile.sh; plugin-advisor.md; skills/profile/SKILL.md
- [x] PHASE 4: README row; USAGE always-on line; CHANGELOG; CLAUDE.md cmd ref; skills/capitalize+prune-memory cmd refs; version.txt
- [x] PHASE 5: shellcheck clean (SC1091 info only); full diff reviewed → committed + merged to master

## 2026-06-26 — coupled-capitalize invariant v1 (Frame 2)
Plan: [.claude/tasks/2026-06-26-coupled-capitalize-invariant.md](2026-06-26-coupled-capitalize-invariant.md)
Goal: every dev flow commits its memory automatically (1 commit/flow) via shared
include; ship-feature reordered (capitalize before FINISH = PR-bug fix). Hook v2,
doc-sync twin chantier deferred. Safety in the pathspec, never `git add -A`.
- [x] Task 1 — `lib/memory-commit.sh` + tests T1/T2/T2-bis/T3/T4/T5/T6/T7 (real exec, outputs reported) — 58cb91d + bbef41c
- [x] Task 2 — `lib/capitalize-commit.md` include — b44791b
- [x] Task 3 — wire feater/hotfixer/bugfixer/commit-changer — 2763678
- [x] Task 4 — ship-feature reorder (capitalize before FINISH) — e8eff7e
- [x] Task 5 — init-project founding-decisions capitalize (F5) — df60df6
- [x] Task 6 — behavioral verify + shellcheck + CHANGELOG + BDR/LRN — this commit
- [x] v2 — REJETÉ (pas différé) — BDR-037 (reconcile 2026-06-29) : aucun event CC ne supporte un nag de fin-de-session (Stop = par-tour, SessionEnd = debug-log only). Vrai manque = câblage, corrigé en wirant /capitalize+/close à l'include. Aucun code à écrire.
- [x] twin chantier — doc-sync DONE (reconcile 2026-06-29) : chantier propre livré ci-dessous (2026-06-27, BDR-036). La note REFUTED était juste — doc-commit BÂTI, pas reorder-seul.

## 2026-06-27 — doc-sync coupled (twin of coupled-capitalize)
Plan: [.claude/tasks/2026-06-27-doc-sync-coupled.md](2026-06-27-doc-sync-coupled.md)
Goal: orchestrators commit the docs doc-sync patched, on the branch, BEFORE FINISH.
Same PR-bug class as memory, NOT same fix: doc-syncer commits nothing (proven) →
reorder + CREATE doc-commit.sh/.md (mirror memory-commit, 4 deltas). Surface-don't-block.
- [x] Task 1 — `lib/doc-commit.sh` + `lib/tests/run-doc-commit.sh` — 24/24 real-exec pass, shellcheck clean. T1a/b/c (guard catches .claude/+CLAUDE.md, mixed→refuse-all-loud) + T2 dynamic pathspec + T3/T4/T5/T6. Exit taxonomy 0/2/3/4 (4=scope violation).
- [x] Task 2 — `lib/doc-commit.md` include — 4a54a65. 4-exit report table (rc 4 = loud upstream anomaly), visible surface w/ agent-composed summary (attribution locked 3×), 2 conscious acks.
- [x] Task 3 — `agents/doc-syncer.md` `PATCHED_FILES:` OUTPUT — fb1f359. Newline (one path/line), both STEP 9 + AUTO A4; NONE silent. Separator contract aligned producer↔consumer, argv space-safe, T7 proves it (28/28). Additive, callers unaffected.
- [x] Task 4 — ship-feature reorder — 636b491. DOC SYNC 9→8 (+doc-commit), FINISH 8→9, HTML comment deleted. Ref-coherence: 159/189 STEP 8→9 FINISH + README:152-153 illustration completed (stale since e8eff7e). Historical records left (append-only).
- [x] Task 5 — init-project reorder — e81f629. SYNC README 12→10c (+doc-commit), GSD 13→12, /13→/12. Order 10b→10c→11→12. Ref-coherence: USAGE ×5 (table, illustration, 3 GSD refs) each verified post-swap. Latent-bug check: none (10b was non-shifting). BLK-011 record left (append-only), TODO locator→12.
- [x] Task 6 — ref-sweep — clean (no old headers; live refs fixed in Task 4/5; historicals left; USAGE:256 non-ordering). Caught inline-flow gap → Task 6b.
- [x] Task 6b — wire doc-commit into feat/bugfix/hotfix DOC SYNC — 1b01b95. commit-change exempt (no DOC SYNC); hotfix wired (include no-ops on empty).
- [x] Task 7 — close: `run-doc-behavioral.md` + shellcheck clean + 28/28 + CHANGELOG + BDR-036 / LRN-058-060 / EVAL-008. surface-replaces-gate + partial-init + scope-expansion engraved honestly.
- [x] RESOLVED 2026-06-29 — [[BLK-010]] closed by `gitflow_init` root commit (init-project STEP 5f): scaffold/README get a deterministic commit owner + HEAD born before the worktree step. Verified (mechanism + STEP 5f wiring + T2 test); blockers.md index+body updated.
- [x] RESOLVED 2026-06-29 — [[BLK-011]] closed by REMOVAL: init-project STEP 12 (speculative gsd auto-bootstrap) deleted → orphan never created. Negative diff, not commit-plumbing ([[LRN-072]]). See chantier below.
- [x] DONE 2026-06-29 — doc-sync MINOR gate strengthened: ① shape-oracle [[BDR-040]] + ② masked-commit fix [[LRN-071]] (③ branch-guard deferred). See chantier below.

## 2026-06-29 — gitflow universal model + 6-repo migration (DONE)
Goal: universal gitflow across all `bchanot/*` Gitea repos. Lib built across prior sessions; migrated + hardened + dogfooded this session.
- [x] Lib hardened at ROOT — `gitflow_init` socle-commit made FATAL + identity precheck + `migrate_local` identity guard (BLK-012 → LRN-068); 57/57 green, abort-zero-mutation proven on identity-less repo
- [x] `lib/gitflow-migrate.sh` — probe (rights, not just identity) / local / remote, reversible→irreversible ordering, delete-master LAST
- [x] Migrated 6 repos (faunosteo, config, bchanot-cv, zenquality, game, claude): master→main, develop, Option-1 protection, master deleted — each delete behind eyeball+GO, ZERO loss, no force/`--no-verify`, settings intact
- [x] claude SELF-APPLIED — own committed lib migrated it; chantier landed C1 feat `167ea96` + C2 memory `1254643` + socle `620071b`; hook now governs claude
- [x] gstack submodule dirty (BLK-008 Playwright bump) excluded via `submodule.ignore=dirty` (LRN-070), NOT reset
- [x] Deleted merged branches: `feat/deploy-skill` (local+remote) + `cleanup/caveman-always-on` (remote)
- [x] Dogfood PROVEN: hook whitelists `.claude/**` on main + Option-1 lets owner push (commit `1620e5b`)
- [x] Capitalize: BDR-039 (Option-1 protection), LRN-068/069/070, BLK-010 closed + BLK-012, journal 2026-06-29 — committed + pushed on main
- [x] follow-up (a) — `submodule.gstack.ignore=dirty` committé dans `.gitmodules` — DONE (reconcile 2026-06-29 : commit `be1dcef` sur main, mergé via hotfix/gstack-ignore-gitmodules)
- [ ] follow-up (b) — zenquality `cleanup/post-smtp-fix` rename `<type>/<name>` ou finish+delete (AUTRE repo, optionnel)

## 2026-06-29 — MINOR-gate strengthening (doc-syncer) [DONE — merged develop, branch deleted]
Read-first cartography refuted the literal premise: "strengthen MINOR gate" = 3 problems;
the literal one (blocking gate on MINOR) contradicts engraved [[BDR-036]]. Scope: ①+②, not B,
③ deferred. Built test-first (Iron Law).
- [x] ② fix masked commit failure — `doc-commit.sh` exit 5 fail-loud ([[LRN-071]], 3rd occurrence of the swallowed-commit pattern). RED T8 proved masking, GREEN 32/32 + taxonomy (sh header/funcdoc + `doc-commit.md` rc-5 row)
- [x] ① MINOR-shape oracle — `lib/doc-shape.sh` ([[BDR-040]]) + `run-doc-shape.sh` 19/19 (boundary + env-override). Wired doc-syncer STEP A4 (escalate whole set → existing SIGNIFICANT gate; no=revert all, select=keep subset) + `doc-commit.md` ACKNOWLEDGMENTS coherence + behavioral Scenario C/D
- [x] shellcheck clean (doc-commit.sh, doc-shape.sh, both test harnesses); coherence ref-sweep clean
- [x] Capitalize — BDR-040 + LRN-071 + CHANGELOG (Added/Fixed) + journal 2026-06-29 (cont.)
- [x] FINISH — merged feature/minor-gate-strengthening → develop (`0f0bd7f`) on explicit signal
- [~] ③ branch-guard in doc-commit DEFERRED — duplicates protected-base predicate 3rd time (lib + hook + here); all migrated repos have the hook. Reconsider only for repos outside `gitflow init`

## 2026-06-29 — BLK-011 GSD ROADMAP post-FINISH [DONE — merged develop ce4391a, branch deleted]
User reframed: don't plumb a commit for the stranded ROADMAP — ask if gsd belongs at init at all.
Read refuted both option-premises (gsd ≫ roadmap; TODO ≠ gsd ROADMAP) but conclusion A held for a
stronger reason: speculative auto-bootstrap of an unused engine at creation is bad per se ([[LRN-072]]).
- [x] Resolve by REMOVAL — deleted init-project STEP 12 (negative diff −26/+13), not a commit helper
- [x] Ref-coherence sweep ("test" for a removal) — header 12→11-step, 10c note, 4 USAGE refs; zero dangling STEP-12 refs repo-wide
- [x] Scope guardrails — deliberate gsd use KEPT (onboarder PHASE 6, plugin-advisor, status-reporter)
- [x] Capitalize — [[BLK-011]] resolved (true reason + premise trace) + [[LRN-072]] + CHANGELOG Removed + journal 2026-06-29 (cont. 2)
- [x] FINISH — merged bugfix/blk-011-gsd-roadmap → develop (`ce4391a`); develop pushed to origin (6 commits, SSH)

## 2026-06-29 — prune-memory hardening (RED-7/8 + index backfill) [DONE — merged develop 73e12be, branch deleted]
LAST of 3 chantiers. Read-first cartography confirmed RED-7/8 + measured 34-row index drift.
- [x] RED-7 (example-priming) — fictionalized STEP-2 example to 9xx ids (live ids primed a wrong merge of complementary LRN-014/016); DETERMINISTIC test (run-deterministic.sh) per [[LRN-046]]. Caught its own ugrep false-green → /usr/bin/grep ([[LRN-074]]). [[LRN-073]]
- [x] RED-8 (added-negation inversion) — consciously ACCEPTED as documented limit in BACKLOG ([[LRN-047]]); no fragile guard built
- [x] Index backfill — 34 missing rows (decisions 11, learnings 21, blockers 2) composed + ID-sorted insert; drift 34→0, STEP-4 verify OK; moved pre-existing out-of-order LRN-021
- [x] Capitalize — [[LRN-073]] + [[LRN-074]] + [[EVAL-010]] + journal 2026-06-29 (cont. 3)
- [x] FINISH — merged bugfix/prune-memory-hardening → develop — DONE (reconcile 2026-06-29 : merge `73e12be`)
- [x] PUSH — develop → origin — DONE (reconcile 2026-06-29 : develop == origin/develop, 0 commit en avance)

## 2026-06-29 — skill /reconcile (RÉCONCILIATEUR file-ouverte ↔ réel) [SHIPPED 2026-06-30 — develop aede7af, pushed]
Genèse : l'inventaire manuel du 2026-06-29 a prouvé que le TODO mentait (5 cases fait-mais-non-coché
+ 1 "auto-nettoyé" qui ne l'était pas + 1 rejeté marqué "deferred"). Cet inventaire EST la spec du
skill ET son cas de test de référence (résultat manuel connu-bon à reproduire).

PRINCIPE NON NÉGOCIABLE — ce n'est PAS un grep des `[ ]` du TODO (ça reproduirait le mensonge : dirait
"ouvert" sur du fait-mais-non-coché). C'est un RÉCONCILIATEUR : confronte les sources DÉCLARATIVES à
l'état RÉEL et signale les ÉCARTS. Un lister-de-todos ne vaut rien (grep le fait) ; un "le TODO prétend
X, le réel est Y" vaut beaucoup.
- Sources DÉCLARATIVES : TODO.md ; BDR deferred/follow-ups/caveats ; BLK status=open|upstream ;
  LRN caveats "revisit if / re-run if".
- État RÉEL (oracles) : git (branche mergée/absente, commit existe, origin sync, working tree clean) ;
  fichier live = committé (skill/agent présent + linké = shippé) ; statut registre.

SORTIE = les 4 catégories de l'inventaire 2026-06-29 :
  1. actionnable maintenant (non bloqué)
  2. bloqué (condition externe — upstream)
  3. différé (déclencheur conditionnel)
  4. écart TODO↔réalité (fait-mais-non-coché / rejeté-marqué-deferred / "auto-fait" non vérifié)
  + CONTRADICTIONS inter-registres (ex. BDR-001 accepted "pas de helper par SKILL.md" vs chantier
    --help qui copie dans chaque SKILL.md).
  + réconciliation TODO **GATED** : montre les écarts, DEMANDE avant cocher/requalifier
    (modifie un fichier tracké → jamais silencieux).

Subtasks (à détailler au lancement) :
- [x] Spec : table oracle-par-source (commit existe / branche absente / tree clean / skill linké /
      statut registre) — chaque "déclaré" a son test réel — DONE (lib/reconcile.sh : reconcile_oracle_*)
- [x] Décider build : superpowers:writing-skills (TDD, RED = fixture TODO menteur reproduisant les 7 écarts) — DONE (RED a4872 miroir + RED-B Index-ignore à dents + GREEN comportemental a8404)
- [x] `skills/reconcile/SKILL.md` — DONE (skill mince : orchestration + gate A/B/C + limites honnêtes)
- [x] routage CLAUDE.md (triggers : "reconcile", "file vraiment vide ?",
      "qu'est-ce qui reste ouvert", "inventaire chantiers") — DONE (CLAUDE.md "Skill routing" + link.sh)
- [x] Détecteur de contradictions inter-registres (BDR accepted vs chantier qui le contredit) — DONE (reconcile_contradiction_candidates ; surface, n'asserte pas)
- [x] Gate de réconciliation (diff TODO proposé, A/B/C confirm avant edit) — DONE (SKILL.md "The gate" ; registres read-only)
- [x] Test final = reproduire l'inventaire 2026-06-29 (cat. 1-4 + contradiction BDR-001) comme oracle — DONE (run-reconcile.sh 20/20, fixtures neutres, RED prouvé rouge avant le vert)
- SHIPPED 2026-06-30 : feat `82e6322` + mémoire `6b512be` → merge `aede7af` (feature/reconcile-skill supprimée) → poussé origin/develop. main intact. BDR-041 + LRN-075/076/077 + EVAL-011 capitalisés.

## [SHIPPED 2026-06-30 — develop 0c0b748, released v4.0.0 (tag v4.0.0)] skill /release-candidate — orchestrateur gitflow release
Pertinent maintenant : develop ahead de main, prochaine étape gitflow = release.
VÉRIFIÉ dans lib/gitflow.sh (2026-06-30) — release CÂBLÉE, pas que hotfix :
- start base=develop (`gitflow_base_for` L49) ; `gitflow start release <ver>` positionne sur la branche (L71).
- finish fan-out (`gitflow_finish` L108-111) : merge main + merge-back develop + delete (locale, `_gitflow_delete` L96).
- GAP CONFIRMÉ (grep clean) : AUCUN `git tag` ni bump version dans tout gitflow.sh → la mécanique merge mais ne tague PAS.

Design (à la conception) : ORCHESTRATEUR au-dessus du gitflow existant — NE PAS réécrire la mécanique.
- `gitflow start release <ver>` (depuis develop) → positionne.
- prep sur la branche release : bump VERSION + CHANGELOG (Keep-a-Changelog) + RC fixes.
- `gitflow finish` (merge main + merge-back develop + delete — déjà câblé).
- FOURNIR le tag manquant : `git tag` sur main au merge-commit (le seul morceau absent de la lib).
- push gaté (ASK, [[LRN-069]]) : main + develop + tag.

Subtasks (à détailler au lancement) :
- [x] Décider : tag fourni par le skill au-dessus de gitflow (mécanique non réécrite) — d3d6ced, [[BDR-042]]
- [x] `skills/release-candidate/SKILL.md` — orchestration start→prep→finish→tag→push(gaté) + gate humain "WHEN to release" — présent (d3d6ced)
- [x] routage CLAUDE.md — présent (~/.claude/CLAUDE.md "Cut a release → release-candidate")
- [x] test — prouvé par la release réelle 4.0.0 : fan-out main (709facf) + develop (4a00a60) + tag v4.0.0

## Auto-déclenchement des skills par intention [WON'T-BUILD 2026-06-30 — mesuré : Claude discrimine déjà (3 classes)]
> ⛔ WON'T-BUILD (2026-06-30) : 3e moot de la série (après [[BDR-001]] --help + [[BDR-043]]/[[LRN-082]] darwin re-baseline). Cartographie : routing = STACK L0(design-hook)→L1(superpowers « 1%→MUST invoke », dominant)→L2(prose CLAUDE.md)→L3(frontmatter)→L4(BDR-019). L1 SUR-détermine déjà l'invocation → « auto-call ? » = déjà oui. Reframe C : la vraie question = DISCERNEMENT, risque inversé under→**OVER**-routing. Mesure en VRAIES sessions fraîches (8 prompts / 3 classes) : CLEAR→route ✓, AMBIGUË→demande (refuse de deviner, investigue pour une question utile) ✓, TRIVIALE→s'abstient ✓. Le sur-routing soupçonné (L1 vs règles Workflow) NE se matérialise PAS — le modèle équilibre. Prose de bornage L2 = valeur fantôme + risque de DÉGRADER un discernement déjà bon. Voir [[BDR-044]] (reframe + verdict), [[LRN-083]] (RED sous-agent invalide), [[LRN-080]] (mesure-first, corroboré 3-in-a-row). RED sous-agent initial (0/6) RETIRÉ comme non-discriminant (plancher artefact). Design + subtasks ci-dessous = historique, non actionnables.
> ⏭️ (historique) NEXT, mais CADRÉ : **pas de design avant la mesure**. Jumeau méthodologique de [[BDR-001]] `--help` (won't-build après RED) — même piège architectural, même garde-fou [[LRN-080]] (mesurer avant d'instruire) + [[LRN-049]] (borner le bruit avant le marqueur). Les subtasks ci-dessous s'arrêtent à la mesure ; le design ne s'ouvre QUE si le RED valide la valeur.

**Contrainte architecturale (établie pour `--help`, non négociable) :**
Aucun mécanisme n'intercepte le message utilisateur pour *lancer* un skill. La harness ne route pas avant que le modèle réponde — un skill n'est invoqué QUE par le modèle (outil Skill). Donc « auto-call déterministe » = IMPOSSIBLE. Le seul levier sur l'invocation elle-même = instruire le MODÈLE à reconnaître l'intention et appeler le bon skill → **conformité-modèle, PAS déterminisme**. C'est une instruction de routage CLAUDE.md, pas un mécanisme.
- Nuance (raffinement) : une couche déterministe existe *en amont* du call, pas *sur* le call — un hook `UserPromptSubmit` peut détecter un signal et INJECTER un rappel de routage (le `design-toolchain` hook fait déjà exactement ça pour l'UI ; le banner session-start aussi). Détection déterministe + injection advisory ; le modèle reste celui qui tire. MAIS sur des verbes d'intention (« corrige », « crée », « bug »), un hook keyword serait BRUYANT (ces mots sont partout) — le design-hook s'en sort car « design/UI » est un signal rare. Donc le levier hook est probablement non-viable pour le cas large → ce qui **renforce** le besoin de borner aux signaux rares/non-ambigus.

**Substrat déjà en place :** [[BDR-019]] a retiré `disable-model-invocation` repo-wide → le modèle PEUT déjà self-router vers les skills (défaut = activé ; user l'avait vécu live : intention feature détectée, `ship-feature` voulu, jadis bloqué). Et la section « Skill routing » de CLAUDE.md existe déjà. Donc la **baseline du RED = le routage CLAUDE.md ACTUEL tel quel** ; le chantier n'a de valeur que si le RED prouve que cette prose SOUS-déclenche sur intention claire (exactement la logique --help : baseline = convention déjà là, question = est-ce qu'instruire en plus change quoi que ce soit).

**Le chantier COMMENCE par (rien d'autre avant) :**
- [x] (a) **Cartographier** le routage CLAUDE.md actuel — quels signaux → quels skills sont déjà censés router (« Skill routing » + « Design work » + descriptions de skills). État des lieux factuel, pas de jugement.
- [x] (b) **RED comportemental** ([[LRN-080]]) — prompts d'intention IMPLICITE, naturalistes, SANS instruction renforcée : « il y a un bug, debug », « on va créer X », « corrige ceci », « refactor ce module », « cut a release »… → le modèle invoque-t-il le bon skill, ou fait-il la tâche à la main en ignorant le skill ? N reps, plusieurs intents distincts.
  - Garde-fou RED : **ne PAS amorcer**. Sessions fraîches / sous-agents, prompts naturels, zéro mention de « skill » / « routage » / « test » dans le prompt mesuré (sinon le modèle route parce qu'il SAIT qu'on le teste — contamination). Le RED `--help` était mécanique donc peu sensible à l'amorçage ; l'intent-routing l'est beaucoup plus → rigueur supérieure requise.
- [x] (c) **Décider selon le RED** :
  - déjà bon (comme --help) → chantier MINCE, voire won't-build ; capitaliser le constat (3e état : mesuré non-rentable, ni fait ni ouvert).
  - sous-déclenche → vraie valeur : renforcer la **prose de routage** (levier modèle) sur signaux CLAIRS uniquement — PAS un hook keyword (trop bruyant, cf. nuance ci-dessus).

**Scope à border au cadrage — NE PAS faire « tout skill jugé pertinent » :**
Tension réelle proactif vs intrusif. Auto-déclencher feat/bugfix sur intention CLAIRE et non-ambiguë = sain. « Déclenche tout skill jugé pertinent » = RISQUÉ (faux déclenchements, skills non sollicités, flux interrompus). Réglage cible ([[LRN-049]] borner le bruit) = déclencher sur signaux d'intention CLAIRS et non-ambigus ; **ambigu → DEMANDER, pas auto-déclencher**. À définir précisément SI (et seulement si) le RED valide : table `signal → skill` + la frontière exacte de l'ambiguïté.

## 2026-06-30 — session-close follow-ups (promoted from BLK-013 / BDR-043)
- [x] (a) Harden install-plugins.sh Step 1 — guarantee `npm` on apt-`nodejs` hosts (detect missing npm + `corepack enable npm`), not just check `node >=22`. Fix-forward for [[BLK-013]] — stops `make plugin` Error 127 recurring on any fresh apt machine.
      [done 2026-07-01 : unconditional npm guard after Node block (corepack enable npm → distro `install npm` fallback → fatal exit 1 w/ clear msg). Catches node>=22-present-but-npm-absent (NODE_OK short-circuit). shellcheck clean, bash -n OK. Fresh-apt live validation pending (no npm-less host to hand). branch bugfix/install-plugins-npm-guard.]
- [x] (b) Re-baseline darwin on the 5 ex-broken gstack skills (`benchmark-models`, `context-restore`, `context-save`, `make-pdf`, `plan-tune`) — now repaired and back in scope ([[BDR-043]], trigger cleared). Verify `results.tsv` still marks them `status=error` first. (Promoted from BDR-043's action-field — not an item the user authored.)
      [resolved-MOOT 2026-06-30 : won't-run. BDR-043 cleared only motif (a) of BDR-015's TWO exclusion grounds (symlinks repaired ✅); motif (b) external-ownership INTACT — the 5 resolve to skills-external/gstack/ (submodule), darwin optimizes by EDITING SKILL.md → would dirty the submodule (forbidden [[LRN-070]]). Re-baseline = unactionable score. + results.tsv gone (wiped by 23/06 make-plugin reinstall) → not even a re-baseline, a fresh-from-zero one. Geometric trigger lifted, value trigger intact — twin of --help [[LRN-080]]. See [[LRN-082]]. Not "done", not "open": MOOT.]

## 2026-07-03 — bugfix/gitflow-finish-args (contract fix + doctor false-warns)
Root: audit 2026-07-02 residuals. `gitflow_finish` ignores its args (merges CHECKED-OUT
branch) → LOT3 mis-merge trap; + 3 doctor false-warns (LRN-047 class).
- [x] (1) lib/gitflow.sh gitflow_finish — optional <type> <name>; error rc2 if != current
      branch ("operates on current branch X, you asked Y — checkout Y first"). No-args unchanged.
      Commit d9fdd4c. [[BLK-015]] [[LRN-089]].
- [x] (2) lib/gitflow-test.sh — T12 arg-guard: arg-mismatch → nonzero + message names both;
      arg-match → merges as before. +7 assertions (71/71). T12 (not T6c — reconcile collision).
- [x] (3) doctor.sh cargo line — false "(RTK unavailable)" → optional info (RTK prebuilt).
- [x] (4) doctor.sh check_symlink — PASS iff canonical path under $REPO (direct OR via
      symlinked ancestor dir); hooks/session-start.sh false-warn gone. Commit 6778b9f.
- [x] (5) doctor.sh §2 gstack — counts 34 per-skill symlinks; mythical [ -L skills/gstack ] dropped.
- [x] (6) doctor.sh token § — denominator 11000→CONTEXT_WINDOW=200000, thresholds 15/25,
      comment anchored to measured ~11.4k (LRN-088). False "92% CRITICAL" → ~5% comfortable.
- [x] Verify — suites green (71/13/32/19/20/13 + RC 5/5); doctor 0 false-warn; shellcheck clean.
      +docs(changelog) Unreleased entry (706abff). Gate passed on GO 2026-07-03. Finish pending.
