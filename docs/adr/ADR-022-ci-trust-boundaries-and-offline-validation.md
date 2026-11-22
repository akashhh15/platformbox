# ADR-022: CI trust boundaries, digest-based signing and offline workflow validation

- **Status:** Accepted
- **Date:** 2026-11-22
- **Deciders:** project owner and implementation agent

## Context

Phase 5 introduces two CI systems with different trust boundaries:

- GitHub Actions validates Terraform and repository policy, plans through a
  read-only OIDC role, applies only from a protected `dev` environment, and
  mirrors `main` to GitLab.
- GitLab CI builds application images, scans them, signs them with Sigstore
  keyless identity, pushes them to ECR and writes the immutable digest back to
  GitHub for Argo CD.

Three non-obvious questions need a recorded answer:

1. How can signing be a separate pipeline stage without signing a mutable tag?
2. How do we prevent a GitOps write-back commit from starting another build?
3. How can the workflows be checked in this environment, where no GitHub or
   GitLab pipeline can actually run?

## Decision

### Sign the digest, not the tag

The GitLab `build` job pushes the image and emits its registry digest. The
`scan` job verifies the digest-based reference with Trivy and generates a
CycloneDX SBOM from the pushed image archive. The `sign` job signs
`$ECR_REGISTRY/$SERVICE@sha256:$DIGEST` with Cosign keyless mode using the
GitLab `SIGSTORE_ID_TOKEN` (`aud: sigstore`) and attaches the SBOM as a
CycloneDX attestation. The `deploy-gitops` job writes only the digest into the
dev overlay.

This keeps the required stage separation while making every downstream action
reference an immutable object. A later tag change cannot invalidate the
signature. `scripts/image-artifacts.sh` normalizes Buildah's `sha256:<hex>`
digest output to a bare 64-character value and the sign job calls its `verify`
mode before Cosign runs, so the signed reference is proven to match the pushed
digest. GitLab's own guidance to build and sign in one job is a defence against
tampering between build and sign; we accept that trade-off because ECR tags
are immutable and the verified digest is carried forward by artifacts.

### Layered loop prevention

A successful write-back commit contains `[skip ci]` and touches only
`gitops/`. The GitHub mirror workflow uses `paths-ignore: ['gitops/**']`, so a
pure GitOps commit is not mirrored. The GitLab workflow rules also require a
change under `apps/`, `.gitlab-ci.yml` or `.trivyignore`. Both mechanisms are
needed because neither CI system interprets the other's path filters.

### Offline validation

`scripts/validate-workflows.sh` is a local quality gate:

- `actionlint` parses every GitHub Actions workflow.
- If `glab ci lint` is installed it is used; otherwise a PyYAML-based
  structural check validates the GitLab stages, job keys, image pin format,
  OIDC audiences and loop-prevention strings.
- A static assertion rejects any `uses:` reference that is not a 40-character
  commit SHA and any AWS access-key-shaped literal.
- A fixture exercises `image-artifacts.sh write` and `verify`, including a
  negative case with an invalid digest.

The script is wired into `make lint`, so `make check` fails before a PR is
opened if a workflow regresses. It does not claim to execute either pipeline.

## Alternatives considered

| Alternative | Why it was not chosen |
|---|---|
| Sign the mutable `:dev` tag | A tag can be repointed; the policy in Phase 6 would verify the wrong object |
| Build and sign in one job | Conflicts with the required scan → sign stage ordering; mitigated as described above |
| Rely only on `[skip ci]` | GitLab commit messages can be reworded on force push; path rules add defence in depth |
| Skip local CI validation | Workflow syntax errors would only be found after pushing a PR |

## Consequences

- Every published image must have a digest emitted by the build job; a job that
  loses the digest artifact fails later stages instead of silently deploying a
  tag.
- The signing identity recorded for Phase 6 is the GitLab project path and
  `main` branch, not a GitHub identity.
- Human reviewers must configure protected variables and environments; the
  repository contains only variable names and no values.
- Local validation checks syntax and contract shape, not live OIDC, registry or
  reviewer behaviour. The phase report lists exactly what the human must test.

## References

- [ADR-002: OIDC over static credentials](ADR-002-oidc-over-static-credentials.md)
- [ADR-003: GitOps write-back](ADR-003-gitops-write-back.md)
- [ADR-014: Machine-editable image tags](ADR-014-kustomize-image-placeholders.md)
- [ADR-021: Buildah over Kaniko](ADR-021-buildah-over-kaniko.md)
- GitLab Sigstore signing examples: <https://docs.gitlab.com/ci/yaml/signing_examples/>
