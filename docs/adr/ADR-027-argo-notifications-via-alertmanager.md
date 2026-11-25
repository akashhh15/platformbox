# ADR-027: Route Argo notifications through Alertmanager

- **Status:** Accepted
- **Date:** 2026-11-25
- **Deciders:** platform maintainers

## Context

Phase 8 adds Argo Rollouts events for aborted rollouts and failed analysis runs.
Phase 7 already added Argo CD sync and health events through the same platform.
Slack is deliberately opt-in and backed by a secret that does not exist on
`kind` (ADR-025). Sending notifications directly from both Argo controllers to
Slack would either break the local platform or require placeholder secrets,
which the repository forbids.

Alertmanager is already installed by kube-prometheus-stack. Its default chart
configuration uses a null receiver on `kind`, and a labelled EKS ApplicationSet
generates Slack routing only when an operator supplies the webhook secret.

## Decision

All Argo CD and Argo Rollouts notifications are HTTP POST requests to the
in-cluster Alertmanager service at
`http://monitoring-kube-prometheus-alertmanager.monitoring.svc.cluster.local:9093/api/v2/alerts`.
Each template emits an Alertmanager-format alert array with `alertname`,
`severity`, `summary`, `description` and a runbook link.

Argo CD gets one shared Helm values file, used by `scripts/local-up.sh` (chart
10.18.2) and both Terraform environments (chart 7.0.0). It sends sync-failed
and health-degraded events. Argo Rollouts values live in
`gitops/platform/argo-rollouts.yaml` (chart 2.38.0) and send rollout-aborted
and analysis-run-failed events. Built-in trigger names are declared explicitly
because the chart does not install the upstream `notifications-install.yaml`
ConfigMap.

## Alternatives considered

| Alternative | Why it was not chosen |
|---|---|
| Direct Slack webhook in each Argo chart | Needs a secret on every cluster and breaks the offline local demo. |
| Prometheus rules that scrape Argo controller state | Adds alerting logic in a second place and cannot observe discrete Argo events such as a single sync failure. |
| No notifications; rely on dashboards | Reviewers would have to watch Grafana continuously, and aborted rollouts would not produce an actionable alert. |
| A separate notification controller/service | Extra component and operational burden for a path Alertmanager already provides. |

## Consequences

- Local notification delivery is intentionally a no-op through the null
  receiver. The configuration shape and rendered JSON are validated offline;
  live Slack delivery remains a human task on an opted-in EKS cluster.
- Alert deduplication and routing stay in one place, so adding Slack later does
  not require touching Argo CD or Rollouts configuration.
- The shared Argo CD values file must render with both pinned chart versions;
  `scripts/helm-lint.sh` asserts this in CI.
- Custom Argo CD trigger names avoid overriding the charts' built-in triggers.
  Rollouts' built-in trigger entries are reproduced exactly because the chart
  does not ship them.

## References

- [ADR-025: Opt-in Slack alert routing](ADR-025-opt-in-slack-alert-routing.md)
- [ADR-026: Replica-weighted canary](ADR-026-replica-weighted-canary.md)
- [Alertmanager Alerts API](https://prometheus.io/docs/alerting/latest/alerts_api/)
- [Argo CD notifications](https://argo-cd.readthedocs.io/en/stable/operator-manual/notifications/)
- [Argo Rollouts notifications](https://argo-rollouts.readthedocs.io/en/stable/features/notifications/)
