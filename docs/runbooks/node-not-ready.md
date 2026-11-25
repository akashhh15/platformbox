# Runbook: PlatformBoxNodeNotReady

- **Alert:** `PlatformBoxNodeNotReady`
- **Severity:** critical

## Symptoms

A Kubernetes node reports `Ready=false` for at least five minutes.

## Impact

Pods on the node may be unresponsive; capacity is reduced.

## Quick diagnosis

```bash
kubectl get nodes
kubectl describe node <node>
kubectl get pods -A --field-selector spec.nodeName=<node>
docker ps   # local kind path only
```

For kind, check Docker Desktop health and the kind node container logs. For EKS,
check the managed node group and Karpenter replacement nodes.

## Likely causes

- Docker Desktop or the kind node container stopped locally.
- Kubelet or container runtime failure.
- Disk pressure, memory pressure or network partition.

## Fixes

1. Drain the node if it is still schedulable:
   `kubectl drain <node> --ignore-daemonsets --delete-emptydir-data`.
2. Restore the host/runtime or let Karpenter replace the EKS node.
3. Uncordon only after `Ready=True` and system pods are healthy.

## Escalation

Escalate to the platform owner if more than one node is NotReady or if the
control plane is affected. Do not delete a node until replacement capacity is
available.
