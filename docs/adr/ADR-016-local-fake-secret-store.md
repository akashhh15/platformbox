# ADR-016: Local fake External Secrets store

- **Status:** Accepted
- **Date:** 2026-11-22
- **Deciders:** project owner and implementation agent

## Context

The application workloads read `DATABASE_URL` and `REDIS_URL` from a Kubernetes
Secret. On the AWS path those Secrets are created by External Secrets Operator
from AWS Secrets Manager (ADR-004). A local smoke test still needs to exercise
the ExternalSecret reconciliation path, not just pre-create a Secret, or it
would prove nothing about the delivery manifests.

The values needed locally are the non-sensitive defaults already committed in
`apps/docker-compose.yml`: user `app`, password `app`, database `app`, and
`redis://redis:6379/0`. They are not real credentials.

## Decision

Install the pinned External Secrets Operator chart locally through Argo CD and
add a namespaced `SecretStore` named `local-fake` in `app-local` using the
provider's `fake` backend. The local overlay patches both ExternalSecrets to
reference this `SecretStore` instead of the AWS `ClusterSecretStore`. The fake
store carries the same non-sensitive values as docker compose.

The AWS overlays are unchanged and continue to reference
`aws-secretsmanager`; no AWS value is ever written to Git.

## Alternatives considered

| Alternative | Why it was not chosen |
|---|---|
| Pre-create a plain Kubernetes Secret locally | Skips ExternalSecret reconciliation; the smoke test would not cover it |
| LocalStack Secrets Manager | Adds an extra service and still needs an ESO provider; ADR-004 rejects unnecessary mocks |
| Commit a real-looking secret | Violates the no-secrets rule without adding value |

## Consequences

- The local demo proves the ExternalSecret → Secret → workload wiring end to
  end without AWS.
- The fake provider is a local-only substitute; rotation, KMS and IRSA are not
  demonstrated locally and are documented as such.
- `gitops/apps/local/secretstore.yaml` is applied only by the smoke script,
  never by the environment ApplicationSets.

## References

- [ADR-004: Local substitutes](ADR-004-local-substitutes.md)
- [External Secrets Operator fake provider](https://external-secrets.io/latest/provider/fake/)
- `gitops/apps/local/secretstore.yaml`
