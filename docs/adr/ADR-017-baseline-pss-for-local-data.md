# ADR-017: Baseline Pod Security Standard for local data services

- **Status:** Accepted
- **Date:** 2026-11-22
- **Deciders:** project owner and implementation agent

## Context

All application namespaces use Pod Security Standards `restricted`. The local
substitutes for RDS and ElastiCache are real PostgreSQL and Redis containers
(ADR-004). The pinned PostgreSQL image initialises its data directory as uid
999 and needs write access to it; forcing `restricted` on that StatefulSet
would either break startup or require an upstream image fork.

These containers never hold real data and exist only inside the disposable kind
cluster. The application namespaces that consume them remain `restricted`.

## Decision

Set `app-data` to `baseline` for enforce, audit and warn. Keep the workload
hardened where it is compatible: non-root, no privilege escalation, dropped
capabilities and `RuntimeDefault` seccomp. Redis additionally uses a read-only
root filesystem. Explain the exception in the namespace manifest and in the
architecture document.

## Alternatives considered

| Alternative | Why it was not chosen |
|---|---|
| Build a custom restricted-compliant Postgres image | Extra maintenance and a divergence from the pinned upstream image |
| Use `emptyDir` with a writable hostPath workaround | Still conflicts with restricted volume rules and weakens the demo |
| Put data services in a namespace outside `app-*` | Kyverno policies would stop covering them; the exception would be less visible |

## Consequences

- The exception is narrow, explicit and local only.
- The five basic Kyverno policies still pass for the local data pods; the
  validation script checks them alongside the application pods.
- Reviewers can see the difference between a deliberate platform exception and
  an accidental relaxed namespace.

## References

- [ADR-004: Local substitutes](ADR-004-local-substitutes.md)
- `gitops/apps/local-data/namespace.yaml`
- `docs/architecture.md`
