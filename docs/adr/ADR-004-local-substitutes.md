# ADR-004: Local substitutes for AWS-specific components

- **Status:** Accepted
- **Date:** 2026-11-21
- **Deciders:** project owner and implementation agent

## Context

[ADR-000](ADR-000-local-first-zero-cost.md) makes the local kind cluster the
primary runtime. Several components in the AWS design have no free local
equivalent or depend on AWS APIs. The project must still demonstrate the same
platform patterns without pretending the substitutes are identical.

## Decision

Use the following local substitutes and label the differences in the README,
architecture document and demo:

| AWS production component | Local substitute | What is preserved | What is lost |
|---|---|---|---|
| Amazon EKS | `kind` on Docker Desktop | Kubernetes API, namespaces, RBAC, policies, workloads | Managed control plane, EKS add-ons, access entries |
| AWS Load Balancer Controller (ALB) | ingress-nginx | Ingress, path routing, health checks | ALB target groups, AWS WAF, ACM integration |
| Amazon ECR | GHCR or GitLab Container Registry, plus a local registry for kind | Immutable digests, image scanning, pull secrets | ECR repository policies, cross-account access |
| Amazon RDS for PostgreSQL | In-cluster PostgreSQL (StatefulSet or Helm chart) | SQL, migrations, backup/restore exercises | Managed backups, Multi-AZ, parameter groups |
| IRSA | Kubernetes ServiceAccount; no cloud identity locally | Pod identity wiring and RBAC | AWS IAM role assumption from pods |
| Karpenter | HPA and multiple replicas on one kind node | Scaling behaviour of workloads | Node autoscaling, spot interruption handling, consolidation |
| AWS Secrets Manager + External Secrets Operator | Kubernetes Secret for local-only values; External Secrets fake store for the sync path | External secret workflow | AWS secret rotation and KMS |
| CloudWatch | Prometheus and Loki | Metrics, logs, alerting | AWS service metrics and CloudWatch Logs Insights |
| Route 53 + ACM | Local HTTP ingress; optional self-signed certificate | Host-based routing | Public DNS and trusted TLS |
| AWS Budgets + Infracost | Documented cost model; Infracost optional for the AWS path | Cost awareness | Real AWS budget enforcement |
| AWS FIS | Chaos Mesh | Pod, network and stress experiments | AWS-managed fault injection |

The AWS Terraform and Kubernetes manifests are still written, linted and
validated. They are not applied. The local overlays use the substitutes; the
AWS overlays keep the production components.

## Alternatives considered

| Alternative | Why it was not chosen |
|---|---|
| Use AWS for everything | Violates the zero-cost requirement (ADR-000) |
| Use LocalStack for EKS, RDS and ALB | Those services are LocalStack Pro features; not free |
| Mock every AWS component and run nothing | No real evidence; the platform would not be demonstrable |
| Run only docker compose, no Kubernetes | Loses GitOps, policy, rollout and observability evidence |

## Consequences

- The local demo proves the Kubernetes, GitOps, policy, observability and
  supply-chain patterns for real.
- The AWS-specific behaviours remain design-validated only. Documentation and
  interview notes must state this clearly.
- Some manifests are intentionally different between local and AWS overlays;
  the Kustomize structure keeps the differences explicit.
- Reviewers can run the project without an AWS account, which improves
  reproducibility.

## References

- [ADR-000: Local-first, zero-cost execution](ADR-000-local-first-zero-cost.md)
- `AGENTS.md`, sections 2 and 3
