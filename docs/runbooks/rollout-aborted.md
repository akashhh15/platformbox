# Runbook: Rollout aborted

- **Alerts:** `PlatformBoxRolloutAborted`, `RolloutAborted`, `RolloutAnalysisFailed`
- **Severity:** warning

## Symptoms

An Argo Rollout has aborted, its Prometheus analysis failed, or Alertmanager
received a `RolloutAborted`/`RolloutAnalysisFailed` notification from Argo
Rollouts. A bad canary is automatically returned to the stable ReplicaSet.

## Impact

The new version was not promoted. Traffic should remain on the stable ReplicaSet.

## Quick diagnosis

```bash
kubectl argo rollouts get rollout api -n app-dev
kubectl argo rollouts history api -n app-dev
kubectl -n argo-rollouts logs deploy/argo-rollouts --tail=200
kubectl -n app-dev describe rollout api
# Local demo namespace: replace app-dev with app-local in the commands above.
```

## Likely causes

- Failed canary analysis or probe.
- Bad image digest brought in by the GitOps write-back.
- Missing ReplicaSet, insufficient capacity or controller RBAC problem.

## Fixes

1. Confirm stable traffic is healthy and no canary pods receive traffic.
2. Fix the image or configuration in Git, then retry the rollout.
3. Use `kubectl argo rollouts promote api -n app-dev` only after the root cause
   is fixed.

## Escalation

Attach the Rollouts status event, image digest and analysis result to the
release ticket. Do not bypass analysis in prod without an approved exception.
