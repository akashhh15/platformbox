# ADR-002: OIDC federation over static credentials

- **Status:** Accepted
- **Date:** 2026-11-21
- **Deciders:** project owner and implementation agent

## Context

CI must authenticate to cloud services and to the container registry without
long-lived secrets in Git. Static AWS access keys and long-lived registry
passwords are easy to leak, hard to rotate and impossible to scope to a branch
or environment.

## Decision

Use OpenID Connect federation for every machine identity:

- GitHub Actions and GitLab CI obtain short-lived AWS credentials through OIDC
  role assumption on the optional AWS path.
- Trust policies are scoped to the specific repository or project, the `main`
  branch or protected tags, and the GitHub `dev` environment where applicable.
- Cosign uses keyless signing through the CI provider's OIDC identity. The
  Kyverno verification policy pins the issuer and subject to this repository.
- Registry authentication uses short-lived CI tokens (`GITHUB_TOKEN`,
  `CI_JOB_TOKEN`) or OIDC, never a stored password.
- The local path needs no cloud credentials at all.

No static AWS access keys are created, stored or documented.

## Alternatives considered

| Alternative | Why it was not chosen |
|---|---|
| IAM user with access keys stored in CI secrets | Long-lived, broad, easy to leak; violates the security baseline |
| Node instance role only | Does not give CI identities; conflates workload and pipeline permissions |
| Self-hosted runner with an instance profile | Adds infrastructure and cost; still lacks branch and environment scoping |
| Long-lived personal access tokens for registries | Rotation burden and broad scope; OIDC or built-in CI tokens are narrower |

## Consequences

- Trust policies are security-critical and must be reviewed like code.
- OIDC subject claims must match the repository path, branch and environment
  exactly; a rename breaks authentication until the trust policy is updated.
- There are no long-lived keys to rotate.
- The local path remains credential-free; the AWS path is optional and
  human-run.

## References

- [ADR-000: Local-first, zero-cost execution](ADR-000-local-first-zero-cost.md)
- GitHub OIDC documentation: <https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect>
- GitLab OIDC documentation: <https://docs.gitlab.com/ee/ci/cloud_services/aws/>
- Sigstore Cosign keyless documentation: <https://docs.sigstore.dev/cosign/signing/overview/>
