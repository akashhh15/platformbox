# ADR-020: Offline contract evidence for the AWS path

- **Status:** Accepted
- **Date:** 2026-11-22
- **Deciders:** project owner and implementation agent

## Context

ADR-000 keeps the AWS path unapplied and ADR-004 documents the local
substitutes. That leaves an honest but weak form of evidence: reviewers can see
that the AWS manifests parse, but not that they express the intended security
and operational contract or that the local overlay still matches the AWS
overlays. LocalStack was considered and rejected again: since 23 March 2026 the
Community edition ended and the free Hobby tier is for non-commercial use and
requires an account and token, while EKS, RDS and ALB remain paid tiers. It
would add a dependency and licensing condition for one secrets path without
solving the underlying gap.

## Decision

Strengthen **offline evidence** instead of emulating AWS:

1. Add `scripts/apps-contract.sh`, wired into `make validate`, which renders
   `dev`, `staging`, `prod` and `local` with Kustomize and asserts a shared
   workload contract (hardening, probes, resources, labels, supporting
   resources, NetworkPolicies, step-less canary) plus the documented
   substitutions (image names, ingress class, secret store kind/name, chaos
   toggle, namespace). It also asserts that all four overlays render the same
   resource identities once the namespace and the local-only store are
   excluded, and that no credential-like value appears in any render.
2. Add `terraform test` files with mock providers for the ECR, budgets and IRSA
   modules, asserting immutability, scanning and KMS encryption, budget limits
   and thresholds, and that the IRSA trust policy is scoped to one namespace
   and service account. Wire them into `make validate` alongside the existing
   bootstrap test.

No new service, account or token is required. ADR-004 remains in force: this
decision changes the strength of the evidence, not the architecture.

## Alternatives considered

| Alternative | Why it was not chosen |
|---|---|
| LocalStack Hobby for Secrets Manager and STS | Free only for non-commercial use, needs an account and token, and does not cover EKS/RDS/ALB/Karpenter |
| Apply short-lived AWS resources | Paid and contradicts ADR-000 |
| Add more prose to the README | Claims without executable checks drift from the code |
| Python + PyYAML contract tests | Adds a dependency where the pinned `yq` binary already parses the renders |

## Consequences

- `make check` fails if an overlay silently drops a workload resource, widens a
  trust policy, uses the wrong secret store or changes an image unexpectedly.
- Substitutions are now executable assertions rather than documentation only.
- The tests still do not prove AWS runtime behaviour (IAM propagation, ALB
  provisioning, RDS failover, spot interruption). Those remain design-validated
  and are called out in `docs/architecture.md`.
- The overlay patches use array indexes such as `env[4]`; the image and chaos
  assertions pin those indexes and will catch an accidental reorder.
