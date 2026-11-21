# Progress

## Phase status

| Phase | Status | Notes |
|---|---|---|
| 0 — Repository foundation | Complete — awaiting review | Skeleton, Makefile, pre-commit, docs, ADRs; `make check` passes |
| 1 — Terraform foundation | Complete — awaiting review | Bootstrap, 8 modules, dev/prod environments, 4 ADRs; fmt/validate/tflint/checkov/trivy/test pass |
| 2 — Application and containers | Complete — awaiting review | FastAPI api/worker, static frontend, compose; ruff/pytest/hadolint pass; images build |
| 3 — GitOps and platform layer | Complete — live cluster start pending host disk | kind config, Argo CD app-of-apps, ingress, CEL policies, monitoring, logging, rollouts; `make check` passes; Docker host disk full blocks `make local-up` |
| 4 — Application delivery | Not started | Kustomize base and dev/staging/prod overlays |
| 5 — CI/CD | Not started | GitHub Actions and GitLab CI, SBOM, signing, write-back |
| 6 — DevSecOps and policy | Not started | Kyverno policies and tests, threat model |
| 7 — Observability and SLOs | Not started | Dashboards, recording rules, burn-rate alerts, runbooks |
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

## Open items

- Git `user.name` and `user.email` are configured on this machine (no-reply).
- The GitHub repository and branch protection are configured.
- The GitLab project and mirror credentials are not created (Phase 5).
- The Slack incoming webhook is not supplied yet; Alertmanager will use a null
  receiver until it is (Phase 7).
- The optional AWS path has no account, budget e-mail or OIDC roles. This is
  intentional and costs nothing.
- The C: drive is full, so Docker Desktop's metadata is read-only. The kind
  cluster could not be created. Host cleanup and a Docker restart are required;
  no project file depends on this.
- The root Argo CD Application reads `main`. The Phase 3 pull request must be
  merged before the platform apps can sync.

## Human tasks

These are the tasks only the repository owner can complete. Full instructions
are in [docs/SETUP.md](docs/SETUP.md).

- [x] Start Docker Desktop before running kind or Docker builds.
- [x] Configure Git identity: `git config --global user.name "..."` and
  `git config --global user.email "..."`.
- [x] Create the GitHub repository, push `main`, and enable branch protection.
- [x] Replace `@REPLACE_ME` in `.github/CODEOWNERS` with the real owner.
- [ ] Create the GitLab project and mirror credentials when Phase 5 starts.
- [ ] Supply the Slack webhook through a secret, never through Git.
- [ ] Do **not** run `make aws-apply` unless you explicitly want a paid AWS
  demo. The local path costs $0.

## Phase log

### 2026-11-21 — Phase 3 complete (live cluster start pending host disk)

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
