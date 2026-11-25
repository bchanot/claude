# CONTRACT — deepseek-delegate
- date: 2026-11-25 | flow: feat | branch: feature/deepseek-delegate
- status: active
- run-base: 9c8e61205f8b6006debaf9197150e06e249d63a3

## REQUEST (verbatim — IMMUTABLE)
User message:
je suis ok sur ces 3 recommandations, on est d'accord que c'est un skill la, mais ce sont bien des taches ou des sous agents ou des appels automatiques qui seront fait a deepseek ?>  Et est-ce qu'on va gerer aussi correctemetne l'effort ? et prendre en compte quand il y aura plusieurs model si c'est le cas un jour pour rediriger auto vers tel ou tel model selon la tache ? . Je peux relancer une discussion sur le claude code du mac pour continuer directement dessus ? Mais ca sera un autre compte  claude. Et aussi il faudra prendre en compte le fait de pouvoir activer ou non le routage deepseek

/feat arguments:
Skill générique `deepseek-delegate` (nom à confirmer) dans claude-config : délègue une tâche autonome en LECTURE SEULE à DeepSeek via la commande wrapper locale `dsh-deepseek` (DeepSeek Harness headless, processus séparé). Périmètre v1 : (1) déclenchement explicite par l'utilisateur uniquement (pas d'invocation automatique par le modèle) ; (2) aucun détail propre au fournisseur ou à l'entreprise dans le skill (URL, CA, nom de variable de clé restent dans le wrapper et le profil dsh, locaux à la machine) ; (3) interrupteur local à la machine, convention des mods (`"enabled": false` dans `~/.claude/<nom>.json`), et wrapper absent = coupé : Claude fait la tâche lui-même et le dit ; (4) tâche passée par fichier sur stdin (pas entre guillemets shell), `--permission-mode read-only` et `--approval-policy never` explicites, timeout externe, contrôle de fin (code de sortie 0 ET événement final `completed` en `--json`) ; (5) le skill transmet un type de tâche (noms de phases du routeur : explore, reflect, verify) comme couture pour une future table locale type → modèle + effort, non construite maintenant ; (6) brief autonome, interdiction de commit/push/écriture, sortie traitée comme non fiable, origine DeepSeek signalée à l'utilisateur ; (7) piège documenté : `dsh` dans le PATH peut être un homonyme (Distributed Shell), toujours passer par `dsh-deepseek`. Hors périmètre : écriture, conteneur, appels automatiques depuis d'autres skills, choix d'effort ou de modèle par run (mécanisme dsh non vérifié en 0.2.2-rc.5), modification du wrapper (sur un Mac, appliqué par l'utilisateur : lecture seule et `DSH_TELEMETRY_MODE=DISABLED` par défaut). Contrainte de vérification : ni dsh ni le wrapper n'existent sur cette machine Linux ; la validation ici porte sur la forme (tests, census, ligne routing.json), le premier run réel se fera sur le Mac. Noms visibles à demander : nom du skill, fichier de l'interrupteur, nom de l'argument de type de tâche.

## CLARIFICATIONS
Q: three recommendations (generic tracked skill without company names; explicit trigger only at first; read-only + telemetry off by default) / A: "je suis ok sur ces 3 recommandations" (2026-11-25)
Q: week without Claude / A: dropped ("je ne ferais pas de semaine sans claude", 2026-11-25)
Q: skill name / A: `deepseek-delegate` [gated 2026-11-25]
Q: switch default when `~/.claude/deepseek-delegate.json` is absent (the file also holds the timeout, 600 s default, and the wrapper command name) / A: on when the wrapper exists; `"enabled": false` turns it off [gated 2026-11-25]
Q: name of the task-kind option / A: `--kind` (explore, reflect, verify) [gated 2026-11-25]
Q: worker's launch directory (the harness looks for API keys in `<cwd>/.env`) / A: an empty temporary directory; the brief carries absolute paths [gated 2026-11-25]
Q: config key listing extra variables allowed into the worker's filtered environment / A: `passEnv` [gated 2026-11-25]
Q: is claude-config installed and linked on the Mac / A: yes [gated 2026-11-25]
Q: three findings of the confirmation challenge (failure tests not proving the success rule; kill tests able to pass vacuously; runner layout, exit status and signal set unpinned) / A: reopen all three, plan revised, no further challenge [gated 2026-11-25]
Q: security review, semgrep refused by the permission classifier / A: re-dispatch a fresh auditor whose brief allows the semgrep rule download; stop if refused again [gated 2026-11-25]
Q: security review findings (1 MEDIUM, 7 LOW, none blocking) / A: fix three LOW now (worker directory separate from the engine's control files, forced stop of processes left after a normal end, a guard in the trap test); the MEDIUM (worker runs with the real HOME) and the four other LOW go to TODO.md [gated 2026-11-25]
Orchestrator note 2026-11-25: the request names `DSH_TELEMETRY_MODE=DISABLED`; the harness repository documents `DSH_TELEMETRY_DISABLED` as the opt-out. The engine sets both. The wrapper's stderr is never relayed (criterion 3: one line).

## ACCEPTANCE CRITERIA
1. Engine `lib/deepseek-delegate.sh` exists with verbs `status` and `run`;
   its suite passes: off when the wrapper command is absent (exit 3, wrapper
   never executed), off when the switch file says `"enabled": false` (exit 3,
   wrapper never executed), usage error on a missing or empty task file
   (exit 2), unknown kind refused (exit 2).
   CHECK: cd /home/bchanot/Documents/claude && make test suite=lib/tests/deepseek-delegate.test.sh 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green
2. `run` executes the wrapper with exactly `--json --permission-mode
   read-only --approval-policy never -`, the task file on stdin, never as an
   argument; no verb or option of the engine can select another permission
   mode. A test asserts the exact argv seen by a stub wrapper.
   CHECK: cd /home/bchanot/Documents/claude && grep -c -F -- "--json --permission-mode read-only --approval-policy never -" lib/tests/deepseek-delegate.test.sh lib/deepseek-delegate.sh | awk -F: '$2>=1{n++} END{print (n==2)?"both":"missing"}'
   EXPECT: both
   EVIDENCE: MET exit=0 marker-found :: both
3. Success only when the wrapper exits 0 AND the stream holds no `error`
   event and a last `final` event (`type` = `final`) whose `reason.kind` is
   `completed` and whose `text` is a string: then that text goes to stdout,
   exit 0. Wrapper nonzero (124 included), no `final`, `reason` null or
   another kind, an `error` event: exit 4, nothing on stdout, exactly one
   stderr line naming the cause and the kept work directory; the wrapper's
   own stderr is never copied to the engine's output. Each case has a test.
4. A run longer than the timeout is killed with its whole process group
   and exits 124 (tested: a sleeping stub and its child are both gone); a
   TERM sent to the engine's pid kills that group too (tested the same
   way); the bound uses a form that runs on GNU and BSD userland and the
   engine is bash 3.2-safe (BDR-110, BLK-026).
5. The wrapper runs in an empty temporary directory, not the caller's, and
   in an allowlisted environment: a fixed base list plus the `passEnv`
   names of the config, nothing else from the session (tested: the stub's
   cwd differs from the caller's; a canary variable is absent in the stub's
   dumped environment; a configured name is present). The engine adds the
   task kind, `DSH_TELEMETRY_DISABLED=1` and `DSH_TELEMETRY_MODE=DISABLED`.
6. `skills/deepseek-delegate/SKILL.md`: frontmatter `name`, `effort`,
   `description` saying it runs only on an explicit user ask; body covers the
   off fallback (Claude does the task and says DeepSeek was off), the
   self-contained brief with absolute paths written to a file, the ban on
   commit / push / write in the brief and on opening env or credential
   files (stated as prose, not enforcement), the run launched in the
   background, output treated as untrusted and attributed to DeepSeek, the
   first-run checklist, and the `dsh` homonym trap. No provider or company
   detail (names judged by the verifier against the request; they are
   deliberately not spelled in this tracked file).
   CHECK: cd /home/bchanot/Documents/claude && for f in skills/deepseek-delegate/SKILL.md lib/deepseek-delegate.sh; do [ -f "$f" ] || { echo "missing $f"; exit 1; }; done; n=$(cat skills/deepseek-delegate/SKILL.md lib/deepseek-delegate.sh | grep -c -E 'https?://' || true); [ "$n" -eq 0 ] && echo no-url
   EXPECT: no-url
   EVIDENCE: MET exit=0 marker-found :: no-url
7. The skill has its row in `mods/model-router/routing.json` and the
   routing, collision, portability and citer censuses stay green.
   CHECK: cd /home/bchanot/Documents/claude && make test suite="lib/tests/effort-routing.test.sh lib/tests/skill-routing-census.test.sh lib/tests/portability-census.test.sh lib/tests/doctrine-citers.test.sh" 2>&1 | tail -1
   EXPECT: all suites green
   EVIDENCE: MET exit=0 marker-found :: all suites green
8. `shellcheck lib/deepseek-delegate.sh lib/tests/deepseek-delegate.test.sh`
   is clean.
   CHECK: cd /home/bchanot/Documents/claude && shellcheck lib/deepseek-delegate.sh lib/tests/deepseek-delegate.test.sh && echo clean
   EXPECT: clean
   EVIDENCE: MET exit=0 marker-found :: clean
9. Not verified on this machine (no `dsh`, no wrapper): a real run. Reported
   as "not verified live"; the skill's Notes carry the first-run checklist
   (write probe, bogus preset, stripped environment, read outside the
   worker's directory, event shape, telemetry, session records).

## FILE SCOPE
lib/deepseek-delegate.sh (new)
lib/tests/deepseek-delegate.test.sh (new)
skills/deepseek-delegate/SKILL.md (new)
mods/model-router/routing.json (one skills row)
