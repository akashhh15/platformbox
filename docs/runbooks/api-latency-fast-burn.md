# Runbook: PlatformBoxApiLatencyFastBurn

- **Alert:** `PlatformBoxApiLatencyFastBurn`
- **Severity:** critical
- **SLO:** at least 95% of API requests complete within 500 ms over 30 days.

## Symptoms

The ratio of requests slower than 500 ms exceeds 14.4x the 5% latency error
budget over 1h and 5m. This is a provisional target until a load test provides
a measured baseline (`TODO(measure)`).

## Impact

Users experience timeouts and slow pages. The latency budget is being consumed
quickly.

## Quick diagnosis

```bash
kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090
curl -s 'http://localhost:9090/api/v1/query?query=platformbox:slo:api_latency:error_ratio_rate5m'
curl -s 'http://localhost:9090/api/v1/query?query=histogram_quantile(0.95,sum by (le,namespace) (rate(http_request_duration_seconds_bucket{job="api"}[5m])))'
kubectl -n app-dev top pods -l app.kubernetes.io/name=api
kubectl -n app-dev describe hpa api
```

## Likely causes

- CPU or memory saturation in the API pods.
- Slow database or Redis calls.
- An expensive new code path or a canary with different performance.

## Fixes

1. Pause or undo the active rollout if latency began after a release.
2. Scale the API with `kubectl -n app-dev scale rollout api --replicas=<n>` or
   adjust the HPA after measurement.
3. Restore dependency performance and verify the 5m ratio falls below 14.4x.

## Escalation

Escalate with a p95 graph and the runbook URL. Do not change the SLO target
during an incident; propose a change in an ADR after measurement.
