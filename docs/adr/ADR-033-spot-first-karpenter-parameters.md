# ADR-033: Spot-first Karpenter with cluster-supplied parameters

- **Status:** Accepted
- **Date:** 2026-11-26
- **Deciders:** platform maintainers

## Context

Terraform installs the Karpenter controller, IAM roles, interruption queue and
EventBridge rules, but node pools are Kubernetes resources owned by GitOps.
The node IAM role ARN is account-specific and must not be committed. The node
security group and private subnets are discovered by the
`karpenter.sh/discovery` tag whose value is `${project}-${environment}`. No
matching security-group tag existed before Phase 10. Karpenter v1 also requires
an AMI selector; `@latest` would allow untested images into the cluster.

## Decision

Add `node_security_group_tags` in the EKS module so the node security group
carries the same `karpenter.sh/discovery` tag as the private subnets. Export the
Karpenter node role ARN and interruption queue name from each environment for
the human to place on the Argo CD cluster Secret.

Generate one Karpenter Application per registered cluster with an ApplicationSet
that selects `platformbox.io/target: eks`. It reads:

- label `platformbox.io/cluster-name` (the Terraform cluster name),
- label `platformbox.io/environment`,
- annotation `platformbox.io/karpenter-node-role` (the Terraform output).

The Application renders a local Helm chart containing one `EC2NodeClass` and two
`NodePool` resources. Spot has weight 100; on-demand has weight 10 and bounded
limits. Both use `WhenEmptyOrUnderutilized`, a one-minute consolidation delay,
10% disruption budgets and a 336-hour expiry. AMIs are pinned to the fixed
AL2023 alias `al2023@v20240807`; Karpenter resolves that alias to the AMI
matching the control-plane version.

## Alternatives considered

| Alternative | Why it was not chosen |
|---|---|
| Static YAML with an account-specific ARN committed to git | Violates the no-account-ids rule and would break for a second cluster. |
| `@latest` AMI alias | Official Karpenter guidance warns against it outside pre-production. |
| Only spot capacity | Interruption and capacity shortages need a predictable fallback for the demo. |
| Kustomize overlays per cluster | Cannot inject the role ARN from Argo CD cluster metadata without human-edited files in git. |
| One NodePool with both capacity types | Weights can only express preference between NodePools. |

## Consequences

- The human must label/annotate the cluster Secret before the generated
  Application becomes healthy; docs/SETUP.md lists the exact values.
- The local `kind` cluster has no matching Secret, so no Karpenter resources are
  generated locally.
- Live Karpenter scheduling, spot interruption and consolidation were not
  verified by the agent: no EKS cluster or AWS credentials were available.
- The fixed AMI alias must be reviewed when the EKS version changes.

## References

- [Karpenter node pools](https://karpenter.sh/docs/concepts/nodepools/)
- [Karpenter node classes](https://karpenter.sh/docs/concepts/nodeclasses/)
- [Managing AMIs](https://karpenter.sh/docs/tasks/managing-amis/)
- [Argo CD cluster generator](https://argo-cd.readthedocs.io/en/latest/operator-manual/applicationset/Generators-Cluster/)
