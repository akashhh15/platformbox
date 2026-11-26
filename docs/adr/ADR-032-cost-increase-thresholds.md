# ADR-032: Cost-increase thresholds

- **Status:** Accepted
- **Date:** 2026-11-26
- **Deciders:** platform maintainers

## Context

A pull request should fail when it materially increases the modelled monthly
bill, but small planned growth must not make routine work impossible. No
historical baseline has been measured in this repository, so absolute dollar
thresholds would be arbitrary.

## Decision

Parse the generated Infracost comment with `scripts/cost_guardrail.py` and emit
GitHub Actions outputs:

- warn when the monthly estimate increases by **10% or more**;
- block when it increases by **25% or more**;
- leave the check `unknown` when no percentage can be parsed, with an explicit
  note in the PR comment rather than a silent pass.

The PR comment always states the thresholds and the verdict. The job fails only
on `blocked=true`. Cloud-side Infracost guardrails, if configured by a human,
remain authoritative and can be stricter.

## Alternatives considered

| Alternative | Why it was not chosen |
|---|---|
| Fixed USD delta | Without a measured baseline it would encode an invented number. |
| Block on any increase | Too noisy for a small platform that is expected to grow. |
| Rely only on Infracost Cloud guardrails | Requires dashboard configuration and credentials that are outside the repository; the local check is deterministic and testable. |
| Parse Terraform JSON directly | Infracost already owns pricing and regional rate data; duplicating it would be error-prone. |

## Consequences

- `scripts/test_cost_guardrail.py` covers warn, block, decrease and unparseable
  comment cases with no network calls.
- Changing thresholds requires updating this ADR, the workflow inputs and the
  PR comment text together.
- A human must confirm the rendered Infracost comment format in a real PR with
  a configured token; the agent did not do this.

## References

- [Infracost guardrails](https://www.infracost.io/docs/infracost_cloud/guardrails/)
