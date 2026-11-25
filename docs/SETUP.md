# Setup

This document is the single source of truth for standing up the project. It is
written for the **local-first, zero-cost** path. The optional AWS production
path is described at the end and is never run by the agent.

If a step fails, see [Troubleshooting](#troubleshooting) before changing
anything. Every command in this document is expected to work from a fresh
clone.

## 1. Supported environments

| Environment | Status | Notes |
|---|---|---|
| Windows 10/11 + Git Bash | Primary | The repository is developed here. PowerShell is not required. |
| Linux (x86_64) | Supported | Use your package manager for the binaries listed below. |
| macOS (Intel or Apple silicon) | Supported | Use Homebrew for the binaries listed below. |

Docker Desktop must be running before `make local-up`, `docker build` or
`docker compose`. The local path needs no AWS account, no domain and no paid
service.

## 2. Prerequisites

| Tool | Version | Why it is needed |
|---|---|---|
| Git | 2.40+ | Version control and pre-commit |
| Python | 3.12+ | Application code, tests and Python-based linters |
| Docker Desktop | Current | kind nodes, image builds and docker compose |
| GNU Make | 4.4+ | Every developer entry point |
| kind | 0.33.0 | Local Kubernetes cluster |
| kubectl | 1.30+ | Cluster inspection |
| Helm | 4.x | Third-party platform charts |
| Kustomize | 5.x | Application overlays |
| Terraform | 1.17.2 | AWS production path, validation and mock tests |
| tflint, terraform-docs, checkov, trivy | See [VERSIONS.md](VERSIONS.md) | IaC quality and security |
| gitleaks, hadolint, yamllint, ruff | See [VERSIONS.md](VERSIONS.md) | Secret, Dockerfile, YAML and Python quality |
| kubeconform, actionlint, promtool | See [VERSIONS.md](VERSIONS.md) | Manifest, workflow and Prometheus rule validation |
| jq, yq, shellcheck | See [VERSIONS.md](VERSIONS.md) | Scripting helpers |

Exact pinned versions and sources are in [VERSIONS.md](VERSIONS.md). Do not
upgrade a tool without updating that file and re-running `make check`.

## 3. Install the toolchain

### Windows (Git Bash, recommended)

```bash
bash scripts/install-tools.sh
make tools-check
```

The installer places binaries in `tools/bin`, creates a Python virtual
environment in `.venv`, and installs the pinned Python tools. It does not
require administrator rights and does not touch system directories. Both
`tools/` and `.venv/` are gitignored.

If `make` is not on your PATH yet, run the downloaded binary directly:

```bash
./tools/bin/make.exe tools-check
```

### Linux and macOS

Create the Python environment and install the pinned tools:

```bash
python3 -m venv .venv
.venv/bin/pip install --upgrade pip
.venv/bin/pip install -r requirements-dev.txt
```

Install the remaining binaries with your package manager, matching the
versions in [VERSIONS.md](VERSIONS.md). For example, on macOS:

```bash
brew install make kind kubectl helm kustomize terraform tflint terraform-docs \
  checkov trivy gitleaks hadolint yamllint kubeconform actionlint jq yq shellcheck
```

Then run:

```bash
make tools-check
make check
```

### Verify the foundation

```bash
make help
make check
```

`make check` is the phase definition of done. It runs the linters, validators,
security scans and tests that exist at the current phase. `make validate` also
runs `terraform test` with mock providers and `scripts/apps-contract.sh`, which
compare the local overlay with the AWS overlays and assert that only the
documented substitutions differ (ADR-020). `make lint` includes
`workflows-validate`, which runs `actionlint` and the offline GitLab CI
contract checks. `make test` includes `policy-test`, which runs `kyverno test`
against compliant, violating and out-of-scope pods for all seven admission
policies. `make validate` also calls `observability-validate`, which runs
`promtool check rules`, `promtool test rules`, dashboard JSON checks, alert
metadata checks and runbook-link checks. Targets for later phases print a clear
"not implemented until Phase N" message and exit 0.

## 4. Local quickstart

The platform runs on a local `kind` cluster. Docker Desktop must be running.
This path creates no AWS resources and costs $0.

```bash
make local-up     # create the cluster, install Argo CD, apply the root app
make check        # verify manifests, policies, Terraform, secrets and tests
make local-down   # delete the cluster and everything in it
```

`make up` and `make down` are the guarded versions. They print exactly what
they will do and require an explicit `y` before acting. They only touch the
local kind cluster; they never call AWS.

### What `local-up` does

The script is deliberately short. It performs only the steps Argo CD cannot do
for itself:

1. Creates the `platformbox` kind cluster from `kind-config.yaml`.
2. Preloads the slow third-party images with `scripts/preload-images.sh`. The
   script pulls them on the host, where the network is more reliable, then loads
   them into every kind node. It preserves `@sha256:` pins when a chart uses one.
3. Installs Argo CD with Helm, pinned in `scripts/local-up.sh`.
4. Applies the two `AppProject` resources from `gitops/projects`.
5. Applies the root `Application` from `gitops/bootstrap/root-app.yaml`.

Everything else — ingress-nginx, External Secrets, Kyverno, the policies,
monitoring, logging, Argo Rollouts and the application ApplicationSets — is
synced by Argo CD from `gitops/platform`. Do not install any
of those directly; there is a single source of truth. See
[ADR-010](adr/ADR-010-local-platform-bootstrap.md).

**Which revision is deployed.** The committed root Application follows `main`.
When you run `local-up` from a branch that exists on `origin`, the script points
the root app at that branch so the manifests in your checkout are deployed.
After the pull request is merged, running from `main` restores the committed
behaviour. A missing source path renders as a *healthy but empty* Application,
so check that the seven child Applications and two ApplicationSets exist:

```bash
kubectl get applications,applicationsets -n argocd
```

The ApplicationSets intentionally generate nothing on kind: their cluster
selector requires a registered EKS cluster Secret labelled
`platformbox.io/target: eks`. This is recorded in ADR-015.

### Accessing the platform

```bash
# Argo CD UI: https://localhost:8080 (use -n argocd, port-forward)
kubectl port-forward svc/argocd-server -n argocd 8080:443
# username: admin
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d

# Grafana (after the monitoring app is healthy)
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80
# username: admin; the local demo password is in gitops/platform/monitoring.yaml

# Application ingress
curl -I http://localhost
```

The Grafana credential is a public, local-only demo value. It is never used
outside kind. Never reuse it for a real installation.

### Running the Phase 4 application smoke test

With the kind cluster already up:

```bash
make local-smoke
```

The script preloads the pinned ESO and data-service images, builds
`platformbox-{api,worker,frontend}:local`, loads them into kind, waits for the
External Secrets CRDs, applies `gitops/apps/local-data` and `gitops/apps/local`,
then checks `/health`, `/ready`, the frontend and the opt-in chaos endpoint
through port-forwards. Expected result: health and readiness return HTTP 200,
the frontend returns HTTP 200, and `POST /chaos/fail` returns HTTP 503 in the
local namespace.

No AWS account, registry credential or domain is needed. Details are in
[docs/architecture.md](architecture.md) and
[ADR-016](adr/ADR-016-local-fake-secret-store.md).

## 5. GitHub repository setup

1. Confirm the `origin` remote points at your repository. Push `main` and the
   current phase branch; never push directly to `main` during a phase.
2. Protect `main` with these settings:
   - Require a pull request before merging.
   - Require at least one approval.
   - Require status checks to pass before merging.
   - Require conversation resolution.
   - Require linear history.
   - Do not allow force pushes or deletions.
   - If you restrict who can push, add the identity that owns the write-back
     token described below to the bypass list. Without this, the ADR-003
     commit from GitLab CI will be rejected by branch protection.
3. Set the default GitHub Actions token permissions to read-only. Every
   workflow declares its own minimal `permissions:` block.
4. Create a `dev` environment with required reviewers. The
   `terraform-apply` workflow waits for approval there. Leaving the job
   waiting is a safe way to test it; approving it creates AWS resources.
5. Add the secrets and variables below. Use repository-level values for
   read-only plan configuration; never paste a value into a workflow file.

For phase pull requests, `@atharvvv10` approves and `@akashhh15` merges. Do not
self-approve, use an admin bypass, or push directly to `main`.

### GitHub secrets

| Name | Used by | Purpose |
|---|---|---|
| `GITLAB_MIRROR_TOKEN` | `mirror-to-gitlab.yml` | GitLab personal or project access token with `write_repository` on the target project |
| `INFRACOST_API_KEY` | `terraform-ci.yml` | Optional Infracost API key for the PR cost diff |

### GitHub variables

| Name | Used by | Purpose |
|---|---|---|
| `GITLAB_PROJECT_PATH` | `mirror-to-gitlab.yml` | Target GitLab path, for example `my-group/platformbox` |
| `AWS_PLAN_ROLE_ARN` | `terraform-ci.yml`, `drift-detection.yml` | Read-only OIDC role for `terraform plan` |
| `AWS_APPLY_ROLE_ARN` | `terraform-apply.yml` | Apply OIDC role; only trusted for `main` and the protected `dev` environment |
| `TF_STATE_BUCKET` | plan, apply and drift workflows | S3 state bucket created by `infra/bootstrap` |
| `AWS_REGION` | plan, apply and drift workflows | Optional; defaults to `ap-south-1` |

`GITOPS_WRITE_TOKEN` is **not** a GitHub Actions secret. It is a GitHub
fine-grained personal access token used by GitLab CI, so it is stored as a
GitLab CI/CD variable.

## 6. GitLab project setup

1. Create the GitLab project and record its path for `GITLAB_PROJECT_PATH`.
2. The `mirror-to-gitlab` workflow pushes `main` to it. If `main` is protected,
   allow the mirror token to push to it.
3. Protect `main` and require a successful pipeline before merging.
4. Use GitLab.com shared runners or a self-hosted runner with the Docker
   executor. The Buildah jobs do not need privileged mode or a Docker socket.
5. Add these CI/CD variables. Mark the token masked and protected.

| Name | Used by | Purpose |
|---|---|---|
| `GITOPS_WRITE_TOKEN` | `deploy-gitops-dev` | Fine-grained GitHub PAT with `Contents: Read and write` on this repository, allowed to push the write-back commit |
| `GITHUB_REPOSITORY` | `deploy-gitops-dev` | GitHub repository in `owner/name` form, for example `akashhh15/platformbox` |
| `ECR_REGISTRY` | build, sign and write-back jobs | ECR host, for example `123456789012.dkr.ecr.ap-south-1.amazonaws.com`; take it from the Terraform ECR output |
| `AWS_ECR_PUSH_ROLE_ARN` | build and sign jobs | OIDC role trusted for this GitLab project and `main`; no static AWS keys |
| `AWS_REGION` | build and sign jobs | Optional; the pipeline defaults to `ap-south-1` |

The `id_tokens` for Sigstore (`aud: sigstore`) and AWS STS
(`aud: sts.amazonaws.com`) are declared in `.gitlab-ci.yml`; they are not
manual variables. The AWS IAM roles must trust `https://gitlab.com` with a
subject scoped to this project and `main`.

## 7. Pipeline test plan (human-run)

The agent can validate syntax and contract shape offline, but it cannot run
GitHub Actions or GitLab CI. Run the following checks yourself.

### GitHub Actions

1. Open a test pull request from a branch in the same repository with a
   Conventional Commit title such as `ci: test github actions`. Touch a file
   under `infra/` and a file under `gitops/` so the path-filtered workflows
   also run. A harmless comment in `infra/environments/dev/main.tf` and
   `gitops/apps/overlays/dev/kustomization.yaml` is enough.
2. Confirm these checks appear and pass: `conventional-title`,
   `static-checks`, `render and validate manifests`, `gitleaks`,
   `workflow configuration` and `CodeQL Python`. `dependency review` is
   best-effort: it passes with a warning if GitHub's dependency graph API is
   unavailable. Enable the dependency graph in repository settings to make it
   enforce dependency policy.
3. `plan dev` is skipped unless `AWS_PLAN_ROLE_ARN` and `TF_STATE_BUCKET` are
   set; `cost estimate` is skipped unless `INFRACOST_API_KEY` is set. With
   those values present, confirm both checks pass and post their PR comments.
   Exit code `2` from `terraform plan` is expected when changes are proposed.
4. Open a second test PR from a **fork**, touching `infra/` again. Confirm
   `plan dev` and `cost estimate` are skipped and that no AWS credentials are
   configured in that run.
5. Run **Actions → drift-detection → Run workflow**. It should run
   `scheduled dev plan` and open or update a drift issue. It must not apply.
6. Test `terraform-apply` safely by merging an infra PR but leaving the
   `dev` environment approval pending. Confirm the job waits. Do **not**
   approve unless you intend to create real AWS resources.
7. Merge the Phase 5 PR to `main`. Confirm `mirror-to-gitlab` pushes `main` to
   the GitLab project. A later commit that changes only `gitops/**` must not
   trigger the mirror.

### GitLab CI

1. Set every GitLab variable from section 6, including the ECR role and
   registry. Push a branch with a change under `apps/`, or use
   **Build → Pipelines → Run pipeline** with that branch as the ref.
2. Confirm the `lint`, `test`, `build`, `scan`, `sign` and `publish` stages all
   run. The service jobs are parallel matrices named `build: [api]`,
   `trivy-image: [api]`, `sbom: [api]` and `sign: [api]`, with equivalent jobs
   for `worker` and `frontend`. `deploy-gitops-dev` is manual on every ref and
   should not run automatically.
3. Download the job artifacts and check: JUnit XML from `pytest`, SAST and
   secret detection reports, `trivy-fs.json`, three `*-image.json` reports,
   three `*.cyclonedx.json` SBOMs, `release.json` and `pipeline-summary.md`.
4. In a `sign: [<service>]` job log, confirm the image is a digest reference
   with exactly one `@sha256:` and that Cosign reports a stored signature and
   attestation.
   Verify it from your machine (replace the project path):
   ```bash
   cosign verify "$IMAGE" \
     --certificate-identity \
       "https://gitlab.com/<namespace>/<project>//.gitlab-ci.yml@refs/heads/main" \
     --certificate-oidc-issuer "https://gitlab.com"
   ```
5. In the ECR console, confirm the three repositories have immutable tags and
   that the tags match `$CI_COMMIT_SHORT_SHA-$SERVICE`.
6. On `main`, run the manual `deploy-gitops-dev` job. Confirm it pushes one
   commit whose message contains `[skip ci]`, that only
   `gitops/apps/overlays/dev/kustomization.yaml` changed, and that the new
   image references are ECR digests.
7. Confirm that the write-back commit starts **no** new GitLab pipeline and
   **no** GitHub mirror run. Push another commit that changes only `gitops/**`
   as a negative test.
8. Confirm a build job log contains `Assumed ... with short-lived STS
   credentials` and that no `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY`
   CI variable exists.

## 8. Observability and alert verification

Phase 7 resources are validated statically by:

```bash
make observability-validate
```

That target extracts the `PrometheusRule.spec` into a temporary plain rules
file before calling `promtool`, validates six dashboard JSON files and their
Grafana UIDs, checks that all ten alerts carry severity/summary/description/
runbook metadata, confirms each runbook exists, and asserts that Slack resources
are not generated in the default platform render. No cluster or cloud API is
used.

With `make local-up` and `make local-smoke` already running, verify the runtime
path yourself:

1. Open Grafana with the port-forward in section 4. Confirm these dashboards
   appear: **PlatformBox / Cluster overview**, **Nodes and Karpenter**, **Argo
   CD**, **API RED metrics**, **Worker queue and latency**, and **Kyverno policy
   results**. Karpenter panels are expected to be empty on kind.
2. Open Prometheus at `kubectl -n monitoring port-forward
   svc/monitoring-kube-prometheus-prometheus 9090:9090`, then visit
   `http://localhost:9090/rules`. All `platformbox-*` groups should show as
   loaded. Query
   `platformbox:slo:api_availability:error_budget_remaining_ratio` after some
   app traffic to see the 30-day budget gauge.
3. Open Alertmanager at `kubectl -n monitoring port-forward
   svc/monitoring-kube-prometheus-alertmanager 9093:9093`. On kind the default
   receiver is `null`; no Slack Secret is required.
4. Select the `loki` datasource in Grafana Explore and run a query from
   [docs/log-queries.md](log-queries.md), for example
   `{namespace="app-dev", app="api", level="ERROR"}`. Structured fields
   `service`, `environment`, `version` and `level` are promoted by Promtail.
5. Send a test alert only on a cluster where Slack is deliberately enabled.

### Slack alerts (opt-in on EKS)

The chart's default Alertmanager config has a `null` receiver, so the local
demo works without Slack. Slack routing is generated only for registered EKS
cluster Secrets labelled `platformbox.io/target: eks` **and**
`platformbox.io/slack-alerting: "true"`. This avoids a missing-Secret failure
during Alertmanager config generation on kind; see ADR-025.

To enable Slack on EKS:

1. Create an incoming webhook in your Slack workspace.
2. Create the AWS Secrets Manager secret `platformbox/alertmanager` with the
   JSON property `webhook_url`. The External Secrets Operator reads it through
   the EKS-gated `aws-secretsmanager` ClusterSecretStore.
3. Add `platformbox.io/slack-alerting: "true"` to that cluster's Argo CD
   cluster Secret, in addition to `platformbox.io/target: eks`.
4. Wait for the `alertmanager-slack` Application to sync, then check the
   generated Secret in the `monitoring` namespace and send a test alert.
   Never put the webhook URL in Git or in a Helm value.

## 9. Optional AWS production path (costs money)

**Do not run this unless you explicitly want a paid demo.** The agent never
runs `terraform apply`, `terraform destroy`, or any AWS CLI command that
creates, changes or deletes resources. Read
[ADR-000](adr/ADR-000-local-first-zero-cost.md) first.

If you choose to use it:

1. Create an AWS account, enable MFA, and stop using the root user.
2. Create an administrative user or SSO profile for bootstrap only.
3. Create an AWS Budget with e-mail alerts before creating anything else.
4. Review the estimates in ADR-000 and the AWS Pricing Calculator.
5. Apply `infra/bootstrap` locally with your own credentials.
6. Fill in `infra/environments/dev/terraform.tfvars` from the example file.
7. Apply `infra/environments/dev` yourself, then destroy it after the demo.

Region default: `ap-south-1`. Every environment and module takes the region as
a variable; nothing is hardcoded.

## 10. Human tasks

These cannot be completed by the agent. Check them off as you go.

- [x] Start Docker Desktop and confirm `docker info` succeeds.
- [x] Set `git config --global user.name` and `user.email`.
- [x] Create the GitHub repository and push the branches.
- [x] Confirm `.github/CODEOWNERS` names the real repository owner.
- [x] Configure branch protection on `main`.
- [ ] Add every GitHub secret and variable from section 5.
- [ ] Create the GitLab project and record its path in `GITLAB_PROJECT_PATH`.
- [ ] Add every GitLab CI/CD variable from section 6, including the ECR OIDC
      role and registry host.
- [ ] Allow the write-back identity to push to protected `main`, or add its
      bypass rule; otherwise ADR-003 cannot work.
- [ ] Configure the GitHub, GitLab and AWS OIDC trust relationships with the
      exact repository/project, branch and environment restrictions.
- [ ] Run the GitHub and GitLab pipeline tests in section 7. Do not approve
      `terraform-apply` unless you intend to create AWS resources.
- [ ] If Slack is wanted on EKS, create the AWS Secrets Manager secret
      `platformbox/alertmanager` with property `webhook_url` and add the
      `platformbox.io/slack-alerting: "true"` cluster label (§8, ADR-025).
- [ ] With Docker Desktop running, verify the six dashboards, Prometheus rule
      groups, Alertmanager null receiver and a Loki query on kind (§8).
- [ ] With Docker Desktop running, run the good and bad canary demos and capture
      the screenshots listed in `docs/demo.md`. No AWS resources are involved.
- [ ] Decide whether to run the optional AWS path; if yes, complete the AWS
      account, MFA and budget steps above.
- [ ] If you deploy to EKS, register the cluster in Argo CD with the label
      `platformbox.io/target: eks`; without it the ApplicationSets generate no
      environment Applications (ADR-015).
- [ ] If you deploy the AWS overlays, annotate the ESO ServiceAccount with the
      IRSA role ARN from the Terraform output so the committed
      `aws-secretsmanager` ClusterSecretStore can read Secrets Manager:
      `kubectl annotate serviceaccount external-secrets -n external-secrets eks.amazonaws.com/role-arn=<role_arn> --overwrite`.
      The store is generated only on clusters labelled
      `platformbox.io/target: eks` (ADR-019); kind generates none.
- [ ] If you use a real domain, supply its value and an ACM certificate ARN as
      variables and add the TLS Ingress patch; no hostname is committed.
- [ ] If you deploy the AWS overlays, patch the app NetworkPolicies with an
      `ipBlock` allow for your VPC CIDR so ALB traffic reaches the pods.
- [ ] Run `make check` on a fresh clone and report any environment-specific
      failure.

## 11. Troubleshooting

### `make: command not found`

The installer places `make.exe` in `tools/bin`. Either run
`./tools/bin/make.exe <target>` or add `tools/bin` to your shell PATH. The
Makefile itself prepends `tools/bin` and `.venv/Scripts` for the commands it
runs.

### PowerShell is blocked by group policy

OpenCode is configured to use Git Bash in this environment. If a new shell
still tries PowerShell, set the `shell` field in your local `opencode.json` to
the absolute path of `bash.exe` and restart the session.

### Docker daemon is not running

Start Docker Desktop and wait for the whale icon to become stable. Then run
`docker info`. kind, image builds and docker compose all need it.

### `gitleaks` not found during `git commit`

The pre-commit hook calls `gitleaks` directly, which is not on the system
PATH by default. Export it before committing:

    export PATH="/d/Devops Projects/tools/bin:$PATH"

The Makefile already prepends `tools/bin` for its own targets, so this is only
needed for raw `git commit`.

### `terraform init` fails with "not enough space on the disk"

The C: drive in this environment is small. Point Terraform's temp directory at
the D: drive before init:

    export TMP="D:/tmp"; export TEMP="D:/tmp"
    mkdir -p D:/tmp
### Python opens the Microsoft Store

The `python3` alias on Windows can point to the Store stub. Use `python` (the
real Python 3.13 installation) or disable the app execution alias in Windows
Settings. The Makefile uses `python` on Windows.

### Line-ending warnings

`.gitattributes` enforces LF. On Windows, set
`git config --global core.autocrlf false` and re-checkout the repository if
files were already converted.

### A GitHub release download stalls

GitHub's release CDN is occasionally slow on some networks. The installer gives
up after 15 minutes per file and prints the URL. Install that tool with winget
instead, then re-run `make tools` (the script skips tools already present in
`tools/bin`):

```powershell
winget install --id TerraformLinters.tflint -e
winget install --id Terraform-docs.Terraform-docs -e
winget install --id Gitleaks.Gitleaks -e
winget install --id hadolint.hadolint -e
winget install --id AquaSecurity.Trivy -e
```

Copy the installed executable into `tools/bin` so the Makefile and pre-commit
use the pinned copy, then verify with `make tools-check`.

### Pre-commit hook failures

Run `make tools` to install the pinned binaries, then
`make pre-commit-install`. For a single hook, run
`pre-commit run <hook-id> --all-files`. Do not bypass hooks with
`--no-verify` unless you are diagnosing a broken hook, and never commit the
bypass.

### kind cluster fails to start

Give Docker Desktop at least 8 GB of memory and 4 CPUs. Delete the stale
cluster with `kind delete cluster --name platformbox`, then rerun
`make local-up`.

If Docker reports `read-only file system` when creating containers, its data
disk is full. Free space on the host drive first, restart Docker Desktop, then
remove unused images and caches with `docker system prune` before retrying.
The kind node image is large (~1.3 GB unpacked); keep at least 5 GB free on the
drive that holds the Docker data.

### A platform pod is stuck in `ImagePullBackOff`

Some registries are slow from the kind node network. `make local-up` preloads
the images listed in `scripts/preload-images.sh`, so a fresh cluster should not
need to pull them at pod start. If a pod still reports `ImagePullBackOff`, run
the helper again:

```bash
bash scripts/preload-images.sh platformbox
```

The script is idempotent: it skips images already present on the first node.
For an image digest pin, it records the digest in the archive manifest so the
kubelet resolves the local copy instead of contacting the registry.

Run the helper as part of `make local-up`, before the platform apps start. Do
not run it against a busy cluster: image pulls and `kind load` share the Docker
disk with etcd, and heavy I/O can make etcd report `slow fdatasync` and cause
transient control-plane leader losses. If images are missing after startup,
prefer `make local-down` followed by `make local-up`.

### `local-smoke` waits forever for External Secrets CRDs

Check that the `external-secrets` Application is `Synced`/`Healthy` and that the
image was preloaded:

```bash
kubectl get application external-secrets -n argocd
kubectl get crd externalsecrets.external-secrets.io
bash scripts/preload-images.sh platformbox
```

The operator is installed by Argo CD with chart version 2.15.0. Do not create
the CRDs by hand; that would diverge from the GitOps source of truth.

### Argo CD reports `metadata.annotations: Too long` on a CRD

Kyverno ships CRDs larger than the 262144-byte Kubernetes annotation limit.
All platform Applications set `ServerSideApply=true` and
`ClientSideApplyMigration=false` through
`gitops/platform/kustomization.yaml`. Do not remove those options. See
[ADR-011](adr/ADR-011-argocd-server-side-apply.md).

If a sync waits on `kyverno-migrate-resources`, the Kyverno upgrade hooks are
still enabled. They are disabled in `gitops/platform/kyverno.yaml` because the
local cluster starts empty; see [ADR-012](adr/ADR-012-disable-kyverno-migration-hooks-locally.md).

`kyverno-policies` is a child Application with a Git `path` source. It
must use the same revision as the root app; see
[ADR-013](adr/ADR-013-git-path-child-apps-follow-root-revision.md). A `Healthy`
status with `Unknown` sync usually means the path does not exist at the
Application's `targetRevision`.

## 12. Security notes

- No secrets in Git. Gitleaks runs in pre-commit and in CI.
- The AWS path uses OIDC federation, never static access keys.
- The local path uses Kubernetes Secrets for local-only values. They are not a
  production secret store.
- Do not use the AWS root account for anything after initial setup.
- Report vulnerabilities through a private GitHub security advisory; do not
  open a public issue with exploit details.
