# Five-minute progressive delivery demo

Purpose: show the API Rollout promoting a healthy canary step by step and
automatically rolling back a bad canary, using only the local `kind` platform.
Every command below is safe and costs $0. Outputs are intentionally left as
`TODO(capture)` until the human runs the demo on a machine with Docker.

The demo changes a GitOps overlay version label, which changes the pod template
hash and starts a new ReplicaSet. A real release also changes `images.newTag`
through GitLab CI (ADR-014); the local image is reused here so no registry push
is needed.

## Prerequisites

```bash
make up           # kind cluster + Argo CD; confirm when prompted
make local-smoke  # build images, deploy app-local, verify endpoints
make check        # offline validation; should pass before the demo
```

Point the screen at three terminals:

1. rollout watch,
2. traffic generator,
3. Grafana API RED dashboard.

`TODO(capture):` screenshot of `kubectl get applications -n argocd` after
`make local-smoke`.

## 0. Verify the rollout contract (30 seconds)

```bash
bash scripts/apps-contract.sh
bash scripts/progressive-validate.sh
```

Expected: `204 passed, 0 failed` from the app contract (or the current count)
and `Progressive delivery validation passed.` Output: `TODO(capture)`.

## 1. Good release: step-by-step promotion (2 minutes)

Prepare the branch. It edits only `gitops/apps/local/kustomization.yaml` and
commits the change; it does not push or apply anything.

```bash
make demo                  # or: TARGET=dev make demo for the EKS dev overlay
```

The script prints the branch name and the next commands. On kind:

```bash
kubectl apply -k gitops/apps/local
kubectl -n app-local get rollout api --watch
```

In the traffic terminal:

```bash
kubectl -n app-local port-forward svc/api 8080:8000
for i in $(seq 1 120); do
  curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/items
  sleep 1
done
```

If the Rollouts kubectl plugin is installed, use the richer view instead:

```bash
kubectl argo rollouts get rollout api -n app-local --watch
```

What to point at on screen:

- The Rollout status moving through `10% -> 25% -> 50% -> 100%` with a pause
  after each step. `TODO(capture)`.
- Two ReplicaSet hashes during the pauses. `TODO(capture)`.
- The Grafana panel **Request rate by canary/stable ReplicaSet hash**: traffic
  appears under both hashes. `TODO(capture)`.
- The Grafana panel **Canary replica fraction (replica-weighted)**: it rises
  with each step. `TODO(capture)`.

Expected audience takeaway: analysis runs in the background from step 0; because
both Prometheus checks pass, the canary reaches 100% and the old ReplicaSet is
scaled down.

## 2. Bad release: automatic abort and rollback (2 minutes)

Keep the good release deployed, then return Git to the starting branch (do not
re-apply the clean overlay) and prepare the bad branch:

```bash
git checkout <the-branch-you-started-from>
make demo DEMO=bad
kubectl apply -k gitops/apps/local
kubectl -n app-local get rollout api --watch
```

The stable ReplicaSet still runs the good template with
`FAULT_INJECTION_ENABLED=false`. The new canary template has it enabled, so
`/chaos/fail` can inject failures into the canary. In the traffic terminal, send
the opt-in failure endpoint through the shared Service; the analysis filters
responses by canary pod-template hash:

```bash
kubectl -n app-local port-forward svc/api 8080:8000
for i in $(seq 1 60); do
  curl -s -o /dev/null -w '%{http_code}\n' -X POST http://localhost:8080/chaos/fail
  sleep 1
done
```

What to point at on screen:

- `503` responses appearing only after the canary ReplicaSet gets pods.
  `TODO(capture)`.
- The AnalysisRun failing after two measurements (roughly one minute with the
  pinned `interval: 30s`, `failureLimit: 2`). `TODO(capture)`.
- The Rollout phase becoming `Abort` and the stable hash serving all traffic
  again. `TODO(capture)`.
- Alertmanager showing `RolloutAborted` and `RolloutAnalysisFailed`. On kind the
  chart's null receiver discards them; on an opted-in EKS cluster they go to
  Slack through the same receiver. `TODO(capture)`.

Expected audience takeaway: a bad version never reaches 100%, and no human had
to click rollback.

## 3. Grafana view (30 seconds)

```bash
kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80
```

Open `http://localhost:3000`, then Dashboards → PlatformBox / API RED metrics.
Use the default admin credentials from the chart for the local demo.

- Dashboard link and full-screen screenshot: `TODO(capture)`.
- Canary vs stable rate and replica-fraction panels during a pause:
  `TODO(capture)`.

## 4. Notifications and alerts (30 seconds)

```bash
kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-alertmanager 9093:9093
```

Open `http://localhost:9093`. Argo CD notification triggers
(`platformbox-sync-failed`, `platformbox-health-degraded`) and Argo Rollouts
triggers (`on-rollout-aborted`, `on-analysis-run-failed`) post Alertmanager-format
alerts to `/api/v2/alerts`. The default null receiver makes this safe on kind;
Slack is enabled only by the labelled EKS ApplicationSet from ADR-025; the
shared delivery path is recorded in ADR-027.

`TODO(capture):` Alertmanager alert list during the bad demo.

## Cleanup

Delete the demo branches after recording the screenshots:

```bash
git branch --list 'demo/canary-*'
git branch -D <demo-branch>
```

The local workload remains on the stable revision. `make down` removes the whole
kind cluster and everything in it.

## Limitations to state during the demo

- Replica-weighted `setWeight` is best effort. There is no ALB or NGINX traffic
  router, so the percentage shown by Argo Rollouts is a target replica ratio,
  not an exact request split (ADR-026).
- The p95 latency target is provisional at 500 ms (ADR-024).
- No Slack webhook is present locally. Real delivery is a human task on EKS.
- Analysis queries use pod-template-hash labels from the ServiceMonitor, so
  Prometheus must have scraped at least one canary sample before a measurement
  can pass. The `or vector(...)` fallback prevents an empty result from failing
  the rollout.

## References

- [ADR-024: SLO targets and burn-rate alerts](adr/ADR-024-slo-targets-and-burn-rate-alerts.md)
- [ADR-025: Opt-in Slack alert routing](adr/ADR-025-opt-in-slack-alert-routing.md)
- [ADR-026: Replica-weighted canary](adr/ADR-026-replica-weighted-canary.md)
- [ADR-027: Argo notifications via Alertmanager](adr/ADR-027-argo-notifications-via-alertmanager.md)
- [Architecture](architecture.md)
