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
| kubeconform, actionlint | See [VERSIONS.md](VERSIONS.md) | Manifest and workflow validation |
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
security scans and tests that exist at the current phase. Targets for later
phases print a clear "not implemented until Phase N" message and exit 0.

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
2. Installs Argo CD with Helm, pinned in `scripts/local-up.sh`.
3. Applies the two `AppProject` resources from `gitops/projects`.
4. Applies the root `Application` from `gitops/bootstrap/root-app.yaml`.

Everything else — ingress-nginx, Kyverno, the policies, monitoring, logging and
Argo Rollouts — is synced by Argo CD from `gitops/platform`. Do not install any
of those directly; there is a single source of truth. See
[ADR-010](adr/ADR-010-local-platform-bootstrap.md).

**Which revision is deployed.** The committed root Application follows `main`.
When you run `local-up` from a branch that exists on `origin`, the script points
the root app at that branch so the manifests in your checkout are deployed.
After the pull request is merged, running from `main` restores the committed
behaviour. A missing source path renders as a *healthy but empty* Application,
so check that the six child Applications exist:

```bash
kubectl get applications -n argocd
```

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

## 5. GitHub repository setup

1. Create an empty repository named `platformbox`.
2. Push `main` and the `phase/0-foundation` branch.
3. Replace `@REPLACE_ME` in `.github/CODEOWNERS` with your GitHub username or
   team.
4. Protect `main` with these settings:
   - Require a pull request before merging.
   - Require at least one approval.
   - Require status checks to pass before merging.
   - Require conversation resolution.
   - Require linear history.
   - Do not allow force pushes or deletions.
5. Set the default GitHub Actions token permissions to read-only. Workflows
   request only the permissions they need.
6. Create a `dev` environment with required reviewers only if you intend to
   run the optional AWS path. The local path needs no environment.

### Repository secrets and variables

Add these only when the relevant phase needs them. Never commit a value.

| Name | Kind | Used by | Purpose |
|---|---|---|---|
| `SLACK_WEBHOOK_URL` | Secret | Phase 7 | Alertmanager Slack receiver |
| `GITOPS_WRITE_TOKEN` | Secret | Phase 5 | Fine-grained token used by GitLab CI to write image digests back to GitHub |
| `INFRACOST_API_KEY` | Secret | Phase 5/10 | Optional cost estimates for the AWS path |
| `AWS_PLAN_ROLE_ARN` | Variable | Phase 5 | Optional read-only OIDC role for Terraform plan |
| `AWS_APPLY_ROLE_ARN` | Variable | Phase 5 | Optional apply role, restricted to `main` and the `dev` environment |

## 6. GitLab project setup

1. Create a project named `cloud-platform-in-a-box`.
2. Configure repository mirroring from GitHub, or use the GitHub Actions
   mirror workflow added in Phase 5.
3. Protect `main` and require pipelines to pass.
4. Enable the Container Registry.
5. Add CI/CD variables (masked and protected where appropriate):
   - `GITOPS_WRITE_TOKEN` — same fine-grained token as GitHub, scoped to
     `Contents: Read and write` on this repository only.
   - `SLACK_WEBHOOK_URL` — optional, Phase 7.
   - `AWS_ECR_PUSH_ROLE_ARN` — optional, only for the AWS path.
6. Add the `id_tokens` block in `.gitlab-ci.yml` in Phase 5 for Cosign keyless
   signing and, optionally, AWS OIDC.

## 7. Slack alerts (enabled)

Slack is optional at runtime but supported by design. The Alertmanager
configuration uses a null receiver when no webhook is configured, so the
platform works without Slack.

To enable Slack:

1. Create an incoming webhook in your Slack workspace.
2. Store the URL in a secret, never in Git:
   - Local path: a Kubernetes Secret in the `monitoring` namespace, created
     from your shell.
   - AWS path: AWS Secrets Manager, synchronized by External Secrets Operator.
3. Set the webhook secret name in the monitoring values in Phase 7.
4. Verify with a test alert in Phase 7.

## 8. Optional AWS production path (costs money)

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

## 9. Human tasks

These cannot be completed by the agent. Check them off as you go.

- [x] Start Docker Desktop and confirm `docker info` succeeds.
- [x] Set `git config --global user.name` and `user.email`.
- [x] Create the GitHub repository and push the branches.
- [x] Replace `@REPLACE_ME` in `.github/CODEOWNERS`.
- [x] Configure branch protection on `main`.
- [ ] Create the GitLab project when Phase 5 starts.
- [ ] Supply the Slack webhook when Phase 7 starts.
- [ ] Decide whether to run the optional AWS path; if yes, complete the AWS
      account, MFA and budget steps above.
- [ ] Run `make check` on a fresh clone and report any environment-specific
      failure.

## 10. Troubleshooting

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

## 11. Security notes

- No secrets in Git. Gitleaks runs in pre-commit and in CI.
- The AWS path uses OIDC federation, never static access keys.
- The local path uses Kubernetes Secrets for local-only values. They are not a
  production secret store.
- Do not use the AWS root account for anything after initial setup.
- Report vulnerabilities through a private GitHub security advisory; do not
  open a public issue with exploit details.
