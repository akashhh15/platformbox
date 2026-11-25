# Load profiles

Purpose: repeatable k6 profiles for the local-first platform. These scripts run
only when a human invokes them; no CI job or agent automatically generates load.

## Prerequisites

- k6 **2.4.0** (`make tools` installs the pinned binary; see `docs/VERSIONS.md`).
- A running platform. For `kind`, `/items` is exposed at
  `http://localhost:8080/items`. For EKS, pass the real URL with
  `BASE_URL=https://<alb-host>`.
- For HPA observations, the cluster must expose `metrics.k8s.io`. See
  `docs/resilience.md` for the pinned metrics-server prerequisite.

## Profiles

| Script | Shape | Pass/fail thresholds | Use |
|---|---|---|---|
| `smoke.js` | 1 VU for 30s | 0 failed requests, all checks pass, p95 < 500 ms | Fast gate before a longer run |
| `load.js` | ramp to 10, hold 50 for 5m, ramp down | error rate < 0.5%, > 99% checks, p95 < 500 ms | HPA scale-up observation |
| `spike.js` | 5 → 100 in 10s, hold 30s, ramp down | error rate < 5%, > 95% checks, p95 < 2 s | Recovery and saturation behaviour |

The 0.5% error rate and 500 ms p95 are the provisional SLO values from
[ADR-024](../docs/adr/ADR-024-slo-targets-and-burn-rate-alerts.md), not measured
results. `TODO(measure):` replace them with observed baselines and update the
ADR. The spike thresholds are stress guardrails, not SLOs.

## Run

```bash
# From the repository root, with the platform already running.
make loadtest SCENARIO=smoke
make loadtest SCENARIO=load BASE_URL=http://localhost:8080
make loadtest SCENARIO=spike
```

A breached threshold makes k6 exit non-zero (exit code **99** in k6 2.4.0), so
the target fails in CI or in a shell script. `abortOnFail` is deliberately not
used: the sustained profile must finish so scale-down can be observed.

## Verification references

- k6 options: <https://grafana.com/docs/k6/latest/using-k6/k6-options/reference/>
- k6 thresholds: <https://grafana.com/docs/k6/latest/using-k6/thresholds/>
- k6 release 2.4.0: <https://github.com/grafana/k6/releases/tag/v2.4.0>
- HPA behaviour: <https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/>
