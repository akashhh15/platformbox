# Versions

Every tool, provider, chart, image and action is pinned. This file records the
choice, the date it was verified and the source. Update it in the same commit
as the version change.

Verification date for this table: **2026-11-22**. Earlier entries were verified
on 2026-11-21; the Phase 4 additions below were verified on 2026-11-22. Phase 7
interface checks were verified again on **2026-11-25**; see the Phase 7 section
below. Phase 9 versions and interfaces were verified on **2026-11-25**. Phase 10
finance and Karpenter interfaces were verified on **2026-11-26**.

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
| k6 | 2.4.0 | Pinned; `k6 version` verified locally | `grafana/k6` GitHub release and published checksums |
| Docker CLI | 29.9.3 | Verified client version | Local Docker Desktop installation |
| AWS CLI | 2.42.1 | Pinned | `awscli.amazonaws.com`, SHA-256 recorded in the Phase 5 CI pins |

The Phase 7 Prometheus release archive was checksum-verified locally on
2026-11-25 before `promtool` was extracted:

| File | Version | SHA-256 |
|---|---|---|
| `prometheus-3.16.0.windows-amd64.zip` | 3.16.0 | `89c03c2f24400fb58668440b6d7226f68564acda27d657e77acfbda42be32cb3` |
| extracted `promtool.exe` | 3.16.0 | `b18a0f297fd3350a104cfcb9745c9e7f3b71cc6474875159fd56195a8289c570` |

`promtool --version` reported `promtool, version 3.16.0 (branch: HEAD, revision:
e2e28adeee2c5883d000fc82aca6008cfbf7e96d)`. The Prometheus server rendered by
kube-prometheus-stack 65.8.1 is 2.55.0, so Phase 7 rules intentionally use only
PromQL syntax available in 2.55 even though the offline checker is newer.

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

## Phase 5 CI pins

All entries below were verified on 2026-11-22. Action tags were resolved to
commits with `git ls-remote --tags`; container digests were read from the
registry with `docker buildx imagetools inspect`; binary digests came from the
upstream release API or the release's checksum file. Workflows must use the
SHA form, never the tag.

| Action | Tag | Commit SHA |
|---|---|---|
| `actions/checkout` | v7 | `3d3c42e5aac5ba805825da76410c181273ba90b1` |
| `actions/setup-python` | v7 | `6d4fd22b20465ccc0f7354476588e8df7c9ca0e0` |
| `actions/upload-artifact` | v7 | `cf430e030ddbb5b0abf93d22962f4752f3646cd9` |
| `actions/github-script` | v9 | `3a2844b7e9c422d3c10d287c895573f7108da1b3` |
| `actions/dependency-review-action` | v5.0.1 | `bbc44d14a204704ccc493733616cd1e93a0321ec` |
| `hashicorp/setup-terraform` | v4 | `dfe3c3f87815947d99a8997f908cb6525fc44e9e` |
| `terraform-linters/setup-tflint` | v6 | `6ffdbaa3be476b3431f7275c26966ef32ff60337` |
| `aquasecurity/trivy-action` | v0.36.0 | `ed142fd0673e97e23eac54620cfb913e5ce36c25` |
| `aws-actions/configure-aws-credentials` | v6 | `e1253824e5c10ff9df46874f81ed3ec929e19cfd` |
| `github/codeql-action` | v4 | `1bd86f2fdb4b86187fa4059f16f31a3202acc9ea` |
| `gitleaks/gitleaks-action` | v3 | `e0c47f4f8be36e29cdc102c57e68cb5cbf0e8d1e` |
| `infracost/actions/diff` | v5 | `a5783eb98adc93aa7a0049fce0abb06fdd30770a` |
| `azure/setup-helm` | v5 | `2f5e7bc67f1f9972ab16657bb795f36d8f04de0e` |

| Container image | Tag | Digest | Used by |
|---|---|---|---|
| `quay.io/buildah/stable` | `v1.46.1` | `sha256:72b49c4af6c63850200cc8809d513691d61ceb440358faff305b540c4b9fc038` | GitLab build, SBOM, sign and publish jobs |
| `python` | `3.12.7-slim-bookworm` | `sha256:60d9996b6a8a3689d36db740b49f4327be3be09a21122bd02fb8895abb38b50d` | GitLab lint and test jobs |
| `aquasec/trivy` | `0.76.2` | `sha256:8f6bb947dbc528902e11f2f5be52f7b519f6a39d5d148f41166f2040499768fb` | GitLab Trivy jobs |
| `alpine/git` | `v2.52.0` | `sha256:4a0e72d49596a1f5d3701aeedafdadc5c0da4062be4657c7bdc4017387f591cc` | GitLab pipeline summary job |
| `registry.gitlab.com/security-products/semgrep` | `7.0.0` | `sha256:0d5c196b9563557d268917e6904e3021c300df90cde2b277e0c55eb80668055c` | GitLab SAST |
| `registry.gitlab.com/security-products/secrets` | `7.43.1` | `sha256:0cbd3826e1006b820af56a100f1baa98c3afe5847dde48c32589120cc83d4a5a` | GitLab secret detection |
| `ghcr.io/infracost/ci` | `2.1.5` | `sha256:e7ddb5c9026624456b47ec4208da00ef942ee390b29cb331d648b8c0d8731ee5` | Infracost action `version` input |

| Binary downloaded in CI | Version | SHA-256 |
|---|---|---|
| `k6-v2.4.0-linux-amd64.tar.gz` | 2.4.0 | `5a5ecf23529ccf93135bc7e5b0c1cd5126ecf5f2672e22eed1556a0ab74abb87` |
| `actionlint_1.7.12_linux_amd64.tar.gz` | 1.7.12 | `8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8` |
| `kustomize_v5.8.3_linux_amd64.tar.gz` | 5.8.3 | `cb9e31198d3f63b44848bd0afc4c8efc56e6cfef9c93a4a39a211940e6decd61` |
| `kubeconform-linux-amd64.tar.gz` | 0.8.0 | `9bc2bffbf71f261128533edaf912153948b7ff238f9a531ae6d34466ec287883` |
| `kyverno-cli_v1.20.0_linux_x86_64.tar.gz` | 1.20.0 | `06b8f3ca7b5626473be8fb4d343ad54ab84e317142766f72420e7d44b80942e2` |
| `awscli-exe-linux-x86_64-2.42.1.zip` | 2.42.1 | `ff2631c32c5db291b099600f404bc493454ec66c125ff4604625da90480c1f47` |
| `prometheus-3.16.0.linux-amd64.tar.gz` | 3.16.0 | `68727009472a2c02e1ff7f062fd5b3e637285bffc8fc2d340c76fb449d6e0f34` |
| `cosign-linux-amd64` | 3.1.4 | `424e2c97d0b45fd7a6b608a87f090f35633f4c23ece5f092d48bba11aaf4bbfa` |
| `hadolint-linux-x86_64` | 2.15.1 | `c7187db94eeeeca956519a6af171adc31453941a1e777961f6e680f697c8c507` |
| `syft_1.57.2_linux_amd64.tar.gz` | 1.57.2 | `ad92bd3ec1b94a3df01d4d0aec199afa9c42b72e86da436ff5f837914d32706b` |

Kaniko was rejected because its upstream repository is archived; see
[ADR-021](adr/ADR-021-buildah-over-kaniko.md).

## Phase 7 interface verification

These facts were checked against the pinned charts and rendered templates on
2026-11-25. No chart version changed in Phase 7.

| Component | Verified interface | Evidence |
|---|---|---|
| kube-prometheus-stack 65.8.1 | Grafana dashboard sidecar enabled by default with label `grafana_dashboard: "1"`, value `"1"`, `searchNamespace: ALL`; datasource uid `prometheus` | `helm template` of the pinned chart |
| kube-prometheus-stack 65.8.1 | Default Alertmanager config has receiver `null` | `helm template` of the pinned chart |
| loki-stack 2.10.2 | Datasource ConfigMap is labelled `grafana_datasource: "1"` with uid `loki` | `helm template` of the pinned chart |
| Argo CD chart 10.18.2 | `controller.metrics.enabled=true` renders Service `argocd-application-controller-metrics`, port `http-metrics`/8082; chart default is false | `helm template` of the pinned chart |
| Argo Rollouts chart 2.38.0 | `controller.metrics.enabled=true` renders Service `argo-rollouts-metrics`, port `metrics`/8090; chart default is false | `helm template` of the pinned chart |
| Karpenter chart 1.0.0 | `serviceMonitor.enabled=true` and `serviceMonitor.additionalLabels.release=monitoring` are supported | Pulled chart `values.yaml` |
| Argo Rollouts v1.7.2 | Abort phase is `Abort`, not `Aborting`; metrics include `rollout_info`, `rollout_reconcile_error`, `rollout_reconcile` and `rollout_events_total` | Rendered chart and versioned metric names |
| Kyverno v1.20 | `kyverno_validating_policy_results_total` has labels including `policy_validation_mode`, `policy_name`, `resource_namespace` and `result` | Pulled chart metric definition |

The Prometheus Operator ignores the `Optional` flag on an AlertmanagerConfig
`apiURL` Secret; that is why Slack routing is gated by cluster label rather than
deployed with a placeholder secret (ADR-025).

## Phase 8 interface verification

These facts were checked against official documentation and the pinned charts on
2026-11-25. No chart version changed in Phase 8.

| Component | Verified interface | Evidence |
|---|---|---|
| Argo Rollouts canary | Without `trafficRouting`, `setWeight` is approximated with replica ratios; `setCanaryScale` needs a traffic router | [Canary docs](https://argo-rollouts.readthedocs.io/en/stable/features/canary/) |
| Argo Rollouts ALB | `trafficRouting.alb.ingress`, `rootService`, `servicePort` and Ingress backend `port.name: use-annotation` are supported, but need ALB | [ALB docs](https://argo-rollouts.readthedocs.io/en/stable/features/traffic-management/alb/) |
| AnalysisTemplate | `args[].valueFrom.podTemplateHashValue`, `interval`, `count`, `failureLimit`, `successCondition` and the Prometheus provider are supported | [Analysis docs](https://argo-rollouts.readthedocs.io/en/stable/features/analysis/) and [Prometheus provider docs](https://argo-rollouts.readthedocs.io/en/stable/analysis/prometheus/) |
| Argo Rollouts chart 2.38.0 | Notification ConfigMap keys are `notifiers`, `templates`, `triggers` and `subscriptions`; built-in trigger names still need a `trigger.<name>` entry | Pulled chart template and `manifests/notifications-install.yaml` |
| Argo CD chart 10.18.2 and 7.0.0 | Both render `argocd-notifications-cm` from `notifications.notifiers/templates/triggers/subscriptions` | `helm template` of both pinned chart versions |
| Alertmanager v0.27.0 | `POST /api/v2/alerts` requires `Content-Type: application/json` and an array of alerts with `labels`, optional `annotations` and optional timestamps | [Alerts API](https://prometheus.io/docs/alerting/latest/alerts_api/) |

## Phase 9 interface verification

These facts were checked against official documentation and the pinned releases
on 2026-11-25. No load test or fault injection was executed.

| Component | Verified interface | Evidence |
|---|---|---|
| k6 2.4.0 | `k6 inspect` reports `vus`, `duration`, `stages` and `thresholds`; a breached threshold exits 99; option precedence is CLI > `K6_*` env > script options > config | [k6 options](https://grafana.com/docs/k6/latest/using-k6/k6-options/reference/) and [thresholds](https://grafana.com/docs/k6/latest/using-k6/thresholds/) |
| k6 2.4.0 Windows archive | `k6-v2.4.0-windows-amd64.zip` SHA-256 `aaa90b3afc336faf90172c7addf45c4f41305f6f188e3d564f79466e80ac68e3` | Published checksums file, verified locally during `make tools` |
| Chaos Mesh chart 2.8.8 | Chart and app version both 2.8.8; `chaosDaemon.runtime`, `chaosDaemon.socketPath`, `clusterScoped`, `controllerManager.enableFilterNamespace`, `controllerManager.replicaCount` and `dashboard.create` are supported values | Pulled chart and `helm template` of the pinned values |
| Chaos Mesh 2.8.8 | Namespace filtering uses `chaos-mesh.org/inject=enabled`; `pod-kill` is one-shot and ignores `duration`; `NetworkChaos` needs an explicit `direction`; deleting an experiment restores the fault and `experiment.chaos-mesh.org/pause=true` pauses it | [Install](https://chaos-mesh.org/docs/production-installation-using-helm/), [namespace filtering](https://chaos-mesh.org/docs/configure-enabled-namespace/), [PodChaos](https://chaos-mesh.org/docs/simulate-pod-chaos-on-kubernetes/), [NetworkChaos](https://chaos-mesh.org/docs/simulate-network-chaos-on-kubernetes/) |
| Chaos Mesh 2.8.8 | No `NodeChaos` CRD exists; `AWSChaos` supports `ec2-stop`, `ec2-restart` and `detach-volume`, needs `secretName` and has no spot-interruption action | [AWSChaos docs](https://chaos-mesh.org/docs/simulate-aws-chaos/) and chart CRDs |
| Chaos Mesh chart repository | Index digest `35f3caded3d33428d0864eb6d6ece97a5d859a1c0a6e49020fb4d07dd3676bdf` | `helm repo add chaos-mesh https://charts.chaos-mesh.org` and `helm repo update` |
| metrics-server 0.9.1 | `components.yaml` SHA-256 `3c7f57cdbee0f57fb0259a150e8f6d6cb4f29d72d1aa5dce8803151dd6d4c2a1`; kind needs `--kubelet-insecure-tls`, EKS does not | [metrics-server releases](https://github.com/kubernetes-sigs/metrics-server/releases/tag/v0.9.1) and [requirements](https://github.com/kubernetes-sigs/metrics-server#requirements) |
| metrics-server chart 3.14.0 | App version 0.9.0; the upstream `components.yaml` release is used for the human-run HPA prerequisite, not a Helm Application | `helm search repo metrics-server/metrics-server --versions` |
| HPA timing | Sync period defaults to 15s, CPU target is a percentage of container requests, downscale stabilisation defaults to 300s; prove scale-up with a sustained plateau | [HPA walkthrough](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/) |

## Phase 10 interface verification

These facts were checked against official documentation, published source and
pulled chart archives on 2026-11-26. No live AWS, Cost Explorer, Infracost PR
comment or cluster operation was performed.

| Component | Version or interface | Evidence |
|---|---|---|
| Infracost CI container | `ghcr.io/infracost/ci@sha256:e7ddb5c9026624456b47ec4208da00ef942ee390b29cb331d648b8c0d8731ee5` (2.1.5) | Pinned container digest; `infracost-ci diff --help` in the published source |
| Infracost CI auth | `INFRACOST_CLI_AUTHENTICATION_TOKEN`; `INFRACOST_API_KEY` is not accepted | [Infracost CI README](https://github.com/infracost/ci/blob/master/README.md) |
| Infracost comment file | `diff --base-path <dir> --head-path <dir> --comment-out-file <path>` needs no provider token | `internal/commands/diff.go` flags and `commentfile.go` in the pinned CI source |
| Infracost config | Version `0.3`; `path` relative to working directory, `terraform.var_files` relative to project, `usage_file` relative to repo root; missing usage file is skipped | [Infracost config](https://www.infracost.io/docs/features/config_file/) and `internal/config/scan.go` |
| Infracost comment tag | `[//]: <> (infracost-comment)` | [Infracost VCS README](https://github.com/infracost/vcs/blob/master/README.md) |
| `actions/download-artifact` | v4.3.0, commit `d3f86a106a0bac45b974a628896c90dbdf5c8093` | `git ls-remote --tags` on 2026-11-26 |
| boto3 / PyYAML | `1.44.12` / `6.0.4` | PyPI pins in `requirements-dev.txt`; installed locally |
| Cost Explorer pricing | USD 0.01 per `get_cost_and_usage` request with the primary billing view | [AWS pricing](https://aws.amazon.com/aws-cost-management/aws-cost-explorer/pricing/) |
| OpenCost chart | `opencost/opencost` 2.5.35, archive SHA-256 `35c5ec2294ab22a2a1fcb14018b45d83cae8e96bf19bff86b9a669335a2836db` | `helm pull` and local `sha256sum` |
| OpenCost exporter image | `ghcr.io/opencost/opencost:1.121.5@sha256:29e7becb7b04b935d85031c7fb43bb3731b53899b3f05353c83c5850619ade3e` | Resolved with registry tooling; chart value `opencost.exporter.image.tag` |
| OpenCost UI image | `ghcr.io/opencost/opencost-ui:1.121.5@sha256:ead6e6dc09c84b34aeb850dfeef84dca9410c9d85fe980d2359a66a14ccde809` | Resolved with registry tooling; chart value `opencost.ui.image.tag` |
| OpenCost metrics | `node_cpu_hourly_cost`, `node_ram_hourly_cost`, `container_cpu_allocation`, `container_memory_allocation_bytes` and their labels | [OpenCost metrics](https://opencost.io/docs/integrations/metrics) |
| Karpenter NodePool | v1 supports `spec.weight`, `spec.limits`, `disruption.consolidationPolicy`, `consolidateAfter`, `budgets` and `template.spec.expireAfter` | [NodePool docs](https://karpenter.sh/docs/concepts/nodepools/) and [disruption docs](https://karpenter.sh/docs/concepts/disruption/) |
| Karpenter consolidation | v1 default is `WhenEmptyOrUnderutilized`; fixed alias AMIs track the control-plane version | [Disruption docs](https://karpenter.sh/docs/concepts/disruption/) and [AMI docs](https://karpenter.sh/docs/tasks/managing-amis/) |
| Karpenter AMI alias | `al2023@v20240807` | [AMI docs](https://karpenter.sh/docs/tasks/managing-amis/) |
| Karpenter discovery | `EC2NodeClass` v1 uses `subnetSelectorTerms`, `securityGroupSelectorTerms` and `amiSelectorTerms` | [NodeClass docs](https://karpenter.sh/docs/concepts/nodeclasses/) |
| Argo CD cluster generator | Exposes `metadata.labels.<key>` and `metadata.annotations.<key>`; `index` handles keys with `/` | [Cluster generator](https://argo-cd.readthedocs.io/en/latest/operator-manual/applicationset/Generators-Cluster/) |

## Platform versions to pin in later phases

These are intentionally unresolved until the phase that needs them. Resolve
them against current official documentation, then add the exact version here.

| Component | Phase | Why it is deferred |
|---|---|---|
| Terraform providers (`aws`, `kubernetes`, `helm`, `random`) | 1 | Resolved in `.terraform.lock.hcl` |
| EKS Kubernetes version | 1 | Resolved in `infra/` |
| Application base images | 2 | Pinned by tag and digest in the Dockerfiles |
| GitHub Actions | 5 | Resolved in the Phase 5 CI pins table above |
| GitLab CI images | 5 | Resolved in the Phase 5 CI pins table above |
