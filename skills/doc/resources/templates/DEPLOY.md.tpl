# Deploy

Stack: {{STACK}}
Target: {{DEPLOY_TARGET}}<!-- e.g. Vercel, fly.io, Docker on VPS, k8s -->

## Prerequisites

- {{REQUIRED_TOOLS}}<!-- gh, fly, docker, kubectl, etc. -->
- Environment variables set in {{ENV_LOCATION}}<!-- .env / Vercel dashboard / GH secrets -->

## Build

```bash
{{BUILD_CMD}}
```

Verify the build artifact at `{{BUILD_OUTPUT_DIR}}` is non-empty before proceeding.

## Deploy

```bash
{{DEPLOY_CMD}}
```

## Verify

```bash
{{HEALTH_CHECK_CMD}}<!-- curl /healthz or equivalent -->
```

Expected response: `{{EXPECTED_RESPONSE}}`.

## Rollback

```bash
{{ROLLBACK_CMD}}<!-- e.g. fly releases rollback <id>, kubectl rollout undo, vercel rollback -->
```

## Common failures

| Symptom | Cause | Fix |
|---|---|---|
| {{SYMPTOM_1}} | {{CAUSE_1}} | {{FIX_1}} |
| Build fails on `{{COMMON_BUILD_ERR}}` | Likely env var missing | Check {{ENV_LOCATION}} has {{REQUIRED_VARS}} |

## Logs / monitoring

- Logs: `{{LOG_CMD}}`
- Monitoring: {{MONITORING_URL}}<!-- Grafana / Sentry / Vercel analytics -->
