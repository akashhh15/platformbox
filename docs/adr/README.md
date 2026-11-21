# Architecture Decision Records

An ADR records a decision that is expensive to reverse or that a reviewer is
likely to question. Each ADR states the context, the decision, the alternatives
considered and the consequences. ADRs are immutable once accepted; supersede
one with a new ADR instead of rewriting history.

| ADR | Title | Status |
|---|---|---|
| [ADR-000](ADR-000-local-first-zero-cost.md) | Local-first, zero-cost execution mode | Accepted |
| [ADR-001](ADR-001-monorepo-github-gitlab-mirror.md) | Monorepo on GitHub, mirrored to GitLab | Accepted |
| [ADR-002](ADR-002-oidc-over-static-credentials.md) | OIDC federation over static credentials | Accepted |
| [ADR-003](ADR-003-gitops-write-back.md) | GitOps write-back from GitLab CI to GitHub | Accepted |
| [ADR-004](ADR-004-local-substitutes.md) | Local substitutes for AWS-specific components | Accepted |
| [ADR-005](ADR-005-wrap-community-modules.md) | Wrapping well-maintained community Terraform modules | Accepted |
| [ADR-006](ADR-006-irsa-over-pod-identity.md) | IRSA over EKS Pod Identity | Accepted |
| [ADR-007](ADR-007-single-nat-dev.md) | Single NAT gateway in dev | Accepted |
| [ADR-008](ADR-008-s3-native-locking.md) | S3 native state locking | Accepted |

Use [template.md](template.md) for a new ADR.
