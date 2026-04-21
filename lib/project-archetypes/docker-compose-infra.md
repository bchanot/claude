---
name: docker-compose-infra
category: meta
public: false
database: optional
hosting_hints:
  - vps
  - bare-metal
  - homelab
audit_stack:
  - analyze
  - code-clean
  - cso
  - doc
plugins:
  context7: no
  ui-ux-pro-max: no
  gstack: no
---

# Docker Compose Infrastructure

Stack docker-compose orchestrant services externes (DB, cache, reverse proxy, monitoring, apps déployables) — pas de code applicatif au root. Exemple : stack homelab / VPS / environnement local partagé.

## Detection signals

### Strong signals (×3)
- FILE: `docker-compose.yml` OR `docker-compose.yaml`
- FILE: `compose.yml` OR `compose.yaml` (syntaxe moderne)
- FILE: plusieurs `docker-compose.*.yml` (override, prod, dev)

### Medium signals (×2)
- FILE: `.env.example` avec vars de services (POSTGRES_PASSWORD, REDIS_PASSWORD, etc.)
- DIR: `configs/` OR `conf/` OR `volumes/` avec configs de services (nginx.conf, redis.conf, postgresql.conf)
- FILE: `Makefile` avec cibles docker (`up:`, `down:`, `restart:`, `logs:`)
- DIR: `traefik/` OR `nginx/` OR `caddy/` (reverse proxy configs)
- FILE: `.dockerignore`

### Weak signals (×1)
- DIR: `scripts/` avec scripts d'init DB / backup
- FILE: `backup.sh` OR `restore.sh`
- DIR: `data/` (gitignored, volumes montés)

### Counter-signals (exclusion)
- FILE: `package.json` AVEC deps applicatives (react/next/express/...) → c'est une app, pas de l'infra-only
- FILE: `pyproject.toml` AVEC `[project.scripts]` → app Python
- FILE: `Cargo.toml` → app Rust
- DIR: `src/` significatif avec code métier → c'est une app, pas du pur infra

## Implications
- **Hébergement** : VPS / bare-metal / homelab (Raspberry Pi, NAS)
- **Base de données** : souvent incluse dans la stack (Postgres/MySQL/Redis/Mongo)
- **SEO/GEO** : N/A
- **Surface sécurité** : GRANDE — secrets, ports exposés, privilèges containers
- **UI/UX** : N/A

## Typical pain points
- `.env` committé avec credentials
- Images `:latest` (pas de versions pinnées) → upgrades casse-stack
- `privileged: true` abusif
- Ports exposés sur 0.0.0.0 sans firewall (DB accessible Internet !)
- Pas de healthchecks
- Pas de restart policy
- Volumes non nommés (data perdue à la recréation)
- Pas de backup automatique (cron, restic, borg)
- Logs non centralisés ni rotés
- Reverse proxy sans TLS (Let's Encrypt absent)
- Network default bridge avec tous services (pas d'isolation)
- User `root` dans containers (privilege escalation)
- Resources limits absents (un service OOM-kill les autres)
- Secrets en environment (visibles `docker inspect`)
- Images Dockerfile non custom : `postgres:15` nu sans hardening

## Interview questions (adaptive)
En plus du set minimum business :
- OS host : Ubuntu / Debian / CoreOS / autre ?
- Services principaux dans la stack (DB / cache / reverse proxy / monitoring / apps) ?
- Reverse proxy : Traefik / Caddy / nginx / aucun ?
- TLS : Let's Encrypt / certs custom / aucun ?
- Secrets management : .env / Docker secrets / Vault / autre ?
- Backup strategy : aucun / manuel / automatisé (quoi ?) ?
- Monitoring / logs : Portainer / Grafana / Loki / ELK / aucun ?
- Uptime monitoring externe : UptimeRobot / BetterStack / aucun ?
- Mise à jour des images : manuelle / Watchtower / Renovate / aucune ?
- Restrictions réseau (firewall, fail2ban) ?
- Multi-env : dev + prod séparés ?

## Plugin recommendations
- **context7** : OFF (Docker/Compose stable)
- **ui-ux-pro-max** : OFF
- **gstack** : OFF

## Example project layout
```
docker-compose.yml
docker-compose.prod.yml    (override prod)
.env.example
.dockerignore
Makefile                    (up:/down:/logs:/backup:)
configs/
  nginx/
    default.conf
  traefik/
    traefik.yml
    dynamic.yml
  postgres/
    init.sql
scripts/
  backup.sh
  restore.sh
volumes/                    (gitignored data)
README.md
```
