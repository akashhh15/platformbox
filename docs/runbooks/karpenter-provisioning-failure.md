# Runbook: PlatformBoxKarpenterProvisioningFailure

- **Alert:** `PlatformBoxKarpenterProvisioningFailure`
- **Severity:** warning
- **Scope:** EKS only. kind uses HPA ([ADR-004](../adr/ADR-004-local-substitutes.md)).

## Symptoms

Karpenter reports unschedulable pods or failed node launches. The alert has no
series on kind, which is expected.

## Impact

Pods remain pending and the application has no extra capacity. On AWS this can
also mean spend is not being used effectively.

## Quick diagnosis

```bash
kubectl -n karpenter logs deploy/karpenter --tail=200
kubectl get nodepools
kubectl get ec2nodeclasses
kubectl get pods -A | grep Pending
kubectl describe pod <pending-pod> -n <namespace>
```

## Likely causes

- EC2 capacity, quota or IAM/IRSA problem.
- Invalid `NodePool` or `EC2NodeClass` constraints.
- Subnet/security-group tags missing for Karpenter discovery.

## Fixes

1. Correct the invalid NodePool/EC2NodeClass constraint or IAM permission.
2. Verify subnet and security-group discovery tags.
3. Confirm a node joins and the pending pod becomes Running.

## Escalation

Escalate to the AWS account owner for quota changes. AWS changes require the
human operator; the agent never applies them.
