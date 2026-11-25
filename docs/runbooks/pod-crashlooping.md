# Runbook: PlatformBoxPodCrashLooping

- **Alert:** `PlatformBoxPodCrashLooping`
- **Severity:** warning

## Symptoms

A container restarted more than three times in 15 minutes.

## Impact

Replicas may be unavailable, increasing latency and error rate for the affected
service.

## Quick diagnosis

```bash
kubectl get pods -A | grep -E 'CrashLoopBackOff|Error'
kubectl -n app-dev describe pod <pod>
kubectl -n app-dev logs <pod> --previous --tail=100
kubectl -n app-dev get externalsecrets
```

## Likely causes

- Missing or malformed `DATABASE_URL`/`REDIS_URL` from an ExternalSecret.
- Failed readiness or startup probe caused by an unavailable dependency.
- Invalid configuration after a release or Kustomize patch.

## Fixes

1. Restore the failed dependency or fix the secret reference.
2. Roll back the release: `kubectl argo rollouts undo api -n app-dev` or
   `kubectl rollout undo deployment/worker -n app-dev`.
3. Confirm restarts stop and readiness probes pass.

## Escalation

If the same image crashes in every namespace, freeze releases and escalate to
the application owner with the previous-container logs.
