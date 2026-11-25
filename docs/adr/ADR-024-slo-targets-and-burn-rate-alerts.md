# ADR-024: Provisional API SLOs with multi-window burn-rate alerts

- **Status:** Accepted
- **Date:** 2026-11-25
- **Deciders:** project owner and implementation agent

## Context

Phase 7 needs API SLOs that are expressed as code, testable offline and usable
on both kind and EKS. The API is a small FastAPI service instrumented with
`prometheus-fastapi-instrumentator` 8.1.0. It exposes grouped status labels
(`2xx`, `4xx`, `5xx`) and two request-duration histograms. The low-resolution
histogram has a `0.5` bucket, which is suitable for an SLO threshold; the
high-resolution histogram is better for dashboard percentiles.

No production traffic data exists yet. A latency target cannot be measured from
this repository, and the pinned Prometheus server is 2.55.0 while the local
`promtool` is 3.16.0. Queries therefore need to stay within PromQL syntax that
2.55 supports.

## Decision

1. Availability SLO: **99.5% successful API requests over a rolling 30-day
   window**. A request is a failure when `status="5xx"`. Probes (`/health`,
   `/ready`, `/metrics`) and the opt-in chaos endpoint (`/chaos/fail`) are
   excluded because they are not user traffic.
2. Latency SLO: **at least 95% of the same requests complete within 500 ms**.
   This is a provisional local-demo target, not an observed production number.
   It is marked `TODO(measure)` in the docs and should be revised after the
   Phase 9 k6 load profile produces real data.
3. Both SLOs use recording rules for 5m, 1h, 30m, 6h and 30d windows. The 30d
   rules feed error-budget-remaining panels.
4. Alerts follow the Google SRE Workbook multi-window approach:
   - fast burn: 14.4x the error budget over both 1h and 5m, `for: 2m`,
     severity `critical`;
   - slow burn: 6x over both 6h and 30m, `for: 15m`, severity `warning`.
5. Denominators use `clamp_min(..., 1e-9)` so a low-traffic service reports zero
   burn rather than `NaN`.
6. Recording rules are evaluated by Prometheus 2.55-compatible PromQL. The
   `prometheus-fastapi-instrumentator` high-resolution histogram is used only
   in dashboards; the SLO uses the `le="0.5"` bucket of the low-resolution
   histogram.

## Alternatives considered

- **99.9% availability.** Rejected for a demo with no measured traffic: a
  single deployment mistake would exhaust the budget and make alerts noisy.
- **Using p95 directly as an alert expression.** Rejected because histogram
  quantiles over long windows are expensive and difficult to test. The SLO uses
  the fraction of requests under the threshold, which is a simple ratio.
- **Using `promtool` 3.16-only functions.** Rejected because the deployed
  Prometheus server is 2.55.0. The offline validator checks syntax with 3.16,
  but the rules intentionally avoid newer PromQL features.
- **Counting probe and chaos traffic.** Rejected: a `/metrics` scrape every 30
  seconds would dominate the denominator and hide real user errors.

## Consequences

- Every API SLO alert has a real runbook and is covered by `promtool test rules`.
- The 500 ms latency target must be revisited before it is presented as a
  production commitment.
- A 30-day error budget requires 30 days of Prometheus retention; local
  retention is therefore set to `30d`, with the resource cost documented as a
  starting point rather than a measurement.
- Adding a new error class requires updating both the recording rules and their
  unit tests.
