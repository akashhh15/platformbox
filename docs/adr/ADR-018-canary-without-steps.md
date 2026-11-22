# ADR-018: Canary strategy without steps for Phase 4

- **Status:** Accepted
- **Date:** 2026-11-22
- **Deciders:** project owner and implementation agent

## Context

The api workload is an Argo Rollout so Phase 8 can add traffic shifting and
Prometheus analysis without changing the workload kind. Phase 4 only needs the
behaviour of a plain Kubernetes rolling update.

Argo Rollouts v1.7.2 does not expose `spec.strategy.rollingUpdate`; its CRD only
defines `blueGreen` and `canary`. A local smoke test failed with a strict
decoding error when `rollingUpdate` was used. Official documentation states that
a `canary` strategy with no `steps` performs a basic rolling update using
`maxSurge` and `maxUnavailable`.

## Decision

Set `spec.strategy.canary.maxSurge: 1` and
`spec.strategy.canary.maxUnavailable: 0`, with no `steps`. Phase 8 adds steps and
an `AnalysisTemplate` to the same field.

## Alternatives considered

| Alternative | Why it was not chosen |
|---|---|
| Use a Kubernetes Deployment in Phase 4 | Would require changing the workload kind in Phase 8 and would break the HPA target reference |
| Use `blueGreen` | Needs preview/active services and changes traffic behaviour beyond Phase 4 scope |
| Add a trivial `setWeight: 100` step | No operational benefit and would need a promotion gate on every deployment |

## Consequences

- The Rollout validates against the pinned v1.7.2 CRD and the local smoke test
  can apply it.
- Phase 4 gets zero-downtime rolling updates with surge 1 and no unavailable
  replicas.
- No canary analysis or rollback exists until Phase 8; this is explicit in
  `docs/architecture.md`.

## References

- [Argo Rollouts migration guide](https://argo-rollouts.readthedocs.io/en/stable/migrating)
- [Rollout specification](https://argo-rollouts.readthedocs.io/en/stable/features/specification)
- `gitops/apps/base/api/rollout.yaml`
