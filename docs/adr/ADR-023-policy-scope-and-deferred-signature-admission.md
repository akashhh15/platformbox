# ADR-023: Application-only hardening scope and deferred signature admission

- **Status:** Accepted
- **Date:** 2026-11-24
- **Deciders:** project owner and implementation agent

## Context

Phase 6 adds two CEL `ValidatingPolicy` resources: one for restricted container
settings (seccomp, read-only root filesystem, capability drop) and one against
host namespaces, hostPath volumes and privileged containers. Three facts shaped
their scope:

1. `app-data` runs the pinned PostgreSQL image on Pod Security Standards
   `baseline` because it must write its data directory as uid 999 (ADR-017).
   A read-only-root-filesystem rule applied to every `app-*` namespace would
   reject the local database.
2. `app-local` is a disposable kind overlay used by `make local-smoke`. It is
   not a promotion target and is managed by the ApplicationSet gate in
   ADR-015.
3. The GitLab project path and the GitLab OIDC `sub` claim are still unconfirmed
   human values. GitLab defaults `sub` to
   `project_path:{group}/{project}:ref_type:{type}:ref:{branch}`, so a
   signature policy cannot be scoped to a real identity without guessing.

Phase 5 already signs the pushed digest with Cosign keyless, but the live
pipeline has not run and no signed image has been observed. Verified CLI output
shows an `ImageValidatingPolicy` with `validationActions: [Audit]` exits 1 in
`kyverno apply` when the pod uses a mutable tag without a digest, so adding it to
the shared policy directory would break the offline GitOps gate.

## Decision

1. Scope the two new hardening policies to `app-dev`, `app-staging` and
   `app-prod` only. Keep the five baseline policies matching all `app-*`
   namespaces.
2. Do not add an image-signature admission policy in this phase. Record it as a
   human task with an explicit promotion path: add a cluster-gated
   `ImageValidatingPolicy` in `Audit`, observe a real signed digest from the
   GitLab pipeline, scope the attestor `subjectRegExp` to the confirmed project
   and `main`, then promote to `Deny`.
3. Add offline unit tests for all seven policies with pass, fail and skip
   cases, and gate both `make check` and the GitHub `gitops-validate` workflow
   on them.

## Alternatives considered

| Alternative | Why it was not chosen |
|---|---|
| Apply the hardening policies to every `app-*` namespace | Breaks the documented `app-data` baseline exception (ADR-017). |
| Add `NamespacedValidatingPolicy` copies per application namespace | Duplicates seven policies three times and makes drift likely. |
| Add a `Deny` image-signature policy now | Would reject the intentionally unsigned local images and depend on an unconfirmed OIDC subject. |
| Use `Audit` only and call signature admission complete | Misrepresents an audit-only control as enforcement; violates the quality bar. |
| Skip unit tests and rely on `kyverno apply` only | `apply` cannot assert violations; a policy that silently stops denying would pass. |

## Consequences

- The three application namespaces are hardened; the data and local namespaces
  keep their documented exceptions.
- `make policy-test` now fails if any policy stops denying a known-bad pod or
  starts denying a known-good one. The suite was negatively tested by changing
  an expected `fail` to `pass` and observing two failures.
- Image signature admission remains a documented human task in
  `docs/threat-model.md` and `PROGRESS.md`, not an invisible gap.
- A future phase must confirm the GitLab project path and OIDC subject before
  adding the signature policy.

## References

- [ADR-017: baseline PSS for local data](ADR-017-baseline-pss-for-local-data.md)
- [ADR-022: CI trust boundaries and offline validation](ADR-022-ci-trust-boundaries-and-offline-validation.md)
- [Kyverno ImageValidatingPolicy](https://kyverno.io/docs/policy-types/image-validating-policy/)
- [GitLab OIDC token payload](https://docs.gitlab.com/ci/secrets/id_token_authentication/#token-payload)
- `docs/threat-model.md`, `gitops/platform/kyverno-policies/tests/`
