# ADR-035: Canonical Project tag and Cost Explorer reporting

- **Status:** Accepted
- **Date:** 2026-11-26
- **Deciders:** platform maintainers

## Context

`infracost.yml` and `scripts/cost_report.py` used `platformbox` as a project
name, while Terraform defaults, tfvars examples and resource names use
`cloud-platform-in-a-box`. A Cost Explorer report filtered on the wrong tag
value would silently return zero. Cost Explorer is also a paid API: each
`get_cost_and_usage` request costs USD 0.01 with the primary billing view.

## Decision

Use `cloud-platform-in-a-box` as the canonical `Project` tag value everywhere:
Terraform defaults, tfvars examples, Infracost project names and the cost report
default. `scripts/cost_report.py` filters Cost Explorer on that tag, makes one
request per page, prints the request count and replaces a marked section in
`docs/costs.md`. Cost figures remain `TODO(measure)` until a human runs the
script with real credentials.

Pause and full teardown are documented as separate operations. Pausing scales
workloads to zero but does not stop fixed charges; teardown is a human-run
Terraform destroy and is never executed by the agent.

## Alternatives considered

| Alternative | Why it was not chosen |
|---|---|
| Keep `platformbox` everywhere | Would require renaming Terraform defaults and all resource names, a larger change with no cost benefit. |
| No tag filter | Would report unrelated accounts and services. |
| Store a measured cost snapshot in git | No real measurement exists, and a static number would go stale. |
| Ignore Cost Explorer API cost | The API is billed per request and the project must stay honest about cost. |

## Consequences

- Existing AWS resources tagged with an older value must be retagged by a human
  before the report matches them.
- `docs/costs.md` contains explicit `TODO(measure)` items and request-count
  output rather than invented figures.
- No Cost Explorer call was made by the agent.

## References

- [AWS Cost Explorer pricing](https://aws.amazon.com/aws-cost-management/aws-cost-explorer/pricing/)
- [Cost model](../../costs.md)
