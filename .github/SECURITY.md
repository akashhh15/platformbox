# Security policy

## Supported versions

This is a portfolio project, not a supported product. Security fixes are applied
to the `main` branch only; older tags and phase branches are not maintained.

## Reporting a vulnerability

Do **not** open a public issue for a suspected vulnerability. Use GitHub's
private vulnerability reporting:

1. Open the repository's **Security** tab.
2. Choose **Report a vulnerability**.
3. Include the affected file or component, reproduction steps, and the impact
   you believe it has.

If private reporting is unavailable, contact the repository owner through the
address in the GitHub profile and ask for a private channel before sharing
details.

This project has no bug bounty and no formal response SLA. Reports are handled
on a best-effort basis; an acknowledgement is normally expected within a week.

## Scope

In scope:

- Committed secrets, credentials or tokens.
- Privilege escalation in CI workflows, IAM trust policies or Kubernetes RBAC.
- Admission-policy bypasses in Kyverno rules.
- Supply-chain issues: unsigned or tampered images, SBOM gaps, dependency
  confusion.
- Container escapes from the application workloads.

Out of scope:

- Findings that require a compromised developer laptop or Docker Desktop.
- Denial of service against a local kind cluster.
- Issues in the optional AWS path that only appear after a human applies it
  without following `docs/SETUP.md`.
- Reports generated only by a scanner without a demonstrated impact.

## Handling secrets

If you find a secret in the repository or its history, do not copy it into an
issue. Report it privately. The owner rotates the credential first and then
rewrites history if needed; deleting the file in a new commit is not enough.

## Security controls in this repository

- No long-lived cloud credentials. CI uses OIDC federation (ADR-002).
- Gitleaks runs in pre-commit and in CI.
- Terraform and manifests are scanned with Checkov, Trivy and TFLint.
- Images are scanned, signed with Cosign keyless and verified by Kyverno before
  admission.
- Workloads run as non-root with a read-only root filesystem, all capabilities
  dropped and `RuntimeDefault` seccomp.
