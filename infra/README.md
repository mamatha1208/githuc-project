# Infra

```
infra/
├── modules/
│   └── container_apps/      # reusable: RG, ACR, Log Analytics, Container Apps env + app
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── environments/
    └── prod/                # environment-specific: backend, provider, sizing, tfvars
        ├── providers.tf     # remote state backend + azurerm provider
        ├── variables.tf
        ├── main.tf          # calls module "app" { source = "../../modules/container_apps" }
        └── outputs.tf
```

The module has no backend block and no hardcoded environment name — it just
defines "a container-apps platform" given inputs. Each environment directory
(`prod/`, and `staging/` etc. if you add one later) has its own state file,
its own backend key, and its own sizing, but all share the same module
source. To add `staging`, copy `environments/prod/` to `environments/staging/`,
change the backend `key` and the module's `environment`/sizing inputs — no
changes needed in `modules/container_apps/`.

CI runs Terraform from `infra/environments/prod` (see `working-directory` in
`ci.yml`'s `deploy` job).

## What this provisions
- Resource group
- Azure Container Registry (ACR) — admin login disabled; pulls happen via
  the Container App's system-assigned managed identity + an `AcrPull` role
  assignment, so no registry credentials exist anywhere.
- Log Analytics workspace + Container Apps environment
- A Container App running in `revision_mode = "Multiple"`, which is the
  detail that makes rollback cheap (see below).

## One-time setup (do this before the workflow can run)

1. **Terraform state backend** — create the storage account/container
   referenced in `environments/prod/providers.tf` (`tfstate-rg` /
   `tfstateuniquename001` / `tfstate`) once, by hand or via a small
   bootstrap script. Terraform can't create the backend it's about to store
   state in.

2. **Azure OIDC federation** (so CI never holds a client secret):
   - Create an App Registration in Entra ID.
   - Add a federated credential scoped to `repo:<org>/<repo>:ref:refs/heads/main`
     (Entra ID → App registrations → your app → Certificates & secrets →
     Federated credentials → GitHub Actions).
   - Grant that app's service principal `Contributor` on the target
     subscription/resource group (or a tighter custom role covering RG,
     ACR, Container Apps, Log Analytics, and role-assignment write).
   - Add `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` as
     repository (or environment) secrets — these are IDs, not credentials;
     the actual auth is the OIDC token exchange.

3. **GitHub Environment with required reviewer**:
   - Repo → Settings → Environments → New environment → `production`.
   - Check **"Required reviewers"** and add at least one person/team.
   - Optionally restrict which branches can deploy to this environment to
     `main` only, and add a wait timer if you want a cooling-off period.
   - This can't be expressed in the workflow YAML itself — it's what makes
     the `deploy` job pause for approval even though it's queued
     automatically by the `push` trigger.

## Rollback strategy

Container Apps' `Multiple` revision mode means every deploy creates a new,
independently-addressable revision rather than mutating the running one.
That gives two rollback paths, cheapest first:

1. **Traffic shift (fastest, no rebuild, no Terraform run)** — Azure keeps
   inactive revisions around by default. If the new revision is unhealthy:
   ```bash
   az containerapp revision list -n <app> -g <rg> -o table
   az containerapp ingress traffic set \
     -n <app> -g <rg> \
     --revision-weight <previous-revision-name>=100
   ```
   This is instant (traffic re-routes, no new container build/pull) and is
   what I'd reach for during an active incident.

2. **Re-deploy a known-good tag via the pipeline** — since every image is
   tagged with its git SHA and pushed to ACR only after passing tests +
   Trivy, "rollback" can also mean re-running the `deploy` job with an older
   SHA:
   ```bash
   terraform apply -var="container_image_tag=<previous-good-sha>"
   ```
   (run from `infra/environments/prod`) or via `workflow_dispatch` with a
   `sha` input wired to the same job, if you want a button-press rollback
   instead of a shell command. This still goes through the `production`
   Environment's required-reviewer gate, which is usually fine for a
   rollback (it's a small, known-safe change) but is worth keeping in mind
   if you need an emergency bypass path.

Because the registry always keeps prior tags (nothing is overwritten,
`latest` is just an extra pointer) and `min_replicas` keeps the environment
warm, both paths avoid a cold rebuild — rollback is a redeploy of something
that already passed CI, not a new build under pressure.
