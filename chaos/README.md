# Chaos experiments

Purpose: opt-in fault injections for the local-first platform. Nothing in this
directory is applied automatically, by CI, or by the agent. A human chooses the
target, confirms the command and restores the fault.

## Scope and safety

- Chaos Mesh **2.8.8** is pinned in
  [`gitops/platform/chaos-mesh-applicationset.yaml`](../gitops/platform/chaos-mesh-applicationset.yaml)
  and is installed only on clusters whose Argo CD cluster Secret has
  `platformbox.io/chaos-enabled: "true"`.
- The controller uses namespace filtering. Annotate only the namespaces used by
  an experiment:

  ```bash
  kubectl annotate ns app-dev chaos-mesh.org/inject=enabled --overwrite
  kubectl annotate ns app-data chaos-mesh.org/inject=enabled --overwrite
  ```

- Every experiment has an explicit namespace and label selector. Never remove
  those selectors or retarget an experiment at `kube-system`, `argocd`,
  `monitoring` or a production namespace.
- Abort by deleting the experiment; Chaos Mesh restores the injected fault:

  ```bash
  kubectl delete podchaos api-pod-kill-dev -n app-dev
  kubectl delete networkchaos api-to-postgres-latency-dev -n app-dev
  ```

- For a slow failure, pause first instead of deleting:

  ```bash
  kubectl annotate networkchaos api-to-postgres-latency-dev \
    experiment.chaos-mesh.org/pause=true -n app-dev --overwrite
  kubectl annotate networkchaos api-to-postgres-latency-dev \
    experiment.chaos-mesh.org/pause- -n app-dev
  ```

## Install Chaos Mesh (opt-in)

Register the target cluster in Argo CD, add the label, and let the
ApplicationSet install the pinned chart:

```bash
kubectl label secret <cluster-secret> platformbox.io/chaos-enabled=true
kubectl -n argocd get applications | grep chaos-mesh
```

`kind` uses containerd, so the chart values set
`chaosDaemon.runtime=containerd` and
`socketPath=/run/containerd/containerd.sock`. The controller is kept to one
replica and the dashboard is disabled to limit the local footprint. The network
delay experiment also needs the `NET_SCH_NETEM` kernel module on the node.

## Experiments

| Experiment | File | Scope | Expected behaviour |
|---|---|---|---|
| Kill one API pod | `experiments/api-pod-kill.yaml` | `app-dev`, `app.kubernetes.io/name: api` | Rollout/ReplicaSet replaces the pod; the `maxUnavailable: 1` PDB prevents a second voluntary eviction. |
| Delay API → PostgreSQL | `experiments/postgres-network-delay.yaml` | API pods in `app-dev`, PostgreSQL pods in `app-data` | Requests slow or time out for two minutes; deleting the experiment restores normal latency. |
| Stop a kind worker node | `experiments/kind-node-stop.sh` | containers named `kind-worker*` only | Node becomes `NotReady`; workloads reschedule after the drain/pod-eviction timeout. Restore with `docker start <node>`. |

### Apply the manifests

For `app-dev` (the committed defaults):

```bash
kubectl apply -f chaos/experiments/api-pod-kill.yaml
kubectl apply -f chaos/experiments/postgres-network-delay.yaml
```

For the local `kind` smoke namespace, render the same contracts with `yq`
instead of editing the committed files:

```bash
yq e '(.metadata.namespace = "app-local") | (.spec.selector.namespaces[] = "app-local")' \
  chaos/experiments/api-pod-kill.yaml | kubectl apply -f -
yq e '(.metadata.namespace = "app-local") | (.spec.selector.namespaces[] = "app-local") | (.spec.target.selector.namespaces[] = "app-data")' \
  chaos/experiments/postgres-network-delay.yaml | kubectl apply -f -
```

### Stop a kind worker node

```bash
# Dry run: prints the target and the restore command.
NODE_NAME=kind-worker bash chaos/experiments/kind-node-stop.sh

# Human confirmation required.
NODE_NAME=kind-worker CONFIRM=stop-kind-worker bash chaos/experiments/kind-node-stop.sh
docker start kind-worker
```

## Why no AWSChaos experiment is committed

Chaos Mesh 2.8.8 documents `ec2-stop`, `ec2-restart` and `detach-volume`, but no
spot-interruption action. AWSChaos also requires a Kubernetes Secret with AWS
credentials, which would violate the no-static-credentials rule in `AGENTS.md`.
The kind worker stop is the local node-termination substitute; an EKS spot
interruption drill needs a future IRSA-backed implementation or AWS FIS and is
recorded as a human task, not implemented here. See ADR-028.

## Verification references

- [Chaos Mesh 2.8.8 installation](https://chaos-mesh.org/docs/production-installation-using-helm/)
- [Namespace filtering](https://chaos-mesh.org/docs/configure-enabled-namespace/)
- [PodChaos](https://chaos-mesh.org/docs/simulate-pod-chaos-on-kubernetes/)
- [NetworkChaos](https://chaos-mesh.org/docs/simulate-network-chaos-on-kubernetes/)
- [Clean-up and pause](https://chaos-mesh.org/docs/clean-up-chaos-experiments/)
