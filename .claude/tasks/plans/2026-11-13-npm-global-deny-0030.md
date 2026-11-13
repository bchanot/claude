# PLAN — npm-global-deny (hotfix fix)
Root cause: the four static deny lines override the classifier, so the soft_deny "Global npm installs" (vet then clear on a named package) never runs for the common spellings (TODO "user hand edit pending" since 2026-09-30, BDR-090: ask does not prompt under auto, soft_deny is the prompt tier).
Edit:
1. settings.json: delete lines 143-146 (the four `Bash(npm … -g|--global *)` deny entries); nothing else; soft_deny entry :600 unchanged (already names `npm install -g`, `npm i -g`, `npm add -g`, `--global`, flag after package).
2. lib/tests/push-guard.test.sh removed-ok heredoc (~:331-336): delete the two dead rows + their comments (`Bash(docker run * -v /:*)`, `Bash(git push * :*)`: absent from main = 3.0.0, so T42 no longer needs them), add
   `# soft_deny "Global npm installs" decides (user 2026-11-12)` + the four npm entries verbatim. `removed_ok_until=3.0.0` unchanged (next bump empties the list, TODO line).
Smoke: `jq . settings.json >/dev/null`, `bash lib/tests/push-guard.test.sh` (tail shows the pass line), then live `npm install -g --dry-run cowsay` in the main loop after commit.
Risk accepted by the user: global installs rest on the classifier + soft_deny prose (vet, user names package this turn).
