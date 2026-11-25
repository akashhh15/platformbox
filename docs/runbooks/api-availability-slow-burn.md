# Runbook: PlatformBoxApiAvailabilitySlowBurn

- **Alert:** `PlatformBoxApiAvailabilitySlowBurn`
- **Severity:** warning
- **SLO:** 99.5% successful API requests over 30 days; error budget 0.5%.

## Symptoms

The 5xx error ratio exceeds 6x over both 6h and 30m. This consumes about 5% of
the 30-day budget per day and is a ticket-level, slow-burn signal.

## Impact

Availability is degraded but not immediately exhausting the budget. Left
unfixed, it will become a fast-burn page.

## Quick diagnosis

```bash
kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090
curl -s 'http://localhost:9090/api/v1/query?query=platformbox:slo:api_availability:error_ratio_rate6h'
kubectl -n app-dev logs -l app.kubernetes.io/name=api --tail=200 | grep '"level":"ERROR"'
kubectl -n app-dev describe rollout api
```

Compare the `namespace` labels to find which environment is burning budget.
Confirm the errors are not deliberate `/chaos/fail` requests.

## Likely causes

- A small but persistent dependency error.
- One unhealthy replica receiving traffic.
- A slow memory leak or connection-pool exhaustion.

## Fixes

1. Identify and remove the unhealthy replica or revert the suspect change.
2. Check readiness probes and dependency health.
3. Verify the 30m and 6h burn ratios fall below 6x.

## Escalation

Open a ticket with the affected namespace, start time and release hash. If the
fast-burn alert also fires, switch to the critical runbook.
