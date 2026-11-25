# Runbook: PlatformBoxArgoCDAppUnhealthy

- **Alert:** `PlatformBoxArgoCDAppUnhealthy`
- **Severity:** warning

## Symptoms

An Argo CD Application is `OutOfSync` for 15 minutes or reports `Degraded`.

## Impact

Git is no longer the source of truth for that Application, or a workload is
failing its health check.

## Quick diagnosis

```bash
kubectl -n argocd get applications
kubectl -n argocd get application <app> -o yaml | yq '.status'
kubectl -n argocd logs deploy/argocd-application-controller --tail=200
kubectl -n argocd logs deploy/argocd-repo-server --tail=200
```

Check the Application's Git path and `targetRevision`. Git-path child apps must
follow the root revision while a review branch is active
([ADR-013](../adr/ADR-013-git-path-child-apps-follow-root-revision.md)).

## Likely causes

- Invalid rendered manifest or Helm values.
- Git repository/revision unreachable.
- Manual drift that self-heal has not corrected.
- A workload failing readiness.

## Fixes

1. Fix the manifest in Git, not with `kubectl edit`.
2. If safe, trigger a hard refresh and sync from the Argo CD UI or CLI.
3. Confirm the Application returns to `Synced` and `Healthy`.

## Escalation

If prod is degraded, pause promotion and notify the platform owner. Never force
a sync that would prune resources needed by another Application.
