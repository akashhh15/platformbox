# Versions

Every tool, provider, chart, image and action is pinned. This file records the
choice, the date it was verified and the source. Update it in the same commit
as the version change.

Verification date for this table: **2026-11-22**. Earlier entries were verified
on 2026-11-21; the Phase 4 additions below were verified on 2026-11-22.

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

## Platform versions resolved in Phase 3

All chart versions below were verified with `helm search repo <repo>/<chart>
--versions` on 2026-11-21. Charts are pinned in the individual `Application`
manifests under `gitops/platform/`; Argo CD is pinned in `scripts/local-up.sh`.

| Component | Version | App version | Where pinned |
|---|---|---|---|
| kind node image | `kindest/node:v1.37.0@sha256:a1ed56cfb0e7b93589bdf97c8cd566405a265939e3620fc4f5de89adff580ae5` | Kubernetes 1.37.0 | kind 0.33.0 default, observed in `kind create cluster` output |
| Argo CD chart (`argo/argo-cd`) | 10.18.2 | v3.6.2 | `scripts/local-up.sh` |
| ingress-nginx chart (`ingress-nginx/ingress-nginx`) | 4.11.3 | 1.11.3 | `gitops/platform/ingress-nginx.yaml` |
| Kyverno chart (`kyverno/kyverno`) | 3.10.0 | v1.20.0 | `gitops/platform/kyverno.yaml` |
| kube-prometheus-stack (`prom/kube-prometheus-stack`) | 65.8.1 | v0.77.2 | `gitops/platform/monitoring.yaml` |
| Loki stack (`grafana/loki-stack`) | 2.10.2 | v2.9.3 | `gitops/platform/logging.yaml` |
| Argo Rollouts chart (`argo/argo-rollouts`) | 2.38.0 | v1.7.2 | `gitops/platform/argo-rollouts.yaml` |
| External Secrets chart (`external-secrets/external-secrets`) | 2.15.0 | v2.15.0 | `gitops/platform/external-secrets.yaml` |

The following images are pulled on the host and preloaded into every kind node
by `scripts/preload-images.sh` because their registries are slow from inside
kind. They are pinned to the same versions the charts above render:

| Image | Pin | Source |
|---|---|---|
| `quay.io/argoproj/argocd` | `v3.6.2` | Argo CD chart 10.18.2 |
| `ecr-public.aws.com/docker/library/redis` | `8.6.4-alpine` | Argo CD chart 10.18.2 |
| `reg.kyverno.io/kyverno/kyverno` | `v1.20.0` | Kyverno chart 3.10.0 |
| `reg.kyverno.io/kyverno/background-controller` | `v1.20.0` | Kyverno chart 3.10.0 |
| `reg.kyverno.io/kyverno/cleanup-controller` | `v1.20.0` | Kyverno chart 3.10.0 |
| `reg.kyverno.io/kyverno/reports-controller` | `v1.20.0` | Kyverno chart 3.10.0 |
| `reg.kyverno.io/kyverno/kyvernopre` | `v1.20.0` | Kyverno chart 3.10.0 init container |
| `registry.k8s.io/ingress-nginx/controller` | `v1.11.3@sha256:d56f135b6462cfc476447cfe564b83a45e8bb7da2774963b00d12161112270b7` | ingress-nginx chart 4.11.3 |
| `registry.k8s.io/ingress-nginx/kube-webhook-certgen` | `v20221220-controller-v1.5.1-58-g787ea74b6` | ingress-nginx chart 4.11.3 |
| `quay.io/prometheus-operator/prometheus-operator` | `v0.77.2` | kube-prometheus-stack 65.8.1 |
| `quay.io/prometheus-operator/prometheus-config-reloader` | `v0.77.2` | kube-prometheus-stack 65.8.1 |
| `quay.io/prometheus/prometheus` | `v2.55.0` | kube-prometheus-stack 65.8.1 |
| `quay.io/prometheus/alertmanager` | `v0.27.0` | kube-prometheus-stack 65.8.1 |
| `registry.k8s.io/kube-state-metrics/kube-state-metrics` | `v2.13.0` | kube-prometheus-stack 65.8.1 |
| `quay.io/prometheus/node-exporter` | `v1.8.2` | kube-prometheus-stack 65.8.1 |
| `quay.io/kiwigrid/k8s-sidecar` | `1.28.0` | kube-prometheus-stack 65.8.1 |
| `docker.io/grafana/grafana` | `11.3.0` | kube-prometheus-stack 65.8.1 |
| `grafana/loki` | `2.6.1` | Loki stack chart 2.10.2 |
| `docker.io/grafana/promtail` | `2.9.3` | Loki stack chart 2.10.2 |
| `quay.io/argoproj/argo-rollouts` | `v1.7.2` | Argo Rollouts chart 2.38.0 |
| `quay.io/argoproj/kubectl-argo-rollouts` | `v1.7.2` | Argo Rollouts chart 2.38.0 dashboard |

The following application and local-data images are pinned for the Phase 4
local smoke test. Digests were resolved on 2026-11-22 with
`docker buildx imagetools inspect`:

| Image | Pin | Source |
|---|---|---|
| `ghcr.io/external-secrets/external-secrets` | `v2.15.0@sha256:6888f243e5f8f7592c6d7fae2a5547c9e33531441b47b53807b9093b25a00e31` | External Secrets chart 2.15.0, `helm template` output |
| `postgres` | `16.4-alpine@sha256:5660c2cbfea50c7a9127d17dc4e48543eedd3d7a41a595a2dfa572471e37e64c` | `gitops/apps/local-data/postgres.yaml` |
| `redis` | `7.4-alpine@sha256:7f7d30b7fdd09467bac58198a1f166dd69789d348d4fe859cccb20e0cf287fbe` | `gitops/apps/local-data/redis.yaml` |
| `nginx` | `1.27.3-alpine@sha256:814a8e88df978ade80e584cc5b333144b9372a8e3c98872d07137dbf3b44d0e4` | `apps/frontend/Dockerfile` base image |

Application images are built locally as `platformbox-{api,worker,frontend}:local`
and loaded into kind by `scripts/local-smoke.sh`; CI will publish immutable tags
in Phase 5 (ADR-014).

Kyverno chart 3.3.7 was rejected: it ships Kyverno 1.13.4, which cannot execute
the CEL `ValidatingPolicy` resources used here. 3.10.0 ships 1.20.0, matching
the pinned Kyverno CLI. See [ADR-009](adr/ADR-009-cel-based-kyverno-policies.md).

## Platform versions to pin in later phases

These are intentionally unresolved until the phase that needs them. Resolve
them against current official documentation, then add the exact version here.

| Component | Phase | Why it is deferred |
|---|---|---|
| Terraform providers (`aws`, `kubernetes`, `helm`, `random`) | 1 | Resolved in `.terraform.lock.hcl` |
| EKS Kubernetes version | 1 | Resolved in `infra/` |
| Application base images | 2 | Pinned by tag and digest in the Dockerfiles |
| GitHub Actions | 5 | Pin every action by commit SHA |
| GitLab CI images | 5 | Pin by tag and digest |
| k6, Chaos Mesh | 9 | Extension phase |
