# ADR-031: Infracost CI comment-file workflow

- **Status:** Accepted
- **Date:** 2026-11-26
- **Deciders:** platform maintainers

## Context

Phase 10 needs a cost diff on pull requests without giving a pricing container
write access to GitHub. The previously pinned
`infracost/actions/diff@a5783eb98adc93aa7a0049fce0abb06fdd30770a` action exposes
no `config-file` or `comment-out-file` input, so it cannot use the repository
`infracost.yml` with our required config path semantics or keep the comment
token out of the scanning process.

## Decision

Run the pinned container
`ghcr.io/infracost/ci@sha256:e7ddb5c9026624456b47ec4208da00ef942ee390b29cb331d648b8c0d8731ee5`
with `INFRACOST_CLI_AUTHENTICATION_TOKEN`, and call:

```bash
infracost-ci diff --base-path base --head-path head --comment-out-file infracost-comment.md
```

A second job downloads the Markdown file, appends the local guardrail verdict
and upserts one PR comment with pinned `actions/github-script`. The stable
marker is `[//]: <> (infracost-comment`, which is the tag emitted by the
Infracost VCS library.

`infracost.yml` uses config version `0.3`. `path` is relative to the working
directory, `terraform.var_files` are relative to the project path, and
`usage_file` is relative to the repository root. CI asserts that all three
paths exist because Infracost silently skips a missing usage file.

## Alternatives considered

| Alternative | Why it was not chosen |
|---|---|
| Keep `infracost/actions/diff` | It cannot consume our repository config file or write the comment to a file, and would require a PR-write token in the action. |
| Let `infracost-ci diff` post the comment | Even with `--comment-out-file` available, the local guardrail verdict must be appended before posting. |
| Use `INFRACOST_API_KEY` | Rejected by Infracost CI v2.1.5; the documented variable is `INFRACOST_CLI_AUTHENTICATION_TOKEN`. |
| Multiple PR comments | A stable marker gives one updatable comment and avoids PR noise. |

## Consequences

- The pricing job needs only `contents: read`; the comment job gets
  `pull-requests: write`.
- Fork pull requests skip the cost job because the token is not available to
  untrusted code.
- No live Infracost result was produced by the agent: no token was available
  and no live pricing request was made.

## References

- [Infracost CI README](https://github.com/infracost/ci/blob/master/README.md)
- [Infracost config file](https://www.infracost.io/docs/features/config_file/)
- [Infracost usage-based resources](https://www.infracost.io/docs/features/usage_based_resources/)
