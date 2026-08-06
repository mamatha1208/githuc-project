# ServiceLink DevOps Exercise — Ship a Container Through GitHub

A hands-on exercise you'll work through live, in this GitHub repository.
You have roughly 45 minutes. We care far more about HOW you think than about
finishing every milestone. Talk us through your decisions and trade-offs.

## The scenario
This repo contains a tiny Python web service (`app/`), a `Dockerfile`, and one
unit test. Build the path that takes this service from a commit to running
securely in production — using GitHub as the delivery platform.

## Before you write anything
Understand the repo and ask clarifying questions. Don't start building until
you know what you're building.

## Milestones (get M1 solid before moving on)

### Milestone 1 — Continuous Integration (required)
Replace `.github/workflows/ci.yml` with a real workflow that, on every pull
request and push to `main`:
- installs dependencies and runs the unit tests (pytest)
- builds the Docker image
Make the test a required status check (branch protection on `main`, or explain how).

### Milestone 2 — Secure the pipeline (expected)
On merge to `main`:
- scan the built image for vulnerabilities (e.g. Trivy) and fail on criticals
- push the image to a registry (GHCR or Azure Container Registry) using
  secrets / OIDC — never hardcoded credentials

### Milestone 3 — Infrastructure & deploy (stretch)
- In `infra/`, write Terraform for the deploy target (Azure preferred: ACR +
  Azure Container Apps or AKS; your own cloud is fine if you map it to Azure)
- Add a deploy job gated on a GitHub Environment with a required reviewer
- Be ready to explain your rollback strategy

## Ground rules
- AI tools are encouraged (Claude, Copilot, Cursor). Using them well is a
  positive signal — but understand and be able to defend every line.
- Commit often and open a pull request; we'll follow along in the Actions tab.
- Ask questions at any point.

## Running locally (optional)
    pip install -r app/requirements.txt
    pytest app/
    python app/app.py
    docker build -t widget-api . && docker run -p 8080:8080 widget-api

---

## Implementation notes (this solution)

### Milestone 1 — CI
`test` and `build` jobs run on every PR and every push to `main`: install
deps, run pytest, then build the Docker image (build-only, not pushed, so PRs
from forks can't leak a registry credential).

Branch protection can't be expressed in the workflow YAML itself — it's a
repo setting. To make the test required:
`Settings → Branches → Add rule → main → Require status checks to pass →
select "Test"`. Also enable "Require branches to be up to date before
merging".

### Milestone 2 — Secure the pipeline
`scan-and-push` runs only on push to `main` (i.e. after merge). It reloads
the image built in the `build` job, scans it with Trivy and fails the job on
any CRITICAL vulnerability, then pushes to GHCR using the workflow's
short-lived `GITHUB_TOKEN` — no PAT or long-lived credential is stored in the
repo.

### Milestone 3 — Infrastructure & deploy
`infra/main.tf` provisions an Azure Container Apps environment and app that
pulls the image pushed to GHCR. The `deploy` job is gated on the `production`
GitHub Environment — configure that environment with a required reviewer
under `Settings → Environments → production → Required reviewers`. Azure
auth uses `azure/login` with OIDC federated credentials (`AZURE_CLIENT_ID`,
`AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` secrets) instead of a client
secret.

**Rollback strategy:** the app runs in `Single` revision mode, so the
previous revision stays provisioned (but inactive) until a new one is
healthy. Rolling back means re-running the deploy with the previous image's
git SHA as `image_tag` — Terraform just repoints the revision, no rebuild
needed. For a faster path in an incident, `az containerapp revision activate`
against the last-known-good revision works without touching Terraform state
at all.

**Secrets/config this pipeline expects** (repo or environment secrets):
`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`,
`TFSTATE_RESOURCE_GROUP`, `TFSTATE_STORAGE_ACCOUNT` (an existing storage
account for the Terraform remote state backend — not created by this config,
since state has to live somewhere before Terraform can run).

**Trade-offs / what I'd revisit with more time:**
- The deploy pulls from GHCR rather than ACR, to avoid a bootstrap
  chicken-and-egg problem (ACR would need to exist before the first push).
  A more "Azure-native" version would provision ACR first, mirror/push there,
  and point Container Apps at it.
- No blue/green or canary traffic splitting — `traffic_weight` is 100% to
  latest, which is simplest but riskiest for a real production rollout.
- Terraform state backend config is intentionally left out of `main.tf` and
  injected via `-backend-config` at `terraform init` time in CI, so the same
  config works across environments without hardcoding a storage account.
