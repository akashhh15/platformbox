# ADR-005: Wrap well-maintained community Terraform modules

- **Status:** Accepted
- **Date:** 2026-11-21
- **Deciders:** project owner and implementation agent

## Context

The network, EKS and Karpenter modules would each be hundreds of lines of
Terraform if written from scratch. Well-maintained community modules exist for
all three and are used by most production teams.

## Decision

Wrap the community modules `terraform-aws-modules/vpc/aws` and
`terraform-aws-modules/eks/aws` inside our own thin modules. Our modules own
naming, tagging, the Karpenter/ELB subnet tags, IRSA, add-ons and the
environment-specific settings; the community module owns the resource graph.

The Karpenter controller, interruption queue and EventBridge rules are written
directly because no community module covers them well and they are small.

## Alternatives considered

| Alternative | Why it was not chosen |
|---|---|
| Write every resource by hand | Slow, error-prone, and duplicates well-tested community code |
| Call community modules directly from environments | Hides our naming and tagging conventions and makes them hard to change |
| Use a different community EKS module | The `terraform-aws-modules/eks/aws` module is the de facto standard and tracks upstream changes quickly |

## Consequences

- Our modules stay small and readable while still controlling the contract.
- Upstream changes are absorbed by bumping the version pin in one place.
- The wrapper must be reviewed when the upstream module changes its interface.
- `terraform-docs` documents the wrapper variables and outputs, not the upstream ones.

## References

- `terraform-aws-modules/vpc/aws`: https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws
- `terraform-aws-modules/eks/aws`: https://registry.terraform.io/modules/terraform-aws-modules/eks/aws
