# Progress

## Phase status

| Phase | Status | Notes |
|---|---|---|
| 0 — Repository foundation | Complete — awaiting review | Skeleton, Makefile, pre-commit, docs, ADRs; `make check` passes |
| 1 — Terraform foundation | Complete — awaiting review | Bootstrap, 8 modules, dev/prod environments, 4 ADRs; fmt/validate/tflint/checkov/trivy/test pass |
| 2 — Application and containers | Complete — awaiting review | FastAPI api/worker, static frontend, compose; ruff/pytest/hadolint pass; images build |
| 3 — GitOps and platform layer | Complete — merged and verified | kind config, Argo CD app-of-apps, ingress, CEL policies, monitoring, logging, rollouts; `make check` passes; clean rebuild succeeded; all Applications `Synced`/`Healthy` |
| 4 — Application delivery | Complete — merged and verified | Kustomize base, dev/staging/prod overlays, ApplicationSets, local data/secret substitutes; `make check` and `make local-smoke` pass; PR #8 merged |
| 5 — CI/CD | Complete — merged and verified | 7 GitHub workflows, GitLab CI with Buildah/Trivy/Syft/Cosign/ECR OIDC, digest write-back, offline workflow validator; PR #13 merged; live pipelines are human-run |
| 6 — DevSecOps and policy | Complete — merged and verified | Two CEL hardening policies, 35 offline policy tests, threat model, ADR-023; PR #15 merged |
| 7 — Observability and SLOs | Complete — awaiting review | Six dashboards, SLO recording rules, ten alerts with runbooks, structured logs, worker metrics, opt-in Slack routing; static validation passes |
| 8 — Progressive delivery | Not started | Canary, analysis, automatic rollback, demo |
| 9 — Resilience (extension) | Not started | k6, chaos, game day, backup and restore |
| 10 — FinOps (extension) | Not started | Cost model, optional Infracost, pause and teardown |
| 11 — Documentation and polish | Not started | Final README, architecture, demo, interview notes |
| 12 — Final audit | Not started | Security, correctness, reproducibility, cost, docs |

## Execution mode

This project is **local-first and zero cost**. The AWS EKS architecture from
`AGENTS.md` is the production target design, but it is not applied. The primary
runtime is a local `kind` cluster; AWS Terraform is validated with
`terraform validate` and `terraform test` using mock providers. See
[ADR-000](docs/adr/ADR-000-local-first-zero-cost.md) and
[ADR-004](docs/adr/ADR-004-local-substitutes.md).

## Decisions

| Date | Decision | Record |
|---|---|---|
| 2026-11-21 | Local-first, zero-cost execution; AWS path is optional and never applied by the agent | ADR-000 |
| 2026-11-21 | Monorepo on GitHub, mirrored to GitLab for application CI | ADR-001 |
| 2026-11-21 | OIDC federation instead of static credentials | ADR-002 |
| 2026-11-21 | CI writes image digests back to Git; Argo CD is the only deployer | ADR-003 |
| 2026-11-21 | Local substitutes for ALB, ECR, RDS, IRSA, Karpenter and Secrets Manager | ADR-004 |
| 2026-11-21 | Slack alerts enabled when a webhook is supplied; null receiver otherwise | Phase 7 |
| 2026-11-21 | RDS enabled for the optional AWS dev path; in-cluster PostgreSQL locally | ADR-000, ADR-004 |
| 2026-11-21 | GitHub/GitLab owner and repository names stay parameterized until supplied | docs/SETUP.md |
| 2026-11-21 | Terraform 1.17.2 with S3 native locking (`use_lockfile`), no DynamoDB | docs/VERSIONS.md |
| 2026-11-21 | Wrap community VPC/EKS modules; write Karpenter directly | ADR-005 |
| 2026-11-21 | IRSA over EKS Pod Identity | ADR-006 |
| 2026-11-21 | Single NAT gateway in dev, HA in prod | ADR-007 |
| 2026-11-21 | S3 native state locking, no DynamoDB | ADR-008 |
| 2026-11-21 | pytest pinned to 8.4.2 because pytest 9 needs `packaging>=24` and checkov 3.4.6 pins `packaging<24` | requirements-dev.txt, docs/VERSIONS.md |
| 2026-11-21 | Kyverno 1.20 CEL `ValidatingPolicy` instead of legacy `ClusterPolicy` | ADR-009 |
| 2026-11-21 | Argo CD app-of-apps bootstrap; Argo CD manages all platform components, including ingress | ADR-010 |
| 2026-11-21 | Kyverno chart 3.10.0 (app 1.20.0) to match CLI; all Phase 3 charts pinned | docs/VERSIONS.md |
| 2026-11-21 | Checkov skips test fixture directories; those pods model policy edge cases | .checkov.yaml |
| 2026-11-21 | Argo CD server-side apply with client-side migration disabled for large CRDs | ADR-011 |
| 2026-11-21 | Kyverno upgrade hooks disabled on the disposable local cluster | ADR-012 |
| 2026-11-22 | Git-path child Application follows the root Application revision during review | ADR-013 |
| 2026-11-21 | Slow third-party images are pulled on the host and preloaded into kind | scripts/preload-images.sh, docs/VERSIONS.md |
| 2026-11-22 | CI edits overlay `images.newTag` with pinned `kustomize edit set image` | ADR-014 |
| 2026-11-22 | ApplicationSets are cluster-gated and inactive on kind; prod is manual sync | ADR-015 |
| 2026-11-22 | Local ExternalSecret path uses a fake store with docker-compose credentials and in-cluster FQDNs | ADR-016 |
| 2026-11-22 | `app-data` uses baseline PSS for the pinned PostgreSQL image | ADR-017 |
| 2026-11-22 | Rollout uses canary with no steps as a basic rolling update | ADR-018 |
| 2026-11-22 | AWS secret store is EKS-gated so local kind stays Healthy | ADR-019 |
| 2026-11-22 | Strengthen offline evidence instead of emulating AWS locally | ADR-020 |
| 2026-11-22 | Buildah 1.46.1 over archived Kaniko for unprivileged GitLab builds | ADR-021 |
| 2026-11-22 | Sign the pushed digest, normalize artifacts in one helper, and layer loop prevention with offline workflow validation | ADR-022 |
| 2026-11-24 | Restrict new hardening policies to app-dev/staging/prod and defer signature admission until the GitLab OIDC subject is known | ADR-023 |
| 2026-11-25 | Provisional 99.5% availability and 95%-under-500-ms latency SLOs with multi-window burn-rate alerts | ADR-024 |
| 2026-11-25 | Slack routing is generated only on explicitly labelled EKS clusters; kind keeps the chart's null receiver | ADR-025 |

## Open items

- Git `user.name` and `user.email` are configured on this machine (no-reply).
- The GitHub repository and branch protection are configured.
- The GitLab project, mirror token, write-back token, ECR OIDC role and CI
  variables are not created. The pipeline test plan is in docs/SETUP.md §7.
- The Slack incoming webhook is not supplied yet. kind uses the chart's null
  receiver; EKS clusters must opt in with the labels described in
  `docs/SETUP.md` §8 and ADR-025.
- The optional AWS path has no account, budget e-mail or OIDC roles. This is
  intentional and costs nothing.
- Image signature admission is not enforced. After the GitLab project path and
  OIDC `sub` are confirmed, add a cluster-gated `ImageValidatingPolicy` in Audit,
  verify a real signed digest, then promote it to Deny. See ADR-023 and
  `docs/threat-model.md`.
- Docker's data disk was moved from C: to D: with a junction. C: now has about
  12 GB free and the kind cluster starts normally.
- The Phase 3 pull requests #6 and #7 are merged; `main` is the source of truth.
- The resumed clean `local-down`/`local-up` succeeded with no manual steps.
  All six child Applications and the root Application are `Synced`/`Healthy`.
  `kyverno-policies` initially stayed `Unknown` because its Git path was pinned
  to `main` while the root app followed `phase/3-platform`; ADR-013 records the
  fix. All five CEL policies report `READY`.
- Phase 4 pull request #8 was approved by `atharvvv10` and merged by
  `akashhh15` as merge commit `6715911`. Local smoke test deployed
  api, worker and frontend with in-cluster Postgres/Redis; `/health`, `/ready`,
  frontend `/` and the opt-in `/chaos/fail` endpoint returned the expected
  results. No AWS resource was created.
- Offline evidence was strengthened after review: overlay contract/parity
  assertions (154 checks) and Terraform mock-provider tests for ECR, budgets,
  IRSA and bootstrap now run in `make validate`. ADR-020 records the decision.

## Human tasks

These are the tasks only the repository owner can complete. Full instructions
are in [docs/SETUP.md](docs/SETUP.md).

- [x] Start Docker Desktop before running kind or Docker builds.
- [x] Move the Docker data disk from C: to D: and restart Docker Desktop.
- [x] Configure Git identity: `git config --global user.name "..."` and
  `git config --global user.email "..."`.
- [x] Create the GitHub repository, push `main`, and enable branch protection.
- [x] Confirm `.github/CODEOWNERS` names the real repository owner.
- [ ] Create the GitLab project, mirror token, write-back token, ECR OIDC role
      and every GitHub/GitLab variable listed in docs/SETUP.md §§5–6.
- [ ] Run the GitHub and GitLab pipeline tests in docs/SETUP.md §7. Do not
      approve `terraform-apply` unless you intend to create AWS resources.
- [ ] Add and promote an EKS-gated image signature admission policy once the
      GitLab project path, OIDC subject and a real signed digest are known
      (ADR-023).
- [ ] If Slack is wanted on EKS, create the AWS Secrets Manager secret
      `platformbox/alertmanager` with the JSON property `webhook_url`, then add
      `platformbox.io/slack-alerting: "true"` to the registered cluster Secret.
      Never put the webhook in Git. See `docs/SETUP.md` §8 and ADR-025.
- [x] After final verification, mark the Phase 3 PR ready and merge it through
  GitHub. Do not push directly to `main`.
- [x] After the merge, change `gitops/platform/kyverno-policies-app.yaml` to
  `targetRevision: main` if the `phase/3-platform` branch will be deleted. See
  ADR-013.
- [ ] Do **not** run `make aws-apply` unless you explicitly want a paid AWS
  demo. The local path costs $0.

## Phase log

### 2026-11-22 — Phase 5 merged

- Added seven GitHub Actions workflows: Terraform CI with fork-safe plan and
  Infracost comments, environment-gated apply, scheduled drift detection,
  GitOps manifest validation, repository security scans, Conventional Commit
  PR title enforcement and GitHub-to-GitLab mirroring.
- Added `.gitlab-ci.yml` with the seven required stages. Build, image scan,
  SBOM and sign jobs use `parallel: matrix` over the three services; Trivy,
  Syft, Cosign keyless signing, SAST, secret detection and ECR OIDC are all
  pinned and artifact-driven.
- Added `scripts/validate-workflows.sh`, wired into `make lint`, plus helpers
  for GitHub/GitLab setup, checksum-verified tool installation, digest artifact
  normalization and ADR-003 write-back.
- Added ADR-021 (Buildah over archived Kaniko) and ADR-022 (digest signing,
  loop prevention and offline workflow validation).
- Validation: `bash scripts/validate-workflows.sh` passed; `actionlint 1.7.12`
  reported no workflow errors; `bash scripts/helm-lint.sh` linted all seven
  pinned charts; `./tools/bin/make.exe check` passed with 160 overlay contract
  checks, 0 failures, and 15 tests.
- Optional cloud/cost checks skip when their variables are unset, and
  dependency review is best-effort when GitHub's dependency graph API is
  unavailable.
- Live GitHub PR checks exposed three workflow defects that were fixed on the
  branch: a relative TFLint config path, Trivy findings from downloaded third-
  party Terraform modules, and hard failures when optional integrations were
  unconfigured.
- Pull request #13 was approved by `atharvvv10`, merged by `akashhh15` as merge
  commit `c0c6575`, and the local `main` branch was fast-forwarded and rechecked.
- Live GitHub and GitLab pipelines were not run by the agent. Human test steps
  and the full secret/variable inventory are in `docs/SETUP.md` §§5–7. No AWS
  resource was created.

### 2026-11-24 — Phase 6 implemented

- Added two CEL `ValidatingPolicy` resources: `require-container-hardening`
  (seccomp, read-only root filesystem, capability drops) and
  `disallow-host-access` (host namespaces, hostPath, privileged containers).
  Both match only `app-dev`, `app-staging` and `app-prod`.
- Added 35 offline `kyverno test` assertions covering all seven policies with
  pass, fail and out-of-scope skip cases. A temporary negative control that
  changed two expected `fail` values to `pass` produced two test failures, so
  the suite detects lost denials.
- Wired `make test` to the new `policy-test` target and added a policy test step
  to the GitHub `gitops-validate` workflow.
- Fixed `scripts/gitops-validate.sh`: the CLI silently loaded zero policies when
  `kustomization.yaml` sat beside the policy manifests. It now builds a clean
  policy directory, asserts that all policies loaded, and reports 21 passes for
  dev/staging/prod, 15 passes plus 6 skips for local, and 10 passes plus 4 skips
  for local-data.
- Added `docs/threat-model.md` with assets, trust boundaries, STRIDE controls,
  residual risks and human tasks, plus ADR-023 for the scope and deferred image
  signature admission decision.
- Validation: `bash -n scripts/gitops-validate.sh scripts/policy-test.sh`
  passed; `kyverno test gitops/platform/kyverno-policies/tests --remove-color
  --require-tests` reported 35 passed, 0 failed; `./tools/bin/make.exe check`
  exited 0 with 160 overlay contract checks, Checkov 194/355/131 passed and 0
  failed, gitleaks clean, and all pytest cases passing.
- No AWS or GitLab resource was created, modified or deleted. Image signature
  admission remains a documented human task (ADR-023).

### 2026-11-25 — Phase 7 implemented

- Added six Grafana dashboard ConfigMaps under
  `gitops/platform/observability/dashboards`: cluster overview, nodes and
  Karpenter, Argo CD, API RED, worker, and Kyverno. The KPS sidecar picks them
  up through `grafana_dashboard: "1"`.
- Added 22 Prometheus recording/alerting rules: API availability and latency
  SLO ratios for 5m/1h/30m/6h/30d, error-budget gauges, four fast/slow burn
  alerts and six platform alerts. All ten alerts have severity, summary,
  description, `runbook_url` and a runbook under `docs/runbooks/`.
- Added `promtool test rules` coverage for both SLO ratios, availability and
  latency fast burn, availability slow burn, node readiness and rollout aborts.
  The CRD `.spec` is extracted before checking so `promtool` sees a plain rules
  file.
- Added structured `service`, `environment` and `version` fields to API and
  worker logs, a configurable `service_version`, worker queue/job/duration
  metrics, and `podTargetLabels` on the app ServiceMonitors. Promtail promotes
  the structured fields to Loki labels; saved queries are in
  `docs/log-queries.md`.
- Set Prometheus retention to 30d and Loki retention to 168h with explicit
  resources. KPS, Loki, Argo CD, Rollouts and Karpenter chart interfaces were
  verified against the pinned chart versions. All sizing values are documented
  as starting points with `TODO(measure)`.
- Added explicit platform ServiceMonitors for Argo CD, Argo Rollouts and
  Kyverno, and enabled the corresponding chart metrics Services. Slack routing
  is generated only by an EKS-labelled ApplicationSet; kind keeps the chart's
  null receiver. See ADR-025.
- Added `scripts/observability-validate.sh`, wired it into
  `scripts/gitops-validate.sh`, the Makefile and the `gitops-validate` workflow,
  and updated the kubeconform skip list for Prometheus Operator CRDs.
- Validation: `promtool check rules` reported `SUCCESS: 22 rules found`;
  `promtool test rules` reported `SUCCESS`; dashboard JSON, UID uniqueness,
  alert metadata, runbook links, rendered-resource assertions and Slack gating
  all passed. `bash scripts/gitops-validate.sh` reported 0 invalid resources in
  every overlay and 35 Kyverno policy tests passing.
- `./tools/bin/make.exe check` exited 0: actionlint 1.7.12 clean, pre-commit
  hooks clean, 168 overlay contract checks passed, gitleaks found no leaks,
  Checkov passed 194 Terraform/355 Kubernetes/131 Dockerfile checks with 0
  failures, and pytest passed 12 API and 8 worker tests.
- Runtime verification on kind was not run because the Docker daemon and
  `kind get clusters` were unavailable in this environment. The manual runtime
  checklist is in `docs/SETUP.md` §8.
- No AWS resource was created, modified or deleted. No GitHub or GitLab live
  pipeline was triggered.

### 2026-11-21 — Phase 3 implemented

- Added `kind-config.yaml` with host ports 80/443, the `ingress-ready=true`
  label and two worker nodes.
- Added `scripts/local-up.sh` and `scripts/local-down.sh`; `make up`/`make down`
  wrap them with explicit confirmation. `local-up` creates the cluster, installs
  pinned Argo CD, applies AppProjects and the root Application.
- Added the Argo CD app-of-apps: `gitops/bootstrap/root-app.yaml` points at
  `gitops/platform`; AppProjects live in `gitops/projects`.
- Added six platform Applications with sync waves: ingress-nginx, Kyverno,
  Kyverno policies, monitoring, logging, Argo Rollouts. All chart versions are
  pinned and verified against the chart repositories.
- Added five CEL `ValidatingPolicy` admission policies and a sample pod fixture.
  `kyverno apply` reports 5 pass, 0 fail.
- Implemented `make gitops-validate` and wired `make validate` to it. Fixed the
  recursive `$(MAKE)` call that broke on the space in the repository path.
- Added ADR-009 (CEL policies) and ADR-010 (app-of-apps bootstrap). Updated
  `docs/SETUP.md` and `docs/VERSIONS.md`.
- `make check` passes: lint, GitOps validation, gitleaks, checkov (194 Terraform
  and 131 Dockerfile checks pass, 0 fail), and 15 tests.
- `make local-up` was attempted: the kind node image was pulled, but Docker
  returned `read-only file system` when creating worker containers because C:
  was 100% full. No Kubernetes resources were created. This is a host
  environment issue, not a project defect; see `docs/SETUP.md`.
- No AWS resources created.

### 2026-11-21 — Phase 3 verification fixes

- Diagnosed a Kyverno sync failure caused by CRDs larger than the 262144-byte
  Kubernetes annotation limit. Added `ServerSideApply=true` and
  `ClientSideApplyMigration=false` to all platform Applications; ADR-011.
- Diagnosed a second stall caused by Kyverno's post-upgrade migration Job.
  Disabled `upgrade.legacyPolicyCheck` and `migration` for the disposable local
  cluster; ADR-012.
- Added `scripts/preload-images.sh` and wired it into `local-up.sh`. It pulls
  every pinned runtime image on the host and loads it into every kind node,
  preserving `@sha256:` pins in the archive manifest.
- Raised Argo CD repo-server and exec timeouts to 300 seconds for slow chart
  downloads, and disabled Dex for the local demo.
- Re-preloading a busy cluster saturated the Docker disk; etcd logged
  `slow fdatasync` and control-plane leader leases were briefly lost. The
  helper is documented to run before platform apps start, and `local-up` already
  does that. A clean rebuild is the recovery path.
- `make check` passed: all pre-commit hooks, `gitops-validate`, gitleaks,
  checkov (194 Terraform and 131 Dockerfile checks pass, 0 fail) and 15 tests.
- A final clean `local-down`/`local-up` was started with no competing disk work.
  It was paused by the human at 9 of 21 preloaded images because it was after
  midnight; Argo CD had not been installed and no Applications existed yet.
- No AWS resources created.

### 2026-11-22 — Phase 3 final verification

- Resumed with a fresh `make local-down` and `make local-up` after Docker
  Desktop was restarted. The rebuild completed with `exit=0` and no manual
  cluster steps.
- All six platform Applications reached `Healthy`; the root sync succeeded.
- `kyverno-policies` initially reported `Unknown` sync because it was the only
  Git-path child Application and was pinned to `main` while the root followed
  `phase/3-platform`. Fixed the committed revision and recorded ADR-013.
- Re-ran `make check` after the fix: `exit=0`, all pre-commit hooks,
  `gitops-validate`, gitleaks (no leaks), checkov (194 Terraform passed, 0
  failed, 37 skipped; 131 Dockerfile passed, 0 failed) and 15 tests passed.
- Verified with `kubectl get applications -n argocd`: `argo-rollouts`,
  `ingress-nginx`, `kyverno`, `kyverno-policies`, `logging`, `monitoring` and
  `root` are all `Synced`/`Healthy`; root operation `Succeeded`.
- Verified `kubectl get validatingpolicies.policies.kyverno.io -A`: all five
  policies are `READY`.
- No AWS resources created.

### 2026-11-22 — Phase 3 merged

- PR #6 was approved by a reviewer with write access and merged into `main`.
- Post-merge cleanup changes `kyverno-policies` back to `targetRevision: main`
  so the review branch can be deleted safely. ADR-013 updated.
- No AWS resources created.

### 2026-11-21 — Phase 2 complete

- Built `apps/api`: FastAPI service with health/ready/metrics/items endpoints,
  structured JSON logging, pydantic-settings, Postgres + Redis clients with
  retry, SQLAlchemy models, Prometheus instrumentation.
- Built `apps/worker`: FastAPI service with health/ready/metrics/stats and a
  background Redis-list consumer loop with graceful shutdown.
- Built `apps/frontend`: static HTML/CSS/JS served by nginx, with security
  headers and healthcheck.
- Added `apps/docker-compose.yml` wiring postgres, redis, api, worker, frontend.
- Multi-stage Dockerfiles (non-root UID 1000, read-only-friendly, hadolint clean).
- Added `sql/init.sql` for the items table.
- Tests: 9 (api) + 6 (worker) passing; ruff clean; hadolint clean; yamllint
  clean; all three images build and smoke-tested (health endpoints return 200).
- No AWS resources created.

### 2026-11-21 — Phase 1 complete

- Built `infra/bootstrap`: S3 state bucket (versioning, KMS, TLS-only policy,
  lifecycle, native locking), GitHub and GitLab OIDC providers, three CI IAM
  roles (plan/apply/ecr-push) with scoped trust policies, and a budget with
  three alert thresholds.
- Built 8 modules: network (VPC, flow logs, S3 endpoint), eks (KMS, control
  plane logs, access entries, managed add-ons, system node group with IMDSv2),
  karpenter (controller IRSA, node role, interruption queue, EventBridge rules,
  Helm release), ecr (immutable tags, KMS, lifecycle), irsa (reusable), secrets
  (value-less Secrets Manager entries, KMS), rds (toggleable PostgreSQL with
  managed master password), budgets.
- Built dev and prod environments wiring all modules, with Argo CD as the final
  bootstrap step and the root Argo CD Application.
- Added ADR-005 to ADR-008.
- Validation:
  - `terraform fmt -check -recursive` passes.
  - `terraform init -backend=false` + `terraform validate` pass on bootstrap,
    dev and prod.
  - `tflint` passes on all three root modules.
  - `checkov` reports 0 failures (194 passed, 37 skipped with documented reasons).
  - `trivy config` reports 0 failures on our own Terraform; remaining findings
    are in vendored community modules and are documented as accepted.
  - `terraform test` passes on the bootstrap module (mock provider).
- No apply or plan was run. Commands for the human are in the report.

### 2026-11-21 — Phase 0 complete

- Confirmed the zero-cost requirement and selected local-first execution.
- Added ADR-000 and ADR-004 to record the deviation and the local substitutes.
- Initialized the repository on branch `phase/0-foundation`.
- Pinned the toolchain in `docs/VERSIONS.md`.
- Added the repository skeleton, Makefile, pre-commit configuration, quality
  configs, issue and PR templates, SECURITY.md, and ADR-000 to ADR-004.
- Added `scripts/install-tools.sh` (pinned Windows downloads, idempotent),
  `scripts/check-tools.sh` and `scripts/checkov.sh` (venv-safe wrapper for the
  Windows path-with-spaces problem).
- Validation:
  - `make help` lists all 15 targets with descriptions.
  - `pre-commit run --all-files` passes: YAML, whitespace, merge conflicts,
    line endings, yamllint, gitleaks. Terraform, ruff, hadolint and checkov
    hooks skip because those file types do not exist yet.
  - `make check` passes: lint, the phase placeholder for validate, secret scan,
    Checkov scan and the phase placeholder for tests.
  - `make tools-check` reports every required tool present, including trivy 0.76.2
  (installed via winget after this phase report was drafted).
  - The conventional-commit hook was tested with a valid message (passes) and
    an invalid one (rejected).
- No commit exists yet: Git `user.name` and `user.email` are unset on this
  machine, so the owner must configure them and commit.
