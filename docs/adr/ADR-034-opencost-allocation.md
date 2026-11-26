# ADR-034: OpenCost for namespace allocation

- **Status:** Accepted
- **Date:** 2026-11-26
- **Deciders:** platform maintainers

## Context

Cost Explorer reports the bill by AWS service but cannot explain which
Kubernetes namespace consumed the spend. The platform already runs Prometheus
and Grafana, so a cluster-level cost signal can be added without another
external service. No real billing month has been observed, and `AGENTS.md`
forbids invented cost figures.

## Decision

Deploy OpenCost chart `2.5.35` (app `1.121.5`) as an Argo CD Application in the
`opencost` namespace. Enable its `ServiceMonitor` with `release: monitoring` so
the existing Prometheus scrapes it. Disable the chart's plugin installer
because its default image is unpinned `curlimages/curl:latest`. Pin both
OpenCost container images by digest.

Add a Grafana dashboard that computes namespace allocation from
`container_cpu_allocation`, `container_memory_allocation_bytes`,
`node_cpu_hourly_cost` and `node_ram_hourly_cost`, joining on the `node` label.
The dashboard explicitly excludes idle and unallocated cost from namespace
totals and marks a `TODO(measure)` comparison against Cost Explorer.

## Alternatives considered

| Alternative | Why it was not chosen |
|---|---|
| Kubecost commercial offering | Adds licensing and a second observability stack; not needed for a portfolio demo. |
| Custom exporter from AWS CUR | Requires a data pipeline, Athena and a bucket; far more moving parts. |
| Divide the total bill by namespace count | Produces misleading numbers and invents an allocation model. |
| Use OpenCost cloud-cost integration | Needs credentials and cloud integration configuration; allocation metrics work without it. |

## Consequences

- The chart images and archive digest are recorded in docs/VERSIONS.md and
  verified by `scripts/helm-lint.sh` when network access is available.
- OpenCost values render locally from the exact Application manifest, so the
  committed values are the ones CI templates.
- The dashboard is an allocation view, not a chargeback or invoice source.
- Live OpenCost metrics were not verified by the agent: no running cluster was
  available.

## References

- [OpenCost Helm chart](https://github.com/opencost/opencost-helm-chart)
- [OpenCost metrics](https://opencost.io/docs/integrations/metrics)
