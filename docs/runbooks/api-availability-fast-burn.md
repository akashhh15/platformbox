# Runbook: PlatformBoxApiAvailabilityFastBurn

- **Alert:** `PlatformBoxApiAvailabilityFastBurn`
- **Severity:** critical
- **SLO:** 99.5% successful API requests over 30 days; error budget 0.5%.

## Symptoms

The 5xx error ratio over 1h and 5m exceeds 14.4x the budget consumption rate.
This is a page-level signal: the remaining 30-day budget would be exhausted in
roughly two days if the rate continued.

## Impact

Users see server errors. The error budget is being consumed quickly and the
release that caused it should be paused or rolled back.

## Quick diagnosis

```bash
kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090
curl -s 'http://localhost:9090/api/v1/query?query=platformbox:slo:api_availability:error_ratio_rate5m'
kubectl -n app-dev get rollout api
kubectl -n app-dev logs -l app.kubernetes.io/name=api --tail=100
kubectl -n app-dev get externalsecrets
```

Deliberate fault injection through `/chaos/fail` is excluded from the SLO. Check
`FAULT_INJECTION_ENABLED` before treating errors as accidental.

## Likely causes

- A bad API release or configuration change.
- Database or Redis dependency failure shown by `/ready` and application logs.
- NetworkPolicy or ingress change blocking dependencies.
- Resource saturation causing timeouts.

## Fixes

1. Stop the current rollout: `kubectl argo rollouts pause api -n app-dev`.
2. Roll back if a previous revision is healthy:
   `kubectl argo rollouts undo api -n app-dev`.
3. Restore the failed dependency or revert the offending configuration.
4. Confirm the 5m and 1h burn ratios return below 14.4x.

## Escalation

If the error persists after rollback, escalate to the platform owner and start
an incident. Record the budget consumed and the exact release that introduced
the regression.
