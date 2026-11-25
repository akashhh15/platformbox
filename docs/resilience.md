# Resilience, load and recovery

Purpose: describe the Phase 9 resilience evidence and the exact human commands
used to produce it. Everything in the repository is offline-validated; load and
chaos are opt-in and are never run by CI or by the agent.

## Verification

```bash
bash scripts/resilience-validate.sh   # k6 syntax, chaos contracts, docs
make check                            # includes the script above
bash scripts/helm-lint.sh             # renders the pinned Chaos Mesh chart
```

`TODO(measure)` marks every value that needs a real run. No timing, error rate
or reliability number in this document is an invented result.

## k6 profiles

k6 **2.4.0** is pinned in `scripts/tool-versions.env` and installed by
`make tools`. Run the profiles from the repository root:

```bash
make loadtest SCENARIO=smoke   # 1 VU, 30s
make loadtest SCENARIO=load    # ramp 10 → 50, hold 5m, ramp down
make loadtest SCENARIO=spike   # 5 → 100 in 10s, hold 30s, ramp down
BASE_URL=https://<alb-host> make loadtest SCENARIO=smoke
```

Each profile calls `GET /items` and exits non-zero when a threshold fails
(exit code 99 in k6 2.4.0). The smoke and load thresholds use the provisional
ADR-024 SLO values: error rate below 0.5% and p95 below 500 ms. The spike
thresholds are stress guardrails, not SLOs. `TODO(measure):` replace both with
observed baselines and update ADR-024.

| Profile | Shape | Pass condition | Primary use |
|---|---|---|---|
| `smoke.js` | 1 VU / 30s | 0 errors, all checks, p95 < 500 ms | Gate before longer runs |
| `load.js` | 1m ramp, 5m plateau, 1m ramp down | errors < 0.5%, checks > 99%, p95 < 500 ms | HPA scale-up and steady state |
| `spike.js` | 10s ramp to 100 VUs, 30s hold, 30s down | errors < 5%, checks > 95%, p95 < 2 s | Recovery behaviour |

### HPA scaling proof (kind)

HPA needs `metrics.k8s.io`. kind does not install metrics-server by default, so
verify the API before the test:

```bash
kubectl get apiservice v1beta1.metrics.k8s.io
kubectl top pods -n app-dev
```

If the API is absent, a human installs the pinned release and, **on kind only**,
allows the self-signed kubelet certificate:

```bash
curl -fsSLO https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.9.1/components.yaml
echo '3c7f57cdbee0f57fb0259a150e8f6d6cb4f29d72d1aa5dce8803151dd6d4c2a1  components.yaml' | sha256sum -c -
kubectl apply -f components.yaml
kubectl -n kube-system get deploy metrics-server -o jsonpath='{.spec.template.spec.containers[0].args}' \
  | grep -q -- --kubelet-insecure-tls \
  || kubectl -n kube-system patch deployment metrics-server --type=json \
    -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
```

Omit the patch on EKS, where the kubelet serving certificate is signed by the
cluster CA. Then watch the controller while the load profile runs:

```bash
kubectl -n app-dev get hpa api --watch
kubectl -n app-dev get rollout api --watch
make loadtest SCENARIO=load BASE_URL=http://localhost:8080
```

Expected behaviour: CPU rises above the 70% target, HPA adds API replicas up to
the `maxReplicas: 8` ceiling, and replicas settle after the five-minute
stabilisation window. `TODO(measure):` record the peak CPU, replica count and
time to first scale-up.

### Karpenter scale-out proof (EKS, human-run only)

Karpenter is an AWS-only component and is not installed on kind. On the optional
EKS dev cluster, run the same load profile against the ALB URL and watch:

```bash
kubectl get nodeclaim -A --watch
kubectl -n kube-system logs -l app.kubernetes.io/name=karpenter -f
```

`TODO(measure):` record node count before and after, the spot/on-demand split,
consolidation time and whether any pod stayed Pending. Do not run this against
a paid cluster unless the human explicitly approves the cost.

## PodDisruptionBudgets and node drain

`scripts/apps-contract.sh` asserts one PDB for each app in every overlay.

| Workload | Replicas (dev/base) | PDB | Effect |
|---|---|---|---|
| api Rollout | 4 | `maxUnavailable: 1` | At least three API pods stay available during voluntary evictions. |
| worker Deployment | 2 | `maxUnavailable: 1` | One worker may be evicted at a time. |
| frontend Deployment | 2 | `maxUnavailable: 1` | One frontend may be evicted at a time. |

Drain procedure (human-run):

```bash
kubectl get nodes
kubectl cordon <node>
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data --timeout=5m
kubectl -n app-dev get pdb api worker frontend
kubectl uncordon <node>
```

On `kind`, drain only worker nodes; the control-plane node hosts the API server.
On EKS, prefer the managed node group or Karpenter replacement path, but the PDB
check is the same. If a drain stalls, do not use `--force`: check the PDB, add a
replacement node and wait. Local `emptyDir` data is deliberately lost with a
drained pod.

## Chaos experiments

Chaos Mesh 2.8.8 is opt-in through the `platformbox.io/chaos-enabled` cluster
label; see [`chaos/README.md`](../chaos/README.md) for install, namespace
annotations, exact commands and abort paths.

| Experiment | Scope | Abort |
|---|---|---|
| Kill one API pod | `app-dev`, API label selector | `kubectl delete podchaos api-pod-kill-dev -n app-dev` |
| API → PostgreSQL latency | API in `app-dev`, PostgreSQL in `app-data` | `kubectl delete networkchaos api-to-postgres-latency-dev -n app-dev` |
| Stop a kind worker | `kind-worker*` container only | `docker start <node>` |

No experiment is applied by the agent. A completed example with observed fields
left as `TODO(measure)` is in [`chaos/gameday-template.md`](../chaos/gameday-template.md).

## Backup, restore and disaster recovery

### Implemented

- Terraform configures RDS automated backups with
  `backup_retention_period = 7`, encryption, deletion protection, a final
  snapshot, tag copying and PostgreSQL log export. Dev is single-AZ; prod
  requests Multi-AZ through the `multi_az` module variable.
- Git is the source of truth for cluster resources. Argo CD rebuilds them after
  a fresh `make local-up`; `make down` intentionally deletes local state.
- PDBs, HPAs and topology spread constraints limit ordinary node and pod loss.

### Designed, not implemented

- A snapshot/PITR restore drill. A human performs it in a separate dev-only
  identifier so the source database is untouched:

  ```bash
  aws rds describe-db-snapshots \
    --db-instance-identifier platformbox-dev-postgres \
    --query 'DBSnapshots[*].{ID:DBSnapshotIdentifier,Created:SnapshotCreateTime}'

  # Choose a snapshot ID from the output. This creates a new, billable DB.
  aws rds restore-db-instance-from-db-snapshot \
    --db-snapshot-identifier <snapshot-id> \
    --db-instance-identifier platformbox-dev-restore-test \
    --db-instance-class db.t4g.micro \
    --no-deletion-protection
  ```

  Verify the restored instance from a temporary in-cluster client, compare row
  counts with the source, then delete the temporary instance after approval.
  `TODO(measure):` record restore time, row-count result and cleanup time.

- Velero backups of cluster resources to S3. It needs a bucket, IAM and a real
  restore test, so it is future work rather than a claimed capability.
- Multi-AZ failover automation and multi-region failover. Terraform requests
  Multi-AZ for prod but does not automate failover; no region-2 infrastructure
  exists. `TODO(measure):` define RTO/RPO only after a real drill.

### Not available locally

`gitops/apps/local-data/postgres.yaml` uses an `emptyDir` volume, so `make down`
or a node loss removes local data. Prometheus and Loki also have no persistent
volume on kind. These are disposable substitutes (ADR-004), not backups.
