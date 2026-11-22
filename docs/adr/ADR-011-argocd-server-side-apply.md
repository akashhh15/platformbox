# ADR-011: Use server-side apply without client-side migration for Argo CD Applications

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

Enabling `ServerSideApply=true` alone did not fix the sync on Argo CD 3.6.2.
Version 3.5 introduced client-side apply migration, which patches an existing
resource's `managedFields` before the server-side apply. For these CRDs Argo
CD still attempted that migration as a client-side patch and hit the same
annotation limit. This is tracked upstream as
[argoproj/argo-cd#28421](https://github.com/argoproj/argo-cd/issues/28421).
The documented escape hatch `Replace=true` also failed because Argo CD tried
to patch the oversized annotation before replacing the resource.

## Decision

Every Application under `gitops/platform/` sets:

```yaml
spec:
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
      - ClientSideApplyMigration=false
```

The options are added once through a Kustomize patch in
`gitops/platform/kustomization.yaml` so all current and future Applications
inherit them. Server-side apply records field ownership in `managedFields`
instead of a large annotation, removing the size limit. Disabling migration
prevents the 3.5+ regression from reintroducing a client-side patch for these
CRDs.

## Alternatives considered

- **`ServerSideApply=true` only** — expected to be sufficient, but failed on
  Argo CD 3.6.2 with the same annotation error. Rejected after live testing.
- **`Replace=true`** — documented by Argo CD as another escape hatch, but it
  also performed a patch first and failed. It can recreate resources and cause
  outages. Rejected.
- **Apply CRDs out of band** — render charts with `--include-crds` and apply
  the CRDs with `kubectl` before the Application syncs. This splits the source
  of truth and adds a bootstrap step, conflicting with ADR-010. Rejected.
- **Pin Argo CD 3.4.x** — the last release line before the regression works,
  but downgrading a security-sensitive component to avoid a documented option
  is less desirable than using the supported mitigation. Rejected.
- **Per-resource sync-option annotation** — would require patching every CRD
  inside third-party charts. Rejected as unmaintainable.

## Consequences

- Large CRDs now sync successfully from Git on a fresh cluster; Kyverno and
  monitoring can become healthy without manual intervention.
- Argo CD tracks ownership through `managedFields`, which is the Kubernetes
  native mechanism and matches the direction of upstream tooling.
- Client-side to server-side migration is disabled for these Applications.
  This is safe for a disposable local cluster created from scratch by
  `make local-up`; on a long-lived cluster, existing client-side-applied
  resources should be migrated deliberately before enabling this option.
- `Replace=true` must not be combined with this setting; it takes precedence.
- When the upstream fix is released, the `ClientSideApplyMigration=false`
  option can be removed after verifying a clean sync.
