# Progress

## Phase status

| Phase | Status | Notes |
|---|---|---|
| 0 — Repository foundation | Complete — awaiting review | Skeleton, Makefile, pre-commit, docs, ADRs; `make check` passes |
| 1 — Terraform foundation | Complete — awaiting review | Bootstrap, 8 modules, dev/prod environments, 4 ADRs; fmt/validate/tflint/checkov/trivy/test pass |
| 2 — Application and containers | Not started | FastAPI api/worker, static frontend, compose |
| 3 — GitOps and platform layer | Not started | Local kind cluster, Argo CD, ingress-nginx, policy, observability |
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

## Open items

- Docker Desktop is installed but its daemon is not running; local builds and
  kind need it.
- Git `user.name` and `user.email` are not configured on this machine.
- The GitHub repository, GitLab project and branch protection are not created.
- The Slack incoming webhook is not supplied yet; Alertmanager will use a null
  receiver until it is.
- The optional AWS path has no account, budget e-mail or OIDC roles. This is
  intentional and costs nothing.

## Human tasks

These are the tasks only the repository owner can complete. Full instructions
are in [docs/SETUP.md](docs/SETUP.md).

- [ ] Start Docker Desktop before running kind or Docker builds.
- [ ] Configure Git identity: `git config --global user.name "..."` and
  `git config --global user.email "..."`.
- [ ] Create the GitHub repository, push `main`, and enable branch protection.
- [ ] Replace `@REPLACE_ME` in `.github/CODEOWNERS` with the real owner.
- [ ] Create the GitLab project and mirror credentials when Phase 5 starts.
- [ ] Supply the Slack webhook through a secret, never through Git.
- [ ] Do **not** run `make aws-apply` unless you explicitly want a paid AWS
  demo. The local path costs $0.

## Phase log

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
