# ADR-014: Machine-editable image tags through Kustomize `images`

- **Status:** Accepted
- **Date:** 2026-11-22
- **Deciders:** project owner and implementation agent

## Context

Phase 5 CI will build, sign and publish an image, then write the new reference
back to Git so Argo CD can deploy it (ADR-003). The write must be a small,
predictable edit to one file per environment. Editing arbitrary lines in a
Deployment would be fragile and would make reviews hard.

Each overlay already pins one image per service through a Kustomize `images:`
entry. Kustomize rewrites every matching image reference in the rendered base,
including the Argo Rollout, without touching application code.

## Decision

Keep three `images:` entries in `gitops/apps/base/kustomization.yaml` and repeat
them in every environment overlay. CI edits only the overlay entry with:

```bash
cd gitops/apps/overlays/dev
kustomize edit set image ghcr.io/akashhh15/platformbox/api:<immutable-tag>
kustomize edit set image ghcr.io/akashhh15/platformbox/worker:<immutable-tag>
kustomize edit set image ghcr.io/akashhh15/platformbox/frontend:<immutable-tag>
```

The command was verified against the pinned Kustomize 5.8.3: it changes
`newTag` only and leaves the other entries untouched. The resulting diff is the
reviewable unit for an image promotion. `latest` is never used and is denied by
the existing Kyverno policy.

## Alternatives considered

| Alternative | Why it was not chosen |
|---|---|
| `sed` on the rendered Deployment | Edits generated output, not the source; breaks the GitOps model |
| Helm values for app images | Adds a second templating system for our own apps; the project uses Kustomize for them |
| Environment variables in the pod spec | Image references cannot come from the pod environment |
| Commit whole rendered manifests | Loses the base/overlay structure and produces unreadable diffs |

## Consequences

- A promotion is a three-line, machine-generated change per overlay.
- Reviewers can see the exact image change in the pull request.
- CI must use the pinned Kustomize binary; `kustomize edit` rewrites file
  formatting, so the repository's yamllint settings must tolerate it (they do).
- The base `newTag: dev` is a placeholder only; no production workload should
  ever be deployed from the base directly.

## References

- [ADR-003: GitOps write-back](ADR-003-gitops-write-back.md)
- `gitops/apps/base/kustomization.yaml`
- `docs/architecture.md`
