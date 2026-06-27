#!/usr/bin/env bash
# === deploy runbook (reference) — NOT run directly. Instantiated to NEXT.sh per delta. ===
# Fixed steps run every deploy; # @delta: steps re-instantiate from the delta.
# @config push_deploy_tags=false
# NOTE grammar: glob=<pat>:each repeats the command per matching file (e.g. psql -f <each>);
#               glob=<pat>:list runs once + lists matching files as VERIFY items; when=<pat,...> is conditional.

# 1) backup BEFORE any forward-only migration
ssh "$DEPLOY_HOST" 'pg_dump "$DB" > ~/backups/pre-deploy-$(date +%F-%H%M).sql'   # VERIFY: dump size > 0

# @delta:migrations glob=supabase/migrations/*.sql:list
# 2) apply NEW migrations (one command; skill lists the delta migrations to VERIFY)
ssh "$DEPLOY_HOST" 'supabase migration up'                                       # VERIFY: "Applied" for each

# @delta:rebuild when=docker-compose*.yml,Dockerfile,Dockerfile.*
# 3) rebuild + restart services (only if build inputs changed)
ssh "$DEPLOY_HOST" 'docker compose up -d --build'                                # VERIFY: docker compose ps healthy

# @delta:deps when=package.json,*lock*,requirements.txt,pyproject.toml
# 4) install deps (only if manifests changed)
ssh "$DEPLOY_HOST" 'cd app && npm ci'                                            # VERIFY: exit 0

# 5) reload cache + smoke test (fixed)
ssh "$DEPLOY_HOST" 'systemctl reload app'
curl -fsS https://$DEPLOY_HOST/health                                            # VERIFY: HTTP 200
