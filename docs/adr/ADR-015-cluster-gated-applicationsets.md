# ADR-015: Cluster-gated ApplicationSets with a separate local overlay

- **Status:** Accepted
- **Date:** 2026-11-22
- **Deciders:** project owner and implementation agent

## Context

Phase 4 needs one Argo CD Application per environment namespace, with dev and
staging auto-syncing and prod syncing manually. The same Argo CD instance also
runs on the local kind cluster for the zero-cost demo. A naive list generator
would create three Applications on kind that target a nonexistent EKS cluster,
leaving the local UI full of permanent errors.

Argo CD's cluster generator can only see clusters registered through Secrets.
The default in-cluster registration has no Secret, so a selector on
`argocd.argoproj.io/secret-type: cluster` excludes kind automatically.

## Decision

Use two ApplicationSets under `gitops/platform`:

- `apps-continuous` combines the cluster generator (selector
  `platformbox.io/target: eks`) with a list generator for `dev` and `staging`,
  and sets `automated.prune/selfHeal`.
- `apps-prod` uses the same cluster selector with a list generator for `prod`,
  and deliberately omits `automated`, making prod a manual sync.

Generated Applications use Go templates with `missingkey=error`, a sync wave of
6 (after the Argo Rollouts CRD in wave 5), and
`ServerSideApply=true` / `ClientSideApplyMigration=false` as required by
ADR-011. A human registers the EKS cluster with the label
`platformbox.io/target: eks`; no cluster Secret exists locally, so the
ApplicationSets generate nothing on kind. The local smoke test applies
`gitops/apps/local` and `gitops/apps/local-data` directly instead.

## Alternatives considered

| Alternative | Why it was not chosen |
|---|---|
| List generator with a fixed cluster name | Generates broken Applications locally |
| Ignore differences and let local apps fail | Noisy UI and a misleading demo |
| Three hand-written Applications | No ApplicationSet pattern, harder to add environments |
| One ApplicationSet with per-element templates | Matrix generators explicitly ignore child `template` overrides; sync policies differ by environment |

## Consequences

- The local cluster stays clean and the smoke test remains self-contained.
- Registering the EKS cluster with the required label is a documented human
  task; without it, no environment Applications appear.
- Application names include the normalized cluster name, so adding a second
  matching cluster cannot cause name collisions.
- ApplicationSet resources are still synced by the root app and are validated
  by `kustomize build`; their CRD-level schema is checked with a server dry-run
  during the local smoke test.

## References

- [Argo CD cluster generator](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Cluster/)
- [Argo CD matrix generator](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Matrix/)
- [ADR-011: Argo CD server-side apply](ADR-011-argocd-server-side-apply.md)
- `gitops/platform/apps-applicationset.yaml`
