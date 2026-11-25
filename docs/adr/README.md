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
| [ADR-009](ADR-009-cel-based-kyverno-policies.md) | CEL-based Kyverno policies | Accepted |
| [ADR-010](ADR-010-local-platform-bootstrap.md) | Local platform bootstrap through Argo CD | Accepted |
| [ADR-011](ADR-011-argocd-server-side-apply.md) | Server-side apply without client-side migration for Argo CD Applications | Accepted |
| [ADR-012](ADR-012-disable-kyverno-migration-hooks-locally.md) | Disable Kyverno upgrade hooks in the local demo | Accepted |
| [ADR-013](ADR-013-git-path-child-apps-follow-root-revision.md) | Git-path child Applications follow the root revision | Accepted |
| [ADR-014](ADR-014-kustomize-image-placeholders.md) | Machine-editable image tags through Kustomize `images` | Accepted |
| [ADR-015](ADR-015-cluster-gated-applicationsets.md) | Cluster-gated ApplicationSets with a separate local overlay | Accepted |
| [ADR-016](ADR-016-local-fake-secret-store.md) | Local fake External Secrets store | Accepted |
| [ADR-017](ADR-017-baseline-pss-for-local-data.md) | Baseline Pod Security Standard for local data services | Accepted |
| [ADR-018](ADR-018-canary-without-steps.md) | Canary strategy without steps for Phase 4 | Accepted |
| [ADR-019](ADR-019-gate-aws-secret-store-by-cluster.md) | Gate the AWS secret store by target cluster | Accepted |
| [ADR-020](ADR-020-offline-contract-evidence.md) | Offline contract evidence for the AWS path | Accepted |
| [ADR-021](ADR-021-buildah-over-kaniko.md) | Buildah over Kaniko and Docker daemon builds in GitLab CI | Accepted |
| [ADR-022](ADR-022-ci-trust-boundaries-and-offline-validation.md) | CI trust boundaries, digest-based signing and offline workflow validation | Accepted |
| [ADR-023](ADR-023-policy-scope-and-deferred-signature-admission.md) | Application-only hardening scope and deferred signature admission | Accepted |
| [ADR-024](ADR-024-slo-targets-and-burn-rate-alerts.md) | Provisional API SLOs with multi-window burn-rate alerts | Accepted |
| [ADR-025](ADR-025-opt-in-slack-alert-routing.md) | Opt-in Slack alert routing with a null fallback | Accepted |

Use [template.md](template.md) for a new ADR.
