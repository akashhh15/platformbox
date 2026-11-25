# Runbook: PlatformBoxApiLatencySlowBurn

- **Alert:** `PlatformBoxApiLatencySlowBurn`
- **Severity:** warning
- **SLO:** at least 95% of API requests complete within 500 ms over 30 days.

## Symptoms

The slow-request ratio exceeds 6x over 6h and 30m. The latency budget is being
consumed steadily rather than in a single incident.

## Impact

Latency is above the agreed objective but not yet at page level.

## Quick diagnosis

```bash
kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090
curl -s 'http://localhost:9090/api/v1/query?query=platformbox:slo:api_latency:error_ratio_rate6h'
kubectl -n app-dev get hpa api
kubectl -n app-dev logs -l app.kubernetes.io/name=api --tail=200 | grep -i slow
```

Check whether a single pod or version is slower by using the
`app_kubernetes_io_version` and `rollouts_pod_template_hash` labels in the API
RED dashboard.

## Likely causes

- Gradual load growth without a matching HPA change.
- A dependency that is slowing under sustained traffic.
- A canary that is marginally slower than the stable revision.

## Fixes

1. Correlate with deployment events and dependency latency.
2. Scale or revert the slowest revision.
3. Confirm both burn windows fall below 6x.

## Escalation

Open a performance ticket and attach the p95 panel and affected version label.
Use the k6 load test from Phase 9 to replace the provisional 500 ms target
with a measured value.
