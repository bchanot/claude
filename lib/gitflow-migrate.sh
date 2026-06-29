#!/usr/bin/env bash
# gitflow-migrate.sh — migrate an existing repo to the gitflow model.
#   LOCAL  (no token): gitflow init existing → master→main, develop, socle, hook.
#   PROBE  (token, READ-ONLY): identity + scope/rights, before any write.
#   REMOTE (token, DESTRUCTIVE): push, default→main, protection, delete master.
#          Writes ordered reversible→irreversible; DELETE master is LAST and only
#          runs if every prior step succeeded. Halts on first failure.
# No `... | grep -q` under pipefail (SIGPIPE false-negative gotcha). Never echo the token.
set -uo pipefail
GITEA="${GITEA_URL:-https://git.bchanot.fr}"
OWNER="${GITEA_OWNER:-bchanot}"

# ── LOCAL half (token-free) ──────────────────────────────────────────────────
migrate_local() {                      # <repo-path>
  local repo="$1" renamed="no"
  cd "$repo" || { echo "  ✗ cannot cd $repo" >&2; return 1; }
  [ -z "$(git status --porcelain)" ] || { echo "  ✗ working tree not clean — stash/commit first" >&2; return 2; }
  { [ -n "$(git config user.name)" ] && [ -n "$(git config user.email)" ]; } \
    || { echo "  ✗ git identity unset (user.name/user.email) — set it before migrating $repo" >&2; return 3; }
  git show-ref --verify -q refs/heads/master && renamed="yes"
  bash "$HOME/.claude/lib/gitflow.sh" init || return 1
  git show-ref --verify -q refs/heads/main    || { echo "  ✗ no main"    >&2; return 1; }
  git show-ref --verify -q refs/heads/develop || { echo "  ✗ no develop" >&2; return 1; }
  [ "$(git config core.hooksPath)" = ".githooks" ] || { echo "  ✗ hook not active" >&2; return 1; }
  [ -z "$(git status --porcelain)" ] || { echo "  ✗ tree dirty after init" >&2; return 1; }
  echo "  ✓ local: main+develop, hook active, tree clean (master→main: $renamed)"
}

# ── Gitea API helper (token in header only; never printed) ────────────────────
_gitea() {                             # <METHOD> <api-path> [json-body]
  local m="$1" p="$2" body="${3:-}"
  curl -fsS -X "$m" -H "Authorization: token $GITEA_TOKEN" \
       -H "Content-Type: application/json" ${body:+-d "$body"} "$GITEA/api/v1$p"
}
_json() { python3 -c "import sys,json;$1" 2>/dev/null; }   # tiny JSON field reader

# ── PROBE (READ-ONLY: identity informational, rights = the real gate) ─────────
# /user needs read:user (cosmetic — the migration never calls it) → informational.
# The gates are the repo-scoped rights the writes actually require: admin+push on
# the repo, and admin scope confirmed by a readable branch_protections list.
gitea_probe() {                        # <repo-name to test rights against>
  local name="$1" me pj perm
  [ -n "${GITEA_TOKEN:-}" ] || { echo "  ✗ GITEA_TOKEN unset" >&2; return 1; }

  # [a] identity — INFORMATIONAL (needs read:user scope the migration never uses)
  if me=$(_gitea GET "/user" 2>/dev/null | _json "print(json.load(sys.stdin).get('login','?'))") && [ -n "$me" ]; then
    echo "  ✓ token identity: $me"
  else
    echo "  ⚠ token identity unavailable (no read:user scope) — cosmetic, migration is repo-scoped"
  fi

  # [b] repo rights — GATE: admin AND push must be true (default_branch, protections, push)
  pj=$(_gitea GET "/repos/$OWNER/$name") \
     || { echo "  ✗ GET /repos/$OWNER/$name failed — token lacks repo read scope" >&2; return 1; }
  perm=$(printf '%s' "$pj" | _json "p=json.load(sys.stdin).get('permissions',{});print('admin=%s push=%s pull=%s'%(p.get('admin'),p.get('push'),p.get('pull')))")
  printf '%s' "$pj" | _json "p=json.load(sys.stdin).get('permissions',{});sys.exit(0 if (p.get('admin') and p.get('push')) else 1)" \
     || { echo "  ✗ insufficient rights on $name ($perm) — need admin+push" >&2; return 1; }
  echo "  ✓ rights on $name: $perm (admin+push confirmed)"

  # [c] admin-scope canary — GATE: branch_protections readable (POST/PATCH/DELETE need repo-admin)
  _gitea GET "/repos/$OWNER/$name/branch_protections" >/dev/null \
     || { echo "  ✗ cannot read branch_protections — token lacks repo-admin scope; protection step would fail" >&2; return 1; }
  echo "  ✓ repo-admin scope confirmed (branch_protections readable → POST/PATCH/DELETE OK)"
}

# ── REMOTE half (DESTRUCTIVE; reversible→irreversible; delete master LAST) ────
_protect() {                           # <repo-name> <branch>  (Option 1: owner-pushable)
  _gitea POST "/repos/$OWNER/$1/branch_protections" \
    "{\"branch_name\":\"$2\",\"enable_push\":true,\"enable_push_whitelist\":true,\"push_whitelist_usernames\":[\"$OWNER\"]}"
}
migrate_remote() {                     # <repo-name>  (cwd = the local repo)
  local name="$1"
  [ -n "${GITEA_TOKEN:-}" ] || { echo "  ✗ GITEA_TOKEN unset" >&2; return 1; }
  echo "  [1/4] push main + develop (ADDITIVE/reversible)…"
  git push -u origin main    || { echo "  ✗ push main failed (push scope?) — STOP, nothing irreversible done" >&2; return 1; }
  git push -u origin develop || { echo "  ✗ push develop failed — STOP" >&2; return 1; }
  echo "  [2/4] default_branch → main (REVERSIBLE — scope canary)…"
  _gitea PATCH "/repos/$OWNER/$name" '{"default_branch":"main"}' >/dev/null \
    || { echo "  ✗ PATCH default_branch failed (admin/write scope?) — STOP before protection & delete" >&2; return 1; }
  echo "  [3/4] branch protection main + develop (REVERSIBLE)…"
  _protect "$name" main    >/dev/null || { echo "  ✗ protect main failed — STOP before delete" >&2; return 1; }
  _protect "$name" develop >/dev/null || { echo "  ✗ protect develop failed — STOP before delete" >&2; return 1; }
  echo "  [4/4] DELETE remote master (IRREVERSIBLE — last; default already repointed)…"
  git push origin --delete master || { echo "  ✗ delete master failed (left in place — safe)" >&2; return 1; }
  echo "  ✓ remote: default=main, main/develop protected (owner-pushable), remote master deleted"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  case "${1:-}" in
    local)  migrate_local "$2" ;;
    probe)  gitea_probe "$2" ;;
    remote) migrate_remote "$2" ;;
    *) echo "usage: gitflow-migrate.sh {local <repo>|probe <name>|remote <name>}" >&2; exit 2 ;;
  esac
fi
