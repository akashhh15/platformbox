# ADR-026: Replica-weighted canary for Phase 8

- **Status:** Accepted
- **Date:** 2026-11-25
- **Deciders:** platform maintainers

## Context

Phase 8 needs canary steps, Prometheus analysis and automatic rollback. The
production target uses an AWS Load Balancer Controller (ALB), while the default
execution mode is a local `kind` cluster with ingress-nginx (ADR-000, ADR-004).

The current Argo Rollouts documentation confirms that ALB traffic routing is
supported. A Rollout declares `canaryService`, `stableService` and
`trafficRouting.alb.ingress`, and the controller injects an
`alb.ingress.kubernetes.io/actions.<service>` annotation with weighted target
groups. The referenced Ingress backend must use `port.name: use-annotation`.

That integration cannot be demonstrated in the default environment: `kind` has
no ALB, the AWS path is never applied by the agent, and adding ALB-specific
Services and Ingress annotations to every overlay would create a configuration
that can only be rendered, not exercised. Argo Rollouts also supports a basic
canary without a traffic router, where `setWeight` is approximated by the ratio
of canary to stable pods.

## Decision

Use a replica-weighted canary for all overlays. The API Rollout runs four
replicas and declares `setWeight` steps of 10, 25, 50 and 100 with short pauses.
Background analysis starts at step 0 and queries only pods carrying the latest
`rollouts-pod-template-hash`. Two failed measurements abort the rollout.

ALB traffic routing is deliberately not configured in this phase. An ADR is
required before adopting it so the extra Services, Ingress annotations and
traffic-router-specific validation are visible in the design record.

## Alternatives considered

| Alternative | Why it was not chosen |
|---|---|
| ALB weighted target groups in AWS overlays plus NGINX canary routing locally | Technically supported, but the AWS half can never be live-verified here and the two traffic routers would need different Service/Ingress contracts in each overlay. |
| NGINX canary routing everywhere | The production target is ALB, not NGINX; it would validate locally but still leave the AWS path untested. |
| Blue-green with a single traffic switch | Does not provide incremental exposure or per-step analysis, and uses roughly twice the steady-state pods. |
| Rolling update with no steps | Already implemented in ADR-018; it cannot demonstrate progressive delivery or automatic rollback. |

## Consequences

- `setWeight` is best effort. With four replicas, a 10% or 25% step usually maps
  to one canary pod, and 50% maps to two. The dashboard separates series by pod
  hash so the observed split is explicit rather than implied.
- No ingress changes or extra Services are needed, so the local and AWS
  overlays keep the resource identities asserted by `scripts/apps-contract.sh`.
- Four API replicas raise the local demo footprint to roughly four 64 MiB
  requests; this is still local-only and costs $0.
- Exact ALB weights, real ALB target-group health and live Slack notifications
  remain human-verified tasks on an EKS cluster.
- Adopting ALB later will likely need a new ADR and overlay patches for
  `canaryService`, `stableService`, `trafficRouting.alb` and a `use-annotation`
  Ingress backend.

## References

- [ALB traffic routing](https://argo-rollouts.readthedocs.io/en/stable/features/traffic-management/alb/)
- [Canary deployment strategy](https://argo-rollouts.readthedocs.io/en/stable/features/canary/)
- [Background analysis](https://argo-rollouts.readthedocs.io/en/stable/features/analysis/)
- [ADR-018: Canary strategy without steps](ADR-018-canary-without-steps.md)
- [ADR-000: Local-first, zero-cost execution mode](ADR-000-local-first-zero-cost.md)
