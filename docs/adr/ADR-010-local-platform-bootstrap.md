# ADR-010: Local platform bootstrap through Argo CD

- **Status:** Accepted
- **Date:** 2026-11-21
- **Deciders:** project owner and implementation agent

## Context

Phase 3 must stand up a local platform on `kind` with zero AWS spend. The
platform components are ingress-nginx, Kyverno, kube-prometheus-stack, Loki and
Argo Rollouts. The repository already follows an app-of-apps GitOps design, so
the local path should not introduce a second deployment mechanism that would
drift from the Git state.

Two concrete problems appeared while implementing the first draft:

1. ingress-nginx was installed twice: once with `kubectl apply` of the
   kind-specific manifest in `local-up.sh`, and once by an Argo CD Application.
   Two controllers would fight over the same resources.
2. The root Argo CD Application pointed at `gitops/bootstrap`, the directory
   that contains the root Application itself. That makes the app manage itself
   instead of its children.

## Decision

Bootstrap only the irreducible minimum imperatively:

1. `kind create cluster` with `kind-config.yaml` (ports 80/443 and the
   `ingress-ready=true` label).
2. Helm install Argo CD into `argocd`.
3. Apply the two `AppProject` resources from `gitops/projects`.
4. Apply the root `Application` from `gitops/bootstrap/root-app.yaml`.

The root Application's source path is `gitops/platform`, which contains a
Kustomization of the six child Applications. Sync waves order them:
ingress (0), Kyverno (1), policies (2), monitoring (3), logging (4), rollouts
(5). All platform components are therefore GitOps-managed; `local-up.sh` never
installs them directly.

ingress-nginx uses `hostNetwork: true` on the labelled control-plane node so
that kind's host port mappings reach the controller. AppProjects stay outside
Argo CD's root app because they are bootstrap RBAC boundaries, not workloads.

## Alternatives considered

| Alternative | Why it was not chosen |
|---|---|
| Keep the direct kind ingress manifest in `local-up.sh` | Two sources of truth; Argo CD would prune or overwrite it on the first sync. |
| Point the root app at `gitops/bootstrap` and remove its own manifest from that directory | The root Application must exist somewhere; keeping it in its own directory is clearer and the offline Kustomize validation still works. |
| Use Helm directly for every component and skip Argo CD locally | Would not exercise the GitOps path the project is meant to demonstrate. |
| Use `helm template` output committed to git instead of chart references | Loses upgradeability and adds generated files to review. |

## Consequences

- `make local-up` is short and idempotent; `make local-down` removes the whole
  cluster, so no local state survives.
- Argo CD needs the child manifests on the `main` branch. Until the Phase 3
  pull request is merged, the root Application will report that the source
  path is missing. This is expected and documented in `docs/SETUP.md`.
- The only credential in the platform charts is the local Grafana demo
  password, which is intentionally public because it never leaves kind.
- Chart versions are pinned in `gitops/platform/*.yaml` and recorded in
  `docs/VERSIONS.md`.

## References

- [ADR-004: Local substitutes](ADR-004-local-substitutes.md)
- `scripts/local-up.sh`, `gitops/bootstrap/root-app.yaml`, `gitops/platform/`
- https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/
