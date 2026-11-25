# Runbook: PlatformBoxPersistentVolumeFillingUp

- **Alert:** `PlatformBoxPersistentVolumeFillingUp`
- **Severity:** warning

## Symptoms

A mounted volume has less than 10% free space for at least 10 minutes.

## Impact

Writes, WAL growth or log ingestion can fail once the volume is full.

## Quick diagnosis

```bash
kubectl get pvc -A
kubectl describe pvc <pvc> -n <namespace>
kubectl -n monitoring get pvc
kubectl -n app-data exec deploy/postgres -- df -h /var/lib/postgresql/data
```

## Likely causes

- Prometheus retention or Loki ingestion grew beyond the dev sizing.
- A runaway log stream or application writing to the container filesystem.
- Database WAL not being reclaimed.

## Fixes

1. Remove unneeded data through the application, not by deleting PVC objects.
2. Lower retention only after checking SLO and incident needs; the API SLO uses
   a 30-day window.
3. Increase the PVC size if the platform owner approves the storage change.

## Escalation

Escalate before the volume reaches 5% free. On EKS, storage changes may cost
money and must be made by the human operator.
