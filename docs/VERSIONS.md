# Versions

Every tool, provider, chart, image and action is pinned. This file records the
choice, the date it was verified and the source. Update it in the same commit
as the version change.

Verification date for this table: **2026-11-21**.

## Local toolchain

| Tool | Version | Status | Source |
|---|---|---|---|
| Git | 2.53.0.windows.3 | Verified with `git --version` | Local installation |
| Python | 3.13.15 | Verified with `python --version` | Local installation |
| GNU Make | 4.4.1 | Pinned | ezwinports, `make-4.4.1-without-guile-w32-bin.zip` |
| Terraform | 1.17.2 | Pinned | `releases.hashicorp.com` and HashiCorp checkpoint API |
| tflint | 0.66.0 | Pinned | `terraform-linters/tflint` GitHub release |
| terraform-docs | 0.25.1 | Pinned | `terraform-docs/terraform-docs` GitHub release |
| checkov | 3.4.6 | Pinned | PyPI |
| trivy | 0.76.2 | Pinned | `aquasecurity/trivy` GitHub release |
| gitleaks | 8.30.1 | Pinned | `gitleaks/gitleaks` GitHub release |
| hadolint | 2.15.1 | Pinned | `hadolint/hadolint` GitHub release |
| yamllint | 1.38.0 | Pinned | PyPI |
| ruff | 0.17.6 | Pinned | PyPI |
| pre-commit | 4.7.0 | Pinned | PyPI |
| pytest | 8.4.2 | Pinned | PyPI; 9.x needs `packaging>=24` and conflicts with checkov's `packaging<24` pin |
| kind | 0.33.0 | Pinned | `kubernetes-sigs/kind` GitHub release |
| kubectl | 1.36.1 | Verified client version | Local Docker Desktop installation |
| Helm | 4.3.2 | Pinned | `get.helm.sh`; chart compatibility verified in Phase 3 |
| Kustomize | 5.8.3 | Pinned | `kubernetes-sigs/kustomize` GitHub release |
| kubeconform | 0.8.0 | Pinned | `yannh/kubeconform` GitHub release |
| actionlint | 1.7.12 | Pinned | `rhysd/actionlint` GitHub release |
| cosign | 3.1.4 | Pinned | `sigstore/cosign` GitHub release |
| syft | 1.57.2 | Pinned | `anchore/syft` GitHub release |
| Kyverno CLI | 1.20.0 | Pinned | `kyverno/kyverno` GitHub release |
| Prometheus and promtool | 3.16.0 | Pinned | `prometheus/prometheus` GitHub release |
| Infracost | 0.10.50 | Pinned | `infracost/infracost` GitHub release |
| jq | 1.8.2 | Pinned | `jqlang/jq` GitHub release |
| yq | 4.54.3 | Pinned | `mikefarah/yq` GitHub release |
| shellcheck | 0.11.0 | Pinned | `koalaman/shellcheck` GitHub release |
| Docker CLI | 29.9.3 | Verified client version | Local Docker Desktop installation |
| AWS CLI | TBD | Optional AWS path | Verify before use |

## Pre-commit hooks

| Hook repository | Revision | Purpose |
|---|---|---|
| `pre-commit/pre-commit-hooks` | v6.0.0 | YAML validity, whitespace, merge conflicts, large files |
| `adrienverge/yamllint` | v1.38.0 | YAML lint |
| `astral-sh/ruff-pre-commit` | v0.17.6 | Python lint and format |
| `antonbabenko/pre-commit-terraform` | v1.109.5 | Terraform fmt, validate, docs and tflint |
| `compilerla/conventional-pre-commit` | v4.5.0 | Conventional Commit messages |

## Terraform plugins

| Plugin | Version | Source |
|---|---|---|
| TFLint AWS ruleset | 0.50.0 | `github.com/terraform-linters/tflint-ruleset-aws` |

## Platform versions to pin in later phases

These are intentionally unresolved until the phase that needs them. Resolve
them against current official documentation, then add the exact version here.

| Component | Phase | Why it is deferred |
|---|---|---|
| Terraform providers (`aws`, `kubernetes`, `helm`, `random`) | 1 | Resolve with `terraform init` and record in `.terraform.lock.hcl` |
| EKS Kubernetes version | 1 | Use a version in standard support at build time |
| kind node image | 3 | Pin the digest in the kind configuration |
| Helm charts (Argo CD, ingress-nginx, Kyverno, kube-prometheus-stack, Loki, Alloy, Argo Rollouts, External Secrets) | 3 | Verify chart and CRD compatibility together |
| Application base images | 2 | Pin by tag and digest |
| GitHub Actions | 5 | Pin every action by commit SHA |
| GitLab CI images | 5 | Pin by tag and digest |
| k6, Chaos Mesh | 9 | Extension phase |
