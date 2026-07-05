#!/usr/bin/env bash
# === deploy runbook (reference) — NOT run directly. Instantiated into the deploy checklist per delta. ===
# Fixed steps run every deploy; # @delta: steps re-instantiate from the delta.
# @config push_deploy_tags=false
# NOTE grammar: glob=<pat>:each repeats the command per matching file (e.g. psql -f <each>);
#               glob=<pat>:list runs once + lists matching files as VERIFY items; when=<pat,...> is conditional.
# Style: one command per line, as typed in an interactive session — step 1 opens
# the ssh session, later steps run ON the box; local steps say "(from your machine)".

# 1) connect + pull the desired branch (fixed)
ssh "$DEPLOY_HOST"
cd "$APP_DIR"
git pull                                                    # VERIFY: HEAD == target sha

# 2) backup BEFORE any forward-only migration
pg_dump "$DB" > ~/backups/pre-deploy-$(date +%F-%H%M).sql   # VERIFY: dump size > 0

# @delta:migrations glob=supabase/migrations/*.sql:list
# 3) apply NEW migrations (one command; the skill lists the delta migrations to VERIFY)
supabase migration up                                       # VERIFY: "Applied" for each

# @delta:rebuild when=docker-compose*.yml,Dockerfile,Dockerfile.*
# 4) rebuild + restart services (only if build inputs changed)
docker compose up -d --build                                # VERIFY: docker compose ps healthy

# @delta:deps when=package.json,*lock*,requirements.txt,pyproject.toml
# 5) install deps (only if manifests changed)
cd app
npm ci                                                      # VERIFY: exit 0

# 6) reload + smoke test
systemctl reload app
# (from your machine)
curl -fsS https://$DEPLOY_HOST/health                       # VERIFY: HTTP 200
