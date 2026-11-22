# ADR-021: Buildah over Kaniko and Docker daemon builds in GitLab CI

- **Status:** Accepted
- **Date:** 2026-11-22
- **Deciders:** project owner and implementation agent

## Context

Phase 5 needs to build three application images in GitLab CI. The repository is
demonstrated on GitLab.com shared runners, where a privileged Docker daemon is
not available and mounting the host Docker socket would hand the job root
equivalence on the runner host. The Phase 5 prompt asked us to check whether
Kaniko is still maintained before considering it.

Upstream verification on 2026-11-22:

- The Kaniko repository README now states that the project is archived and no
  longer developed or maintained: <https://github.com/GoogleContainerTools/kaniko>.
- GitLab's official "Use Docker to build Docker images" documentation lists
  Buildah as a Docker alternative that needs no daemon and no privileged mode,
  and recommends the `vfs` storage driver because overlay cannot be stacked on
  overlay: <https://docs.gitlab.com/ci/docker/using_docker_build/#buildah-example>.

## Decision

GitLab CI builds images with **Buildah 1.46.1**, pinned as
`quay.io/buildah/stable:v1.46.1@sha256:72b49c4af6c63850200cc8809d513691d61ceb440358faff305b540c4b9fc038`.

The build job:

1. Sets `STORAGE_DRIVER=vfs` and `BUILDAH_FORMAT=docker`.
2. Authenticates to ECR with short-lived credentials from GitLab OIDC web
   identity (ADR-002). AWS CLI 2.42.1 is downloaded from the official AWS URL
   and verified against its SHA-256 before use.
3. Pushes immutable `$CI_COMMIT_SHORT_SHA-$SERVICE` tags.
4. Writes the pushed digest to a job artifact for the scan, sign and GitOps
   write-back stages.

Build, image scan, SBOM and sign jobs use GitLab's `parallel: matrix` over
`SERVICE: [api, worker, frontend]`, so each service is handled by the same
reviewed job definition instead of three copies.

No static registry credentials, privileged runner, Docker socket or Kaniko
image is used.

## Alternatives considered

| Alternative | Why it was not chosen |
|---|---|
| Kaniko | Upstream repository is archived and unmaintained as of 2026-11-22 |
| Docker-in-Docker | Requires a privileged runner; larger attack surface |
| Docker socket binding | Grants effective root access to the runner host and has cross-job interference |
| Shell executor with Docker group | Same root-equivalence problem as socket binding |

## Consequences

- The `vfs` driver is slower than overlayfs, but the three images are small and
  the jobs need no special runner configuration.
- Buildah runs as the image's default user inside the GitLab executor; the
  pipeline does not request `privileged: true`.
- The AWS CLI bootstrap adds a fixed, checksum-verified download to the build
  and sign jobs.
- Container image builds are not reproducible locally byte-for-byte with the
  CI runner; the digest written to Git is always the digest of the pushed ECR
  artifact, not an estimate.

## References

- [ADR-002: OIDC over static credentials](ADR-002-oidc-over-static-credentials.md)
- [ADR-003: GitOps write-back](ADR-003-gitops-write-back.md)
- `docs/VERSIONS.md` for all image and binary pins
