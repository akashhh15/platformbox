# AGENTS.md — Cloud Platform in a Box

Read this file completely at the start of every session. It is the source of truth for rules, decisions and the quality bar. If a user prompt conflicts with it, stop and ask which one wins.

> **Execution mode (ADR-000): local-first, zero cost.**
> The AWS EKS architecture below is the production target design, but this repository is built and demonstrated on a local `kind` cluster at **zero AWS spend**. AWS Terraform is validated with `terraform validate` and `terraform test` using mock providers and is **never applied** by the agent. `make up` / `make down` operate on the local cluster. AWS-specific components have documented local substitutes (ADR-000 and ADR-004). Do not create AWS resources unless the human explicitly asks for a paid demo.

---

## 1. Mission

Build a production-style cloud platform on AWS as a flagship DevOps portfolio project.

Audience: hiring managers and senior DevOps / SRE / platform interviewers.

It must look and behave like something a real platform team would run: secure by default, fully automated, observable, cost-aware, documented, and reproducible from scratch with a few commands.

Quality bar: every file must survive a senior engineer's code review. Prefer fewer things done properly over many things half-done.

---

## 2. What the platform does

A small microservices app (frontend, api, worker, Postgres, Redis) runs on Amazon EKS. Everything is provisioned with Terraform and delivered with GitOps.

End-to-end flow:

1. A pull request opens. GitHub Actions runs Terraform and manifest checks, security scans, `terraform plan` and a cost estimate.
2. Merge to `main`. Terraform apply for dev runs behind a manual approval. The repo is mirrored to GitLab.
3. GitLab CI tests, builds, scans, generates an SBOM, signs the image, pushes to ECR using OIDC (no static keys), then updates the image tag under `gitops/`.
4. Argo CD syncs the change. Argo Rollouts performs a canary release with Prometheus-based analysis and automatic rollback.
5. Kyverno admission policies block unsigned or non-compliant workloads.
6. Prometheus, Grafana and Loki provide metrics, logs and SLO burn-rate alerts, each alert with a runbook.
7. Cost controls: Infracost on PRs, AWS Budgets, Karpenter spot capacity, one-command teardown.

**Local-first execution (ADR-000):** the flow above is the AWS production path. The default demo runs the same platform on `kind` with ingress-nginx, in-cluster PostgreSQL, GHCR or the GitLab Container Registry and replica-weighted canaries. AWS-only steps are design-validated, never applied.

---

## 3. Stack and fixed decisions

| Area | Choice | Notes |
|---|---|---|
| Cloud | AWS | Default region `ap-south-1`, always a variable |
| Execution mode | Local-first on `kind` | Zero AWS spend by default; the AWS path is validated but not applied (ADR-000) |
| IaC | Terraform | Pin `required_version` and all providers. State in S3 with native locking (`use_lockfile`); fall back to DynamoDB locking only if the pinned Terraform version does not support it |
| Kubernetes | Amazon EKS | Use a currently supported version, verified at build time |
| Nodes | Small managed node group (system) + Karpenter | `NodePool` + `EC2NodeClass`, spot and on-demand, consolidation on |
| Pod AWS auth | IRSA | Mention EKS Pod Identity as the alternative in an ADR |
| Ingress | AWS Load Balancer Controller (ALB) | ExternalDNS + ACM only if a `domain_name` variable is set |
| GitOps | Argo CD | App-of-apps + ApplicationSets, AppProjects with RBAC |
| Manifests | Kustomize for our apps, Helm for third-party | |
| Progressive delivery | Argo Rollouts | Canary + Prometheus AnalysisTemplate |
| Secrets | AWS Secrets Manager + External Secrets Operator | No secrets in git, ever |
| Policy | Kyverno | Audit first, then Enforce |
| Infra CI | GitHub Actions | OIDC to AWS |
| App CI | GitLab CI | OIDC to AWS, repo mirrored from GitHub |
| Registry | Amazon ECR | Immutable tags, scan on push, lifecycle policy |
| Supply chain | Trivy, Syft (CycloneDX), Cosign keyless, Gitleaks, GitLab SAST | |
| Observability | kube-prometheus-stack, Loki + Grafana Alloy | Dashboards and alerts as code |
| Cost | Infracost, AWS Budgets, Karpenter consolidation | OpenCost as extension |
| App | Python 3.12+ FastAPI (api, worker), small static frontend | Postgres (RDS, toggleable), Redis (in-cluster) |
| Load / chaos | k6, Chaos Mesh or AWS FIS | Extension phase |
| Local dev | docker compose, kind | Must work with zero AWS cost |

If you believe a decision should change, write an ADR proposing the change and ask. Do not silently deviate.

---

## 4. Repository layout

```
cloud-platform-in-a-box/
├── AGENTS.md
├── README.md
├── PROGRESS.md
├── Makefile
├── LICENSE (MIT)
├── .pre-commit-config.yaml  .editorconfig  .gitignore  .gitleaks.toml
├── .tflint.hcl  .checkov.yaml  .yamllint.yaml  .trivyignore
├── .github/
│   ├── workflows/            (terraform-ci, terraform-apply, drift-detection,
│   │                          gitops-validate, security, mirror-to-gitlab, pr-title)
│   ├── CODEOWNERS  PULL_REQUEST_TEMPLATE.md  ISSUE_TEMPLATE/  dependabot.yml
├── .gitlab-ci.yml
├── infra/
│   ├── bootstrap/            (state bucket, GitHub + GitLab OIDC providers and CI roles, budget)
│   ├── modules/              (network, eks, ecr, irsa, secrets, rds, budgets)
│   └── environments/
│       ├── dev/              (applied)
│       └── prod/             (written, must pass validate and plan, not applied by default)
├── apps/
│   ├── frontend/  api/  worker/       (each: src, tests, Dockerfile, README)
│   └── docker-compose.yml
├── gitops/
│   ├── bootstrap/            (Argo CD root application)
│   ├── projects/             (AppProjects)
│   ├── platform/             (LB controller, Karpenter pools, External Secrets, Kyverno,
│   │                          policies, monitoring, logging, Argo Rollouts, ...)
│   ├── apps/                 (Kustomize base + overlays: dev, staging, prod)
│   └── applicationsets/
├── loadtest/                 (k6 scripts)
├── chaos/                    (experiments + game day template)
├── scripts/                  (Python and shell helpers)
└── docs/
    ├── architecture.md  security.md  costs.md  demo.md  interview-notes.md
    ├── SETUP.md  VERSIONS.md
    ├── adr/                  (numbered ADRs)
    ├── runbooks/
    └── images/
```

Environments: only `dev` is applied by default. `prod` is fully written and must pass `validate` and `plan`, but is not applied (cost). Inside the cluster, namespaces `app-dev`, `app-staging`, `app-prod` demonstrate promotion.

---

## 5. Hard rules (never break these)

1. **Never run anything that changes real infrastructure or costs money.** That means `terraform apply`, `terraform destroy`, `kubectl apply/delete` against a real cluster, and any `aws` CLI call that creates, modifies or deletes resources. The human runs those. You may run: `terraform fmt`, `terraform init -backend=false`, `terraform validate`, `terraform test`, `tflint`, `checkov`, `trivy`, `kubeconform`, `kustomize build`, `helm template`, `helm lint`, `kyverno test`, `docker build`, `pytest`, `ruff`, `hadolint`, and `kind` for local clusters.
2. **Never commit secrets.** No keys, tokens, passwords, account IDs of real accounts in committed files unless they are intentionally public. If you find one, stop and report.
3. **Verify, don't guess.** Before using any chart, provider, module, API version, GitHub Action or CLI flag, check current official documentation or the tool's own `--help` / schema output. Pin exact versions: providers, modules, Helm charts, container images (digest where practical), GitHub Actions (commit SHA). Record choices in `docs/VERSIONS.md`.
4. **One phase at a time.** Do only the phase you were asked to do. Do not start the next one.
5. **Small commits.** Conventional Commits (`feat:`, `fix:`, `docs:`, `ci:`, `chore:`, `refactor:`). One logical change per commit.
6. **Never claim you ran or verified something you did not.** Show the real command and a summary of the real output. If you could not run something, say so and say why.
7. **No invented numbers.** Costs, timings, performance and reliability figures in docs must come from real measurements. Otherwise write `TODO(measure): <what to measure and how>` and list it in `docs/SETUP.md` under "Human tasks".
8. **No half-finished code.** Values only a human can supply (account ID, e-mail, domain, tokens) are variables with clear names, documented in `docs/SETUP.md` and `*.tfvars.example`.
9. **Ask when ambiguous.** Ask at most 3 questions at a time, each with a recommended default.
10. **Keep `PROGRESS.md` current:** phase status, decisions, open items, human tasks.
11. **Every non-obvious decision gets an ADR** in `docs/adr/` (context, decision, alternatives considered, consequences).
12. **Do not add tools, services or features outside the current phase.** If you think something is missing, list it under "Suggestions" in your report.

---

## 6. Security baseline

- No static AWS credentials anywhere. CI authenticates through OIDC federation with roles scoped to a specific repo or project, branch and environment.
- IAM least privilege. No `"Action": "*"` and no `"Resource": "*"` unless the API requires it, with a comment explaining why.
- S3: block public access, TLS-only bucket policy, encryption, versioning.
- EKS: secrets encryption with KMS, IMDSv2 required, nodes in private subnets, public API endpoint restricted by a CIDR variable, control plane logging enabled, access entries instead of `aws-auth`.
- Containers: non-root user, read-only root filesystem, drop ALL capabilities, `allowPrivilegeEscalation: false`, seccomp `RuntimeDefault`, resource requests and limits.
- Namespaces: Pod Security Standards `restricted` (use `baseline` only where a platform component requires it, documented).
- NetworkPolicy: default deny plus explicit allows.
- Images: immutable tags, pinned base images, scanned, signed, SBOM attached as an attestation. Only signed images are admitted to app namespaces.
- GitHub Actions: pinned by commit SHA, minimal `permissions:` per workflow and job, no `pull_request_target` with untrusted code.

---

## 7. Coding standards

**Terraform**
- Every module has `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf` and a README generated with terraform-docs.
- `validation` blocks on variables where useful, descriptions on all variables and outputs.
- `default_tags` with `Project`, `Environment`, `Owner`, `ManagedBy=terraform`.
- Naming: `${var.project}-${var.environment}-<thing>`. No hardcoded account IDs or regions.
- Prefer `for_each` over `count` when keys are meaningful. Use `moved` blocks when refactoring.
- Wrapping well-maintained community modules (VPC, EKS) in our own thin modules is fine. Write own modules for ECR, IRSA, OIDC/CI roles, budgets, secrets. Explain the split in an ADR.
- Add native `terraform test` (`.tftest.hcl`) for modules where practical.

**Kubernetes / GitOps**
- Standard `app.kubernetes.io/*` labels, liveness/readiness/startup probes, PodDisruptionBudgets, topology spread constraints, HPA, `ServiceMonitor`, resource requests and limits.
- Argo CD sync waves for ordering. Dev auto-syncs, staging syncs after dev passes, prod is manual sync (documented).

**Docker**
- Multi-stage builds, minimal final image (distroless or slim), non-root UID, `.dockerignore`, OCI labels, hadolint clean, base images pinned by tag and digest.

**Python**
- 3.12+, type hints, `ruff` for lint and format, `pytest`, structured JSON logging, configuration via environment (pydantic-settings), dependencies locked.

**CI**
- Fail fast, cache dependencies, use concurrency groups, pin tool versions, least privilege.

**Docs**
- Must match the code exactly. Each doc states its purpose and how to verify its claims. Use Mermaid for diagrams.

---

## 8. Quality gates

The Makefile must provide at least:

`make help`, `make fmt`, `make lint`, `make validate`, `make scan`, `make test`, `make check` (runs all of the above), `make local-up`, `make local-down`, `make up`, `make down`, `make demo`.

`make up` and `make down` print what they will do and require explicit confirmation. A phase is not done until `make check` passes.

In local-first mode, `make up` creates the kind cluster and installs Argo CD; `make down` deletes it. `make aws-plan` and `make aws-apply` are optional, human-run targets for the AWS production path.

---

## 9. Git workflow

- One branch per phase: `phase/<n>-<slug>`.
- Conventional commits. Tag `v0.<n>.0` only after the human approves the phase.
- `main` is protected (document the required settings in `docs/SETUP.md`): PR required, status checks required, no force pushes.

---

## 10. Phase report format

End every phase with exactly this structure:

1. **Done**: what was built, in bullets.
2. **Files changed**: grouped by area.
3. **Commands run**: each with a short summary of the real result.
4. **Not verified**: what could not be run and why.
5. **Decisions and ADRs**: what was decided and where it is recorded.
6. **Human tasks**: things only the human can do (AWS actions, screenshots, tokens, measurements).
7. **Suggestions**: optional improvements outside the phase scope.
8. **Next phase**: what is needed to start it.

Then stop and wait.

---

## 11. Definition of done

**Per phase:** deliverables exist, `make check` passes, docs and ADRs updated, `PROGRESS.md` updated, report delivered.

**Overall project:**
- A fresh clone plus `docs/SETUP.md` is enough to stand up the platform locally at zero cost; the AWS production path is optional and clearly labeled.
- `make down` removes everything it created.
- No secrets, no placeholders, no dead code, no unverified claims.
- README tells the story in 60 seconds: what it is, architecture diagram, what makes it production-grade, how to run it, results (measured), and what was learned.
- Every component can be explained in `docs/interview-notes.md` with trade-offs and failure modes.
