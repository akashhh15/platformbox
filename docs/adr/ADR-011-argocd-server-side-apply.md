# ADR-011: Use server-side apply for all Argo CD Applications

- Status: Accepted
- Date: 2026-11-21

## Context

The local platform syncs Helm charts that install CustomResourceDefinitions,
notably Kyverno 1.20's CEL policy CRDs and kube-prometheus-stack. Argo CD's
default sync method is client-side apply, which writes the full desired
manifest into the `kubectl.kubernetes.io/last-applied-configuration`
annotation. Three Kyverno CRDs are larger than the Kubernetes annotation limit
of 262144 bytes, so Argo CD reported:

```
CustomResourceDefinition.apiextensions.k8s.io "mutatingpolicies.policies.kyverno.io" is invalid:
metadata.annotations: Too long: may not be more than 262144 bytes
```

The CRDs were skipped, the admission controller could not watch
`MutatingPolicy`, and its TLS webhook never became ready. This is a general
Argo CD limitation, not a chart defect.

## Decision

Every Application under `gitops/platform/` sets
`spec.syncPolicy.syncOptions: [CreateNamespace=true, ServerSideApply=true]`.
The option is added once through a Kustomize patch in
`gitops/platform/kustomization.yaml` so all current and future Applications
inherit it. Server-side apply records field ownership in `managedFields`
instead of a large annotation, removing the size limit.

## Alternatives considered

- **`Replace=true`** — documented by Argo CD as another escape hatch, but it
  recreates resources and can cause outages. Rejected.
- **Apply CRDs out of band** — render charts with `--include-crds` and apply
  the CRDs with `kubectl` before the Application syncs. This splits the source
  of truth and adds a bootstrap step, conflicting with ADR-010.
- **Per-resource sync-option annotation** — would require patching every CRD
  inside third-party charts. Rejected as unmaintainable.

## Consequences

- Large CRDs now sync successfully; Kyverno and monitoring can become healthy.
- Argo CD tracks ownership through `managedFields`, which is the Kubernetes
  native mechanism and matches the direction of upstream tooling.
- `Replace=true` must not be combined with this setting; it takes precedence.
- Client-side apply migration is enabled by default in Argo CD 3.6, so
  pre-existing client-side-applied resources are migrated automatically.
