# ADR-029: Backup boundary for Phase 9

- **Status:** Accepted
- **Date:** 2026-11-25
- **Deciders:** platform maintainers

## Context

The platform needs a documented backup and restore story. The AWS dev path
provisions RDS with automated backups, while the default `kind` path uses
in-cluster PostgreSQL backed by an `emptyDir` volume. Argo CD can rebuild
cluster resources from Git, but it does not restore application data or
historical metrics. Adding Velero would need an S3 bucket, IAM permissions, a
backup storage location and restore tests; none of that exists in the
zero-cost local path.

## Decision

Document the implemented boundary instead of adding a backup operator:

- RDS automated backups with a seven-day retention period, encryption,
  final snapshot, deletion protection and snapshot tags are treated as the only
  managed data backup. A human performs a snapshot/PITR restore drill into a
  separate dev-only identifier.
- The `kind` PostgreSQL `emptyDir` volume is disposable: `make down` deletes it
  intentionally. No local backup is promised.
- Argo CD Git state is the source of truth for cluster resources; rebuilding
  `kind` from a fresh clone is the local recovery exercise.
- Velero, cross-region snapshots and multi-region failover are described as
  future work, not implemented. No RTO or RPO number is claimed.

## Alternatives considered

| Alternative | Why it was not chosen |
|---|---|
| Velero to S3 in Phase 9 | Requires AWS storage and IAM, cannot be validated locally at zero cost, and would need a real restore drill before it could be called working. |
| Back up local `emptyDir` PostgreSQL to a host path | Adds statefulness and credentials to the disposable demo without changing the AWS production path. |
| Claim an RTO/RPO | No measured failure data exists; `AGENTS.md` forbids invented reliability figures. |
| Implement multi-region failover | Far outside the Phase 9 scope and not applicable to the local-first default path. |

## Consequences

- `docs/resilience.md` states exactly what is implemented, what is designed and
  what is absent. `docs/architecture.md` has a matching DR section.
- Human tasks include a restore drill, measured timings and a decision on
  Velero. Until then, the platform is honest about single-region, dev-only
  recovery.
- The RDS module now exposes `multi_az`: dev stays single-AZ for cost and prod
  requests Multi-AZ. This is Terraform design evidence only; no AWS apply is
  performed by the agent.

## References

- [RDS module](../../infra/modules/rds/main.tf)
- [Local PostgreSQL manifest](../../gitops/apps/local-data/postgres.yaml)
- [ADR-000: Local-first, zero-cost execution mode](ADR-000-local-first-zero-cost.md)
- [ADR-004: Local substitutes](ADR-004-local-substitutes.md)
