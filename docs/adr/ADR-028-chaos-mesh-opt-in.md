# ADR-028: Opt-in Chaos Mesh with a kind node-stop substitute

- **Status:** Accepted
- **Date:** 2026-11-25
- **Deciders:** platform maintainers

## Context

Phase 9 needs three fault injections: kill an API pod, terminate a node or
simulate a spot interruption, and add latency to the database path. ADR-004
already names Chaos Mesh as the local substitute for AWS FIS. The default path
must stay on `kind`, cost nothing and never require the agent to touch AWS.

Chaos Mesh 2.8.8 has `PodChaos` and `NetworkChaos`, but its official CRD list
has no `NodeChaos`. Its `AWSChaos` supports `ec2-stop`, `ec2-restart` and
`detach-volume`, not a documented spot-interruption action, and needs a
Kubernetes Secret with AWS credentials. Committing such a secret or a manifest
that assumes one would break the no-static-credentials rule. Chaosd host
shutdown is also not auto-recoverable and is not exposed through
`PhysicalMachineChaos`.

## Decision

Use Chaos Mesh 2.8.8 for pod and network faults. Install it through a
cluster-gated Argo CD ApplicationSet that requires
`platformbox.io/chaos-enabled: "true"`; `kind` therefore stays lightweight by
default. Experiments are committed under `chaos/experiments/` with explicit
namespaces and label selectors, and are never applied by CI or by the agent.

For node termination, provide a separate kind-only script that stops a running
`kind-worker*` container after an explicit `CONFIRM=stop-kind-worker`. It checks
the kind role label and prints the `docker start` restore command. No AWSChaos
manifest is committed.

## Alternatives considered

| Alternative | Why it was not chosen |
|---|---|
| AWS FIS | Needs a paid AWS account and experiment templates; it cannot be exercised in the default zero-cost path. |
| Chaos Mesh AWSChaos `ec2-stop` | Requires static AWS credentials in a Kubernetes Secret and does not model spot interruption. |
| Chaosd host shutdown through PhysicalMachineChaos | Not exposed as a recoverable `PhysicalMachineChaos` action; shutdown cannot be reversed by Chaosd. |
| StressChaos as a node failure | Simulates resource pressure, not node loss, so it does not exercise PDB eviction and rescheduling. |
| Install Chaos Mesh on every cluster | Adds controllers, webhooks and a daemon set to the default local demo without consent. |

## Consequences

- The two Chaos Mesh experiments are declarative, namespace-scoped and
  validated offline. The node-stop experiment is imperative and works only on
  disposable `kind` workers.
- A human must label the cluster Secret, annotate `app-dev`/`app-data`, apply
  the experiments and restore faults. `chaos/README.md` and
  `chaos/gameday-template.md` document every command and abort path.
- EKS spot interruption remains designed but not implemented. A future ADR must
  choose IRSA-backed Chaos Mesh AWSChaos or AWS FIS before it is added.
- No AWS resource, credential or payment method is required for Phase 9.

## References

- [Chaos Mesh 2.8.8 installation](https://chaos-mesh.org/docs/production-installation-using-helm/)
- [Chaos Mesh supported releases](https://chaos-mesh.org/supported-releases/)
- [Namespace filtering](https://chaos-mesh.org/docs/configure-enabled-namespace/)
- [PodChaos](https://chaos-mesh.org/docs/simulate-pod-chaos-on-kubernetes/)
- [NetworkChaos](https://chaos-mesh.org/docs/simulate-network-chaos-on-kubernetes/)
- [AWSChaos](https://chaos-mesh.org/docs/simulate-aws-chaos/)
- [ADR-004: Local substitutes](ADR-004-local-substitutes.md)
