# Alert runbooks

Each Prometheus alert in
[`gitops/platform/observability/prometheus-rules.yaml`](../../gitops/platform/observability/prometheus-rules.yaml)
has a `runbook_url` annotation pointing to one file in this directory. Start
with the alert name and severity, then follow the diagnosis steps. Commands are
written for the local `kind` platform; AWS-only alerts say so explicitly.

| Alert | Severity | Runbook |
|---|---|---|
| `PlatformBoxApiAvailabilityFastBurn` | critical | [API availability fast burn](api-availability-fast-burn.md) |
| `PlatformBoxApiAvailabilitySlowBurn` | warning | [API availability slow burn](api-availability-slow-burn.md) |
| `PlatformBoxApiLatencyFastBurn` | critical | [API latency fast burn](api-latency-fast-burn.md) |
| `PlatformBoxApiLatencySlowBurn` | warning | [API latency slow burn](api-latency-slow-burn.md) |
| `PlatformBoxPodCrashLooping` | warning | [Pod crash looping](pod-crashlooping.md) |
| `PlatformBoxNodeNotReady` | critical | [Node not ready](node-not-ready.md) |
| `PlatformBoxKarpenterProvisioningFailure` | warning | [Karpenter provisioning failure](karpenter-provisioning-failure.md) |
| `PlatformBoxArgoCDAppUnhealthy` | warning | [Argo CD app unhealthy](argocd-app-unhealthy.md) |
| `PlatformBoxPersistentVolumeFillingUp` | warning | [Persistent volume filling](persistent-volume-filling.md) |
| `PlatformBoxRolloutAborted` | warning | [Rollout aborted](rollout-aborted.md) |

`PlatformBoxKarpenterProvisioningFailure` has no data on kind because Karpenter
is an AWS-only component ([ADR-004](../adr/ADR-004-local-substitutes.md)). No
certificate-expiry alert exists because cert-manager is not deployed; add one
when TLS is introduced.
