# ADR-006: IRSA over EKS Pod Identity

- **Status:** Accepted
- **Date:** 2026-11-21
- **Deciders:** project owner and implementation agent

## Context

Pods need AWS credentials. Two mechanisms exist on EKS: IRSA (IAM Roles for
Service Accounts, via an OIDC provider on the cluster) and EKS Pod Identity
(a newer AWS feature that does not need an OIDC provider).

## Decision

Use IRSA. The reusable `infra/modules/irsa` module creates an IAM role whose
trust policy is scoped to a specific namespace and service account name.

## Alternatives considered

| Alternative | Why it was not chosen |
|---|---|
| EKS Pod Identity | Simpler and avoids the OIDC provider, but it is newer, requires the Pod Identity agent add-on, and is less widely documented. The community EKS module and most third-party charts assume IRSA. |
| Node instance role for all pods | No per-pod isolation; a compromised pod gets the node's permissions. |
| Static credentials in Secrets Manager | Long-lived, hard to rotate, and violates the security baseline. |

## Consequences

- One OIDC provider per cluster, managed by the EKS module.
- Every workload that needs AWS access gets its own role and service account.
- Pod Identity can be adopted later by replacing the trust policy; the module
  interface (role ARN output) stays the same.
- The local path uses plain Kubernetes ServiceAccounts with no cloud identity.

## References

- IRSA documentation: https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html
- EKS Pod Identity: https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html
