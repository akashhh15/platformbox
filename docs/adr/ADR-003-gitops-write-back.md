# ADR-003: GitOps write-back from GitLab CI to GitHub

- **Status:** Accepted
- **Date:** 2026-11-21
- **Deciders:** project owner and implementation agent

## Context

GitLab CI builds and signs application images. Argo CD watches the GitHub
repository, which is the source of truth for desired state. Something must
update the image reference in Git after a successful build, without giving CI
direct cluster credentials and without creating an infinite pipeline loop.

## Decision

The GitLab `deploy-gitops` job updates the image digest in
`gitops/apps/overlays/dev/kustomization.yaml` and commits it to the GitHub
repository:

1. Build, scan, generate the SBOM, sign and push the image by digest.
2. Clone the GitHub repository with a fine-grained token scoped to this
   repository (`Contents: Read and write`).
3. Run `kustomize edit set image` (or an equivalent, deterministic `yq`
   update) with the new digest.
4. Commit with a Conventional Commit message and `[skip ci]`, for example:
   `chore(gitops): deploy api@sha256:... [skip ci]`.
5. Push to `main` (dev) or open a pull request (staging and prod).
6. Argo CD detects the commit and syncs. It is the only component that applies
   manifests to the cluster.

Loop prevention is layered:

- `[skip ci]` in the commit message.
- The GitHub-to-GitLab mirror ignores `gitops/**`.
- The GitLab pipeline has a rule that does not run build jobs for commits whose
  only changes are under `gitops/`.

Promotion is explicit: dev auto-syncs, staging auto-syncs after dev is healthy,
prod requires a pull request and manual sync.

## Alternatives considered

| Alternative | Why it was not chosen |
|---|---|
| Argo CD Image Updater | Convenient, but hides the write-back mechanism this project is meant to demonstrate and adds another controller to operate |
| CI runs `kubectl apply` | Breaks GitOps, gives CI cluster credentials and leaves drift undetected |
| Separate GitOps repository | Cleaner separation, but doubles repository and credential management for a small project |
| Mutable tags such as `latest` | Not auditable, not reproducible and incompatible with immutable image policy |
| Manual image updates | Error-prone and not automated |

## Consequences

- Git history is the deployment audit trail.
- The write-back token is a high-value secret. It is fine-grained, stored as a
  masked and protected GitLab variable, and rotated on a schedule.
- A failed push leaves the image built but not deployed; the pipeline reports
  it and the job is retryable.
- Concurrent pipelines can race on the same file. The job retries with a fresh
  clone and a rebase before giving up.
- The local path builds images locally and loads them into kind; the same
  write-back flow is exercised with GHCR or a local registry in Phase 5.

## References

- [ADR-001: Monorepo and mirror](ADR-001-monorepo-github-gitlab-mirror.md)
- [ADR-002: OIDC over static credentials](ADR-002-oidc-over-static-credentials.md)
- Argo CD auto-sync documentation: <https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/>
