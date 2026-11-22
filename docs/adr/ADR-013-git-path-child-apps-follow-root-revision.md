# ADR-013: Git-path child Applications follow the root Application's revision

- Status: Accepted
- Date: 2026-11-22

## Context

The root Application follows `phase/3-platform` while the Phase 3 pull request
is open. `scripts/local-up.sh` patches the root Application to the current
branch when that branch exists on `origin`.

Six child Applications are generated from `gitops/platform`. Five are Helm
Applications pinned to chart versions. Only `kyverno-policies` uses a Git
`path`, and it was pinned to `main`. At verification time `main` did not contain
`gitops/platform/kyverno-policies`, so Argo CD reported:

```text
ComparisonError: app path does not exist
```

The Application still showed `Healthy` because it owned no failing resources;
its sync status was `Unknown`. Patching the live Application would be reverted
by the root app's `selfHeal: true`, so the fix has to be committed in Git.

## Decision

`gitops/platform/kyverno-policies-app.yaml` uses
`targetRevision: phase/3-platform`, matching the branch the root Application
follows during Phase 3 review.

After the Phase 3 pull request is merged, the value should be changed to `main`
in a small follow-up commit. The local demo continues to work while the branch
exists on `origin`.

## Alternatives considered

- **Keep `main` and patch the live Application** — rejected because root app
  self-heal reverts the patch and a fresh clone would break again.
- **Use `HEAD`** — rejected because it still resolves to the default branch,
  which does not contain the Phase 3 path until merge.
- **Pin a commit SHA** — rejected because it would require an update after
  every policy edit and would hide later changes from Argo CD.
- **Convert policies to a Helm chart** — rejected as unnecessary scope creep;
  the directory is already validated by `kyverno apply`.

## Consequences

- `kyverno-policies` syncs from the same revision as the root app during the
  Phase 3 review.
- A follow-up commit after merge is required to switch the value back to
  `main`. This is recorded as a human task in `PROGRESS.md`.
- All other child Applications remain pinned to their exact Helm chart
  versions.
