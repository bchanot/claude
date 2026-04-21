---
name: terraform-infra
category: meta
public: false
database: none
hosting_hints:
  - aws
  - gcp
  - azure
  - digitalocean
  - cloudflare
  - hetzner
audit_stack:
  - analyze
  - code-clean
  - cso
  - doc
plugins:
  context7: optional
  ui-ux-pro-max: no
  gstack: no
---

# Terraform Infrastructure-as-Code

Projet Terraform/OpenTofu définissant une infrastructure cloud. Pas de code applicatif — que des ressources cloud.

## Detection signals

### Strong signals (×3)
- EXT: 2+ fichiers `.tf` à la racine OU dans `modules/`
- FILE: `main.tf`
- FILE: `terraform.tfvars` OR `*.auto.tfvars` (attention: doit être gitignored)
- FILE: `.terraform.lock.hcl`

### Medium signals (×2)
- FILE: `variables.tf`
- FILE: `outputs.tf`
- FILE: `backend.tf` OR `versions.tf` OR `providers.tf`
- DIR: `modules/` contenant sous-modules `.tf`
- FILE: `terragrunt.hcl`

### Weak signals (×1)
- DIR: `.terraform/` (gitignored normalement)
- FILE: `.tflint.hcl`
- FILE: `.tfsec.yaml` OR `.checkov.yaml`
- DIR: `environments/` (dev/staging/prod en workspaces)

### Composition overlays
- **Terragrunt** : `terragrunt.hcl` présent → multi-env DRY
- **OpenTofu** : `opentofu.lock.hcl` OR `tofu.tf` → fork open-source, même archétype

## Implications
- **Cloud provider** : variable (AWS/GCP/Azure/DO/Cloudflare/Hetzner/mix)
- **Base de données** : N/A (mais peut provisionner des DBs managées)
- **SEO/GEO** : N/A
- **Surface sécurité** : CRITIQUE — un mauvais `.tf` peut ouvrir un S3 bucket publique ou IAM trop permissif
- **UI/UX** : N/A

## Typical pain points
- `terraform.tfvars` committé avec secrets (API keys, DB passwords)
- State file en local (pas de remote backend S3/GCS/Terraform Cloud)
- State file committé dans git (ÉNORME red flag — contient secrets en clair)
- Pas de state locking (DynamoDB / GCS lock) → corruption en équipe
- IAM policies trop permissives (`"*"` actions / resources)
- S3 buckets sans encryption, sans versioning, sans logging
- Security groups ingress `0.0.0.0/0` sur ports non-HTTP
- Secrets dans variables au lieu de secret manager
- Providers non pinned → breaking changes silencieuses
- Modules non versionnés (`source = "./modules/x"` au lieu de `git::...?ref=v1.0.0`)
- Pas de `tflint` / `tfsec` / `checkov` en CI
- Plan non reviewé avant apply (auto-approve en CI dangereux)
- Pas de `depends_on` explicite → ordre d'apply instable
- `count` / `for_each` mal utilisé → ressources détruites-recréées accidentellement

## Interview questions (adaptive)
En plus du set minimum business :
- Cloud provider(s) : AWS / GCP / Azure / DO / Cloudflare / Hetzner / multi ?
- Terraform ou OpenTofu ?
- Terragrunt utilisé ?
- State backend : local / S3+DynamoDB / GCS / Terraform Cloud / Spacelift / autre ?
- Multi-env : workspaces / modules / Terragrunt ?
- Pipeline CI : Atlantis / Terraform Cloud / GitHub Actions / GitLab / aucun ?
- Plan review obligatoire avant apply ?
- Secrets : Vault / AWS Secrets Manager / GCP Secret Manager / SOPS / autre ?
- Scanners sécu : tflint / tfsec / checkov / trivy ?
- Versions providers pinnées ?
- Drift detection (terraform plan régulier en CI) ?
- Disaster recovery plan (perte de state) ?

## Plugin recommendations
- **context7** : OPTIONAL — ON pour AWS/GCP providers (APIs évoluent)
- **ui-ux-pro-max** : OFF
- **gstack** : OFF

## Example project layout
```
main.tf
variables.tf
outputs.tf
providers.tf
versions.tf
backend.tf
terraform.tfvars        (GITIGNORED — contient secrets)
.terraform.lock.hcl
.tflint.hcl
modules/
  vpc/
    main.tf
    variables.tf
    outputs.tf
  ecs-service/
    ...
environments/
  dev/
    terragrunt.hcl
  prod/
    terragrunt.hcl
.github/
  workflows/
    terraform-plan.yml
    terraform-apply.yml
```
