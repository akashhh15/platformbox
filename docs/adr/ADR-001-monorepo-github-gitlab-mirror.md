# ADR-001: Monorepo on GitHub, mirrored to GitLab

- **Status:** Accepted
- **Date:** 2026-11-21
- **Deciders:** project owner and implementation agent

## Context

The project needs two CI systems to demonstrate both GitHub Actions and GitLab
CI, but it should remain one coherent repository for a reviewer. The
infrastructure code, application code, GitOps manifests and documentation all
change together and should be reviewed together.

## Decision

Keep one monorepo on GitHub as the source of truth. Mirror `main` to a GitLab
project. GitHub Actions owns infrastructure quality, repository security and
the mirror. GitLab CI owns application lint, test, build, scan, SBOM, signing
and the GitOps write-back.

The mirror is one-way (GitHub to GitLab). The write-back from GitLab goes
directly to GitHub, not through the mirror, so Argo CD always watches the
source of truth.

## Alternatives considered

| Alternative | Why it was not chosen |
|---|---|
| GitHub only | Does not demonstrate GitLab CI, which is part of the target stack |
| GitLab only | Loses GitHub's ecosystem, branch protection and the portfolio visibility of a public GitHub repository |
| Two repositories (infra and app) | Duplicates configuration and makes atomic changes harder; a reviewer has to jump between repos |
| GitLab as the source of truth with a GitHub mirror | The portfolio and hiring audience primarily browse GitHub; the mirror direction would be reversed for no benefit |

## Consequences

- One clone, one pull request, one history.
- The mirror needs a token or deploy key with write access to GitLab.
- The mirror workflow must avoid loops. GitOps write-back commits include
  `[skip ci]` and the mirror ignores `gitops/**`.
- GitLab CI variables must be maintained in addition to GitHub secrets.
- Drift between the two remotes is possible if the mirror fails; the mirror
  workflow reports failures and the repository is the source of truth.

## References

- [ADR-003: GitOps write-back](ADR-003-gitops-write-back.md)
- GitHub repository mirroring and GitLab repository mirroring documentation
