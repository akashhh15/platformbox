# Cloud Platform in a Box — Opencode Prompt Pack

## How to use this

1. Create an empty folder, run `git init`, and open opencode inside it.
2. Copy `AGENTS.md` into the repo root. Opencode loads it automatically as persistent project rules, so every prompt below can stay short.
3. Start in **Plan mode** (Tab switches between Plan and Build; if your version differs, just add "plan only, do not write any files" to the prompt). Paste **Prompt 0**, review the plan, answer its questions, then switch to Build mode.
4. Paste the phase prompts **one at a time, in order**. Never paste several together. One giant prompt makes the agent drift and skip things.
5. After each phase: read the report, run `make check` yourself, review the diff, commit or merge, then move on.
6. If the agent loses context or you start a new session, use the **Resume prompt** at the bottom.

Phases 0–8 and 11–12 are the core. Phases 9 and 10 are extensions that make the project stand out. Do them if time allows.

---

## Prompt 0 — Kickoff (Plan mode, no files yet)

```
Read AGENTS.md completely. You are going to build "Cloud Platform in a Box", a production-grade AWS DevOps platform portfolio project, in phases.

Do NOT write any files yet. Produce:

1. Your understanding of the project in at most 10 lines.
2. A phase-by-phase plan for Phases 0 to 12 (Foundation, Terraform, App, GitOps and platform layer, App delivery, CI/CD, DevSecOps and policy, Observability and SLOs, Progressive delivery, Resilience, FinOps, Documentation, Final audit). For each phase give deliverables, main risks, and what you need from me.
3. Up to 5 questions, each with your recommended default. Cover: AWS region, whether I own a domain (optional), whether I have a Slack webhook (optional), whether RDS should be enabled by default or Postgres run in-cluster for dev, and my GitHub and GitLab usernames.
4. The list of tools I must install locally, with the purpose of each.
5. An estimated AWS cost for (a) one 4-hour demo session of the dev environment and (b) leaving dev running for a month. Label these clearly as estimates with your assumptions, and tell me how to verify them (AWS Pricing Calculator, Infracost).
6. The top 5 things most likely to go wrong in this project and how the plan reduces each risk.

Stop after this and wait for my answers.
```

---

## Prompt 1 — Phase 0: Repository foundation

```
Phase 0: Repository foundation. Work on branch phase/0-foundation.

Read AGENTS.md first. Build the repository skeleton and developer tooling. Do not write Terraform, app code or Kubernetes manifests yet.

Deliverables:
1. The full directory layout from AGENTS.md section 4 (use .gitkeep only where a folder will stay empty for now).
2. Makefile with all targets from AGENTS.md section 8. Targets whose tooling does not exist yet must print a clear "not implemented until phase N" message and exit 0. `make help` lists every target with a description.
3. .pre-commit-config.yaml with pinned hooks: terraform fmt, terraform validate, terraform-docs, tflint, checkov, gitleaks, hadolint, yamllint, ruff, end-of-file-fixer, trailing-whitespace, check-merge-conflict, and a conventional-commit message check.
4. .gitignore (Terraform, Python, Node, editors, OS files, kubeconfig, *.tfvars except *.tfvars.example, *.tfstate), .editorconfig, .gitleaks.toml, .tflint.hcl, .checkov.yaml, .yamllint.yaml, empty .trivyignore with a header comment explaining that every ignore needs a reason and an expiry date.
5. LICENSE (MIT), CODEOWNERS, PULL_REQUEST_TEMPLATE.md (checklist: tests, docs, security impact, cost impact, rollback plan), issue templates (bug, feature), dependabot.yml covering github-actions, docker, pip and terraform.
6. README.md skeleton with the sections listed in AGENTS.md section 11, clearly marked as filled in later. No fake badges or fake numbers.
7. PROGRESS.md with the phase table.
8. docs/SETUP.md: prerequisites (AWS account with MFA and no root usage, budget alert, required CLI tools with purpose, GitHub and GitLab setup, branch protection settings, GitHub environments with required reviewers), and a "Human tasks" section that later phases will append to.
9. docs/VERSIONS.md (table of tool, version, date verified, source) and docs/adr/ with a template plus ADR-001 (monorepo on GitHub, GitLab mirror and why), ADR-002 (OIDC instead of static credentials), ADR-003 (GitOps write-back design: how the GitLab pipeline updates image tags in the GitHub repo, how infinite pipeline loops are avoided, and the token trade-off).

Validation: run `pre-commit run --all-files` and `make help`. Fix everything that fails.

Finish with the phase report format from AGENTS.md section 10, then stop.
```

---

## Prompt 2 — Phase 1: Terraform foundation (bootstrap, modules, environments)

```
Phase 1: Terraform. Work on branch phase/1-terraform.

Read AGENTS.md first. Remember: never run apply or destroy. Verify every provider, module and argument against current docs and pin versions.

1a. infra/bootstrap (applied once, locally, by the human):
- S3 state bucket: versioning, encryption, public access block, TLS-only policy, lifecycle for old versions, native state locking.
- IAM OIDC providers for GitHub Actions and GitLab (gitlab.com).
- IAM roles, each with a precise trust policy (repo or project path, branch, environment) and least-privilege permissions, each documented:
  * github-terraform-plan: read-only plus state access, usable from pull requests.
  * github-terraform-apply: restricted to main branch and the `dev` environment.
  * gitlab-ecr-push: can only push to the project's ECR repositories, only from the main branch or protected tags.
- AWS Budget with e-mail alert (e-mail is a variable) at several thresholds.

1b. infra/modules (each with README via terraform-docs, validation blocks, and `terraform test` where practical):
- network: VPC across 3 AZs, public and private subnets, single NAT gateway toggle for dev (HA NAT for prod), S3 gateway endpoint, flow logs, required Karpenter and ELB subnet tags.
- eks: KMS secrets encryption, IMDSv2, control plane logs, access entries, restricted public endpoint CIDRs, IRSA OIDC provider, small managed node group for system workloads, managed add-ons (vpc-cni, coredns, kube-proxy, ebs-csi) with their IRSA roles.
- karpenter: controller IAM, SQS interruption queue and EventBridge rules, node IAM role, Helm install of the controller (NodePools themselves live in gitops/ later).
- ecr: immutable tags, scan on push, lifecycle policy, KMS encryption, repository policy.
- irsa: reusable module that creates a role for a service account with a policy document input.
- secrets: Secrets Manager secrets with no secret values in code.
- rds: optional PostgreSQL (toggle variable), small instance class by default, private subnets, security group only from node security group, managed master password in Secrets Manager, backups enabled.
- budgets: reusable budget module.

1c. infra/environments/dev and infra/environments/prod:
- Backend configuration, `terraform.tfvars.example`, `default_tags`, outputs, wiring of all modules.
- Terraform also installs Argo CD (Helm release) as the final bootstrap step and creates the root Argo CD Application pointing at gitops/bootstrap. Everything else in-cluster is managed by Argo CD later.
- prod uses different sizing and HA settings but is not meant to be applied by default.

Write ADRs for: wrapping community modules, IRSA vs Pod Identity, single NAT in dev, state locking approach.

Validation (run all that apply): `terraform fmt -check -recursive`, `terraform init -backend=false` and `terraform validate` in every root module, `tflint`, `checkov`, `trivy config`, `terraform test`. Fix all findings or document each suppression with a reason.

Do NOT run plan or apply. Instead, in the report give me the exact commands to run bootstrap, then dev, what outputs to check, and what the expected resources are.

Finish with the phase report, then stop.
```

---

## Prompt 3 — Phase 2: Application, containers, local development

```
Phase 2: Application and containers. Work on branch phase/2-app.

Read AGENTS.md first. Build a small but realistic microservices app that exists to showcase the platform, not to be a product.

Services:
- api (FastAPI): CRUD for a simple `items` resource on PostgreSQL (SQLAlchemy + Alembic migrations), `/healthz`, `/readyz` (checks DB), `/version` (git SHA from a build arg), `/metrics` (Prometheus: request count, latency histogram, error count), structured JSON logs, graceful shutdown, configuration via environment (pydantic-settings).
- worker (Python): consumes jobs from Redis, exposes metrics and health endpoints, graceful shutdown.
- frontend: tiny static UI served by an unprivileged nginx image that calls the api and shows the running version and hostname.
- Fault injection: an opt-in module in the api, enabled only when `FAULT_INJECTION_ENABLED=true`, that can add latency and return 5xx at a configurable rate. It must be disabled by default and in the prod overlay. This is used later to demonstrate automatic canary rollback.

Quality:
- Tests with pytest (unit plus API tests against a test database), meaningful coverage on core logic, `ruff` lint and format clean, dependencies locked.
- Dockerfiles: multi-stage, minimal final image, non-root UID, compatible with read-only root filesystem, base images pinned by tag and digest, OCI labels, `.dockerignore`, hadolint clean.
- `apps/docker-compose.yml` runs the whole stack locally with Postgres and Redis, with healthchecks.
- Each service has a short README (what it does, env vars, how to run tests).

Validation: pytest, ruff, hadolint, `docker build` for each image, `trivy image` for each image (report HIGH and CRITICAL findings and fix or justify them), `docker compose up` smoke test (create an item, see the worker process a job, hit /metrics). Hook everything into `make test`, `make lint`, `make scan`, `make local-up`, `make local-down`.

Finish with the phase report, then stop.
```

---

## Prompt 4 — Phase 3: GitOps foundation and platform layer

```
Phase 3: GitOps foundation and platform layer. Work on branch phase/3-platform.

Read AGENTS.md first. Everything in the cluster except Argo CD itself and the Karpenter controller is managed by Argo CD from gitops/. Verify chart versions and CRD API versions against current docs, and pin them.

Deliverables:
- gitops/bootstrap: root application (app-of-apps).
- gitops/projects: AppProjects (platform, apps) with restricted source repos, destinations and cluster-resource allow-lists, plus RBAC notes.
- gitops/platform as Argo CD Applications with sync waves for correct ordering:
  * AWS Load Balancer Controller (IRSA role comes from Terraform, referenced through values)
  * Karpenter NodePool and EC2NodeClass resources (spot and on-demand mix, sensible limits, consolidation enabled, discovery tags)
  * metrics-server
  * External Secrets Operator and a ClusterSecretStore for AWS Secrets Manager
  * Kyverno (install only; policies come in phase 6)
  * kube-prometheus-stack (install with sane retention and resources; dashboards come in phase 7)
  * Loki with Grafana Alloy for log collection (install only)
  * Argo Rollouts
  * Optional: ExternalDNS and cert-manager, enabled only when a domain variable is set
- Namespaces with Pod Security Standards labels and default-deny NetworkPolicies where applicable.
- Each platform component gets a short doc in docs/architecture.md (what it does, why chosen, failure mode).

Validation without touching AWS: `kustomize build`, `helm template` with the pinned versions, `kubeconform` (with CRD schemas), `yamllint`. Then create a local `kind` cluster and install the components that do not need AWS (Kyverno, Argo Rollouts, kube-prometheus-stack in a reduced configuration, External Secrets with a fake store) to prove the manifests apply and become healthy. Delete the kind cluster afterwards. Add `make gitops-validate` and include it in `make check`.

Finish with the phase report and, under Human tasks, the exact steps to verify on the real dev cluster after Terraform apply (what Argo CD should show, which pods should be Running).

Stop after the report.
```

---

## Prompt 5 — Phase 4: Application delivery manifests

```
Phase 4: Application delivery. Work on branch phase/4-app-delivery.

Read AGENTS.md first. Create the Kubernetes manifests that deploy the apps in gitops/apps with Kustomize: one base and three overlays (dev, staging, prod).

For every service:
- ServiceAccount, Service, and Deployment (frontend, worker) or Argo Rollout (api; the canary strategy itself is finished in phase 8, here use a basic rollout that works).
- Probes, resource requests and limits, restricted securityContext, topologySpreadConstraints, PodDisruptionBudget, HPA.
- ServiceMonitor for api and worker.
- ExternalSecret that pulls database credentials from AWS Secrets Manager (no secret values in git).
- Ingress using the AWS Load Balancer Controller with sensible annotations (health check path, target type ip), and TLS only if the domain variable is set.
- NetworkPolicies: default deny in each app namespace, then explicit allows (frontend to api, api to Postgres and Redis, worker to Redis and Postgres, Prometheus scrape, DNS, ingress from the load balancer).
- Image references use a placeholder tag that CI will replace (document the exact mechanism, e.g. Kustomize `images:` entries, and make sure it is machine-editable).

Argo CD:
- An ApplicationSet that creates one Application per environment/namespace.
- Dev auto-syncs with prune and self-heal. Staging auto-syncs. Prod is manual sync. Document the promotion model in docs/architecture.md.

Overlays: dev uses fault injection allowed and smaller resources, prod disables it and uses higher replica counts.

Validation: `kustomize build` for every overlay, `kubeconform`, `yamllint`, `kyverno` CLI checks of the rendered manifests against the policies you plan for phase 6 (just the basic ones for now), and a local `kind` smoke test where the app runs with in-cluster Postgres and Redis substituted via a local-only overlay. Show me the rendered manifest summary per overlay.

Finish with the phase report, then stop.
```

---

## Prompt 6 — Phase 5: CI/CD (GitHub Actions + GitLab CI)

```
Phase 5: CI/CD. Work on branch phase/5-cicd.

Read AGENTS.md first and re-read ADR-003 about the write-back design. Pin every action by commit SHA, set minimal `permissions:` on every workflow and job, and use concurrency groups.

GitHub Actions (infra and repo quality):
- terraform-ci.yml (pull requests): fmt, validate, tflint, checkov, trivy config, `terraform plan` through OIDC with the read-only role for dev, Infracost cost diff comment, plan summary comment. Plans for forks must not receive credentials.
- terraform-apply.yml (push to main): apply to dev only, behind a GitHub environment with required reviewers, using the apply role.
- drift-detection.yml (scheduled): plan on a schedule, open or update an issue when drift is detected.
- gitops-validate.yml: kustomize build, helm lint, kubeconform, yamllint, kyverno CLI tests.
- security.yml: gitleaks, dependency review, CodeQL for Python.
- pr-title.yml: enforce conventional commit PR titles.
- mirror-to-gitlab.yml: mirror main to GitLab, with a documented token or deploy-key setup.

GitLab CI (.gitlab-ci.yml), stages lint, test, build, scan, sign, publish, deploy-gitops, for each app service using a matrix or parent-child pipelines:
- ruff and pytest (with service containers where needed), hadolint.
- Build with Buildah or Docker buildx (check whether Kaniko is still maintained before considering it, and record the choice in an ADR).
- GitLab SAST and secret detection templates, Trivy filesystem and image scans failing on HIGH and CRITICAL (exceptions only through .trivyignore with reason and expiry).
- Syft SBOM in CycloneDX format, Cosign keyless signing and SBOM attestation using the GitLab OIDC id_token.
- Push to ECR using AWS OIDC (web identity) with the gitlab-ecr-push role. No static keys.
- deploy-gitops job: updates the image tag (by digest) in the dev overlay by committing to the GitHub repo, using the design from ADR-003. Staging and prod promotion happens through pull requests, not direct commits. Implement the loop-prevention (`[skip ci]` and path rules) so a gitops commit does not trigger another build.
- Cache dependencies, publish test and scan reports as artifacts, show a pipeline summary.

Also: a scripts/ helper to validate workflows locally (actionlint) and `glab ci lint` style validation for .gitlab-ci.yml if available, wired into `make lint`.

You cannot run these pipelines. In the report, explain precisely how I will test each one (which PR to open, which variable to set), list every GitHub secret/variable and GitLab CI/CD variable required, and add them to docs/SETUP.md under Human tasks.

Finish with the phase report, then stop.
```

---

## Prompt 7 — Phase 6: DevSecOps and policy enforcement

```
Phase 6: DevSecOps and policy. Work on branch phase/6-security.

Read AGENTS.md first. Verify Kyverno's current policy API and the Cosign keyless verification syntax against current docs before writing policies.

Deliverables:
- gitops/platform/policies: Kyverno ClusterPolicies, each with clear annotations (title, category, severity, description), rolled out in Audit mode first with a documented switch to Enforce:
  * verify image signatures with Cosign keyless (issuer and subject pinned to our GitLab project and main branch) and require the SBOM attestation
  * disallow `latest` tags and require images from our ECR registry only
  * require resource requests and limits
  * require non-root, read-only root filesystem, no privilege escalation, drop ALL capabilities, seccomp RuntimeDefault
  * disallow privileged containers, hostPath, hostNetwork
  * require standard labels
  * generate default-deny NetworkPolicy for new app namespaces (optional, if it works cleanly)
- Kyverno CLI test suites (`kyverno test`) with passing and failing fixtures for every policy, wired into `make check` and the gitops-validate workflow.
- PolicyReport visibility in Grafana (a simple dashboard or panel using Kyverno metrics).
- docs/security.md: threat model (lightweight STRIDE across CI, registry, cluster, secrets), a supply-chain diagram (Mermaid), a controls table mapping each control to the threat it mitigates and the file that implements it, and a short mapping to the relevant CIS Kubernetes / EKS benchmark areas (only claim what is actually implemented).
- A docs/demo.md section "Security demo": steps to deploy an unsigned image and show it being blocked, deploy a signed one and show it admitted. Leave the output as `TODO(capture)` until a human runs it.
- Optional extension, only if it stays clean: Trivy Operator for in-cluster vulnerability reports.

Validation: `kyverno test`, `kubeconform`, `make check`. Test the policies locally on a kind cluster with Kyverno installed, using sample good and bad manifests, and show the results.

Finish with the phase report, then stop.
```

---

## Prompt 8 — Phase 7: Observability and SLOs

```
Phase 7: Observability and SLOs. Work on branch phase/7-observability.

Read AGENTS.md first.

Deliverables (all as code in gitops/, no manual clicking):
- Grafana dashboards as JSON ConfigMaps loaded by the sidecar: cluster overview, nodes and Karpenter, Argo CD, api RED metrics (rate, errors, duration) with version/rollout awareness, worker queue depth and processing time, Kyverno policy results.
- Define SLOs for the api: availability (e.g. 99.5% over 30 days) and latency (p95 under a target you justify). Implement them as Prometheus recording rules and multi-window, multi-burn-rate alerts (fast burn and slow burn, following the SRE workbook approach). Explain the math in docs/architecture.md.
- Additional alerts: pod crash looping, node not ready, Karpenter provisioning failures, Argo CD app out of sync or degraded, certificate expiry (if cert-manager is enabled), persistent volume filling up, Rollout aborted.
- Every alert carries `severity`, `summary`, `description` and a `runbook_url` annotation pointing to a real file in docs/runbooks/. Write one runbook per alert: symptoms, impact, quick diagnosis commands, likely causes, fixes, escalation.
- Alertmanager routing: a Slack receiver using a webhook from an ExternalSecret (enabled only when configured) and a null fallback receiver so the setup works without Slack.
- Loki: log queries saved in docs (api errors, worker failures, rollout events), and structured log fields that match the app's JSON logs.
- Retention and resource settings sized for a small dev cluster, with the reasoning documented.

Validation: `promtool check rules` and `promtool test rules` with unit tests for the SLO and burn-rate rules, JSON validity of dashboards, `kubeconform`, `make check`. Run the monitoring components on kind to confirm the rules load without errors.

Finish with the phase report, then stop.
```

---

## Prompt 9 — Phase 8: Progressive delivery (canary with automatic rollback)

```
Phase 8: Progressive delivery. Work on branch phase/8-progressive-delivery.

Read AGENTS.md first. Verify the current Argo Rollouts ALB traffic-routing support and syntax against current docs. If ALB traffic routing is not practical in this setup, use replica-weighted canary and record the trade-off in an ADR.

Deliverables:
- Finish the api Rollout: canary steps with traffic weights (for example 10, 25, 50, 100) and pauses, using ALB traffic routing if feasible.
- AnalysisTemplates using Prometheus queries: success rate threshold and p95 latency threshold, with sensible interval, count and failure limits. Automatic abort and rollback when analysis fails.
- A way to demo both outcomes safely:
  * good release: new version is promoted step by step
  * bad release: version with fault injection enabled gets aborted automatically
  Provide scripts/demo-canary-good.sh and scripts/demo-canary-bad.sh (they change the gitops overlay in a branch or PR and print the commands to watch progress), plus `make demo`.
- Argo CD notifications (Slack optional) for sync failed, degraded, rollout aborted.
- docs/demo.md: a 5-minute demo script with exact commands, what to point at on screen, and what the audience should see. Leave outputs as `TODO(capture)`.
- Update the Grafana api dashboard so canary vs stable traffic is visible.

Validation: manifests build and pass kubeconform and policies, rule and template syntax check, and a local kind test of the Rollout with the replica-based strategy if possible. State clearly what could only be verified on the real cluster.

Finish with the phase report, then stop.
```

---

## Prompt 10 — Phase 9 (extension): Resilience, load testing, chaos

```
Phase 9: Resilience. Work on branch phase/9-resilience.

Read AGENTS.md first. Everything here must be safe: experiments are opt-in, scoped to the app-dev namespace or tagged dev resources, and have a documented abort procedure.

Deliverables:
- loadtest/: k6 scripts for smoke, load and spike tests with pass/fail thresholds, a README, and a make target. Document how to prove HPA scaling and Karpenter node scale-out with these tests.
- chaos/: experiments using Chaos Mesh or AWS FIS (pick one, justify in an ADR), at least: kill api pods, node termination or spot interruption simulation, network latency to the database. If FIS, define the experiment templates in Terraform with strict stop conditions.
- Game day template (chaos/gameday-template.md): hypothesis, steady-state metric, injection, expected behaviour, observed behaviour, outcome, fixes, follow-ups. Pre-fill one complete example flow, leaving observed results as `TODO(measure)`.
- Verify and document PodDisruptionBudgets and a node drain procedure.
- Backup and restore: document RDS automated backups and a snapshot-restore test procedure. Add Velero backup of cluster resources to S3 only if it stays clean, otherwise document it as a future improvement.
- Honest DR section in docs/architecture.md: what is built, what is only designed (e.g. multi-region failover), with the design described but clearly labeled as not implemented.

Validation: script syntax, manifest validation, `make check`. Do not execute chaos experiments yourself.

Finish with the phase report, then stop.
```

---

## Prompt 11 — Phase 10 (extension): FinOps

```
Phase 10: FinOps. Work on branch phase/10-finops.

Read AGENTS.md first.

Deliverables:
- Confirm and document cost tagging coverage via `default_tags`, and add a Terraform or CI check that fails on untagged resources where feasible.
- Infracost configuration (infracost.yml or equivalent) with usage assumptions file, wired into PR comments (already in phase 5; refine thresholds, e.g. warn on a cost increase above a set percentage).
- Karpenter tuning: spot-first NodePool with on-demand fallback, consolidation settings, instance-family diversity, and documented limits. Explain interruption handling.
- OpenCost (or Kubecost free tier) as an Argo CD application plus a Grafana dashboard for cost by namespace.
- Dev environment cost savers: `make down` (full teardown with confirmation), a documented "pause" procedure (scale node groups and workloads down) and what it does and does not save.
- scripts/cost_report.py (Python, boto3): reads Cost Explorer data for the project tag and writes a Markdown summary to docs/costs.md. Mention that Cost Explorer API calls are billed per request. It must run without modification once the human supplies AWS credentials.
- docs/costs.md: cost model per component (control plane, nodes, NAT, ALB, RDS, logs, storage) with the formula used, and a table where actual numbers are `TODO(measure)` until real data exists.

Validation: ruff and pytest for the script (mock boto3), `make check`.

Finish with the phase report, then stop.
```

---

## Prompt 12 — Phase 11: Documentation and polish

```
Phase 11: Documentation and polish. Work on branch phase/11-docs.

Read AGENTS.md first, then read the whole repository. Documentation must match the code exactly. If you find a mismatch, fix the docs or the code and tell me which.

Deliverables:
- README.md final version, optimised for a recruiter reading for 60 seconds and an engineer reading for 10 minutes: title and one-line pitch, a "What this demonstrates" section mapped to skills (Terraform, Kubernetes, GitOps, CI/CD, DevSecOps, observability and SRE, FinOps), architecture diagram (Mermaid in the README, plus a note on how to export a PNG into docs/images), the end-to-end flow, feature table, repo map, quickstart for local (kind and docker compose) and for AWS (`make up`), cost and teardown section, a "Results" section that contains only real measurements or clearly marked `TODO(measure)` entries, links to docs, and "What I learned / trade-offs".
- docs/architecture.md: final and complete (network, IAM trust relationships, CI/CD flow, GitOps flow, data flow, security layers, observability, DR), with Mermaid diagrams.
- docs/adr/: index README listing all ADRs.
- docs/runbooks/: index README.
- docs/demo.md: final, with a 5-minute live demo script and a 3-minute video storyboard (shot list with what to show and what to say), plus a list of screenshots the human must capture (Argo CD application tree, Grafana dashboards, canary rollout, policy block, pipeline view, Infracost PR comment, cost report).
- docs/interview-notes.md: for each major component, give what it is, why it was chosen, alternatives and trade-offs, failure modes and how they are handled here, and 3 to 5 likely interview questions with concise answers grounded in this repository. Add a section of 25+ cross-cutting questions (Terraform state and drift, IRSA vs node roles, GitOps vs push CD, canary vs blue-green, secrets management, supply-chain security, SLO math, cost optimisation, incident response).
- CONTRIBUTING.md, SECURITY.md (how to report issues), CHANGELOG.md (Keep a Changelog format), a suggested GitHub repo description, topics and pinned-repo blurb in docs/SETUP.md.
- A consolidated list of every remaining `TODO(measure)` and `TODO(capture)` in docs/SETUP.md under Human tasks, with instructions for each.

Validation: check every relative link and every command in the docs exists (script this: scripts/check-docs.sh), spell-check obvious typos, `make check`.

Finish with the phase report, then stop.
```

---

## Prompt 13 — Phase 12: Final audit

```
Phase 12: Final audit. Work on branch phase/12-audit.

Act as a skeptical senior platform engineer and a security reviewer doing a pre-release review of this repository. Read AGENTS.md, then review everything. Do not make changes until you have produced the audit report, then fix what you can.

Audit areas:
1. Security: secrets in git history or files, IAM over-permissions, trust policy scope, public exposure, policy gaps, image and Action pinning, workflow permissions, anything violating AGENTS.md section 6.
2. Correctness: do Terraform modules, Helm values, Kustomize overlays and CI definitions agree with each other (names, namespaces, role ARNs, variable names, image paths)? List every inconsistency.
3. Reproducibility: could a fresh clone follow docs/SETUP.md and reach a working dev environment? Walk through it step by step and list every missing prerequisite or unclear step.
4. Cost safety: anything that could create unexpected cost, resources left behind after `make down`, missing budgets or tags.
5. Docs honesty: every claim in README and docs checked against the code. List unsupported claims, fake or unmeasured numbers, outdated commands.
6. Quality: dead code, duplicated logic, missing tests, missing validations, flaky or slow checks.
7. Interview readiness: gaps between what the README claims and what interview notes can defend.

Output a table of findings with severity (Blocker, High, Medium, Low), location, evidence and the fix. Then fix every Blocker and High finding, re-run `make check`, and update PROGRESS.md. Leave Medium and Low as a prioritised backlog in docs/BACKLOG.md.

Finish with the phase report, then stop.
```

---

## Helper prompts

### Review prompt (use after any phase, before approving it)

```
Review the work from the last phase as a skeptical senior reviewer. Re-read AGENTS.md, then review the diff on this branch. List problems by severity with file and line, check that nothing violates AGENTS.md sections 5 to 7, check that every claim in the report is true by re-running the relevant commands, and check that docs and ADRs match the code. Do not fix anything yet; report only.
```

### Fix prompt

```
Fix the findings you just reported, highest severity first, one commit per fix with conventional commit messages. Re-run `make check` after the fixes and show the real results. Then update PROGRESS.md and stop.
```

### Resume prompt (new session or lost context)

```
Re-read AGENTS.md, PROGRESS.md, docs/adr/ and the last 30 commits (`git log --oneline -30`). Tell me in 10 lines: which phase we are in, what is finished, what is half-done, and what the next step is. Do not change any files until I confirm.
```

### Unstick prompt (if the agent loops, guesses, or goes off-plan)

```
Stop. You are drifting from the plan. Re-read AGENTS.md sections 5 and 10. List what you were asked to do in this phase, what you have actually completed, and what is left. Do not write code in this reply.
```

---

## Things only you can do (the agent cannot)

- Create the AWS account, enable MFA, never use root, create an admin user or SSO profile, and run the bootstrap and dev `terraform apply` yourself.
- Create the GitHub repo and the GitLab project, set branch protection, create the GitHub environments with required reviewers, and add the secrets and variables the agent lists in docs/SETUP.md.
- Create the AWS Budget e-mail and confirm the subscription.
- Run the demos on the real cluster, capture screenshots and record the video.
- Fill every `TODO(measure)` with real numbers.
- Run `make down` after every session. EKS, NAT gateway and load balancers bill by the hour.
