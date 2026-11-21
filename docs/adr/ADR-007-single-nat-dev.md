# ADR-007: Single NAT gateway in dev

- **Status:** Accepted
- **Date:** 2026-11-21
- **Deciders:** project owner and implementation agent

## Context

A NAT gateway costs roughly $43 per month in `ap-south-1` plus data processing
charges. A highly available setup uses one NAT gateway per availability zone.

## Decision

Use a single NAT gateway in dev (`single_nat_gateway = true`) and one per
availability zone in prod (`single_nat_gateway = false`).

## Alternatives considered

| Alternative | Why it was not chosen |
|---|---|
| One NAT gateway per AZ in every environment | Roughly triples the NAT cost in dev for availability the dev environment does not need |
| No NAT gateway (public subnets only) | Nodes and pods in public subnets can reach the internet directly, but it removes the network isolation that the production design relies on |
| NAT instance instead of NAT gateway | Cheaper but adds an EC2 instance to operate and patch |

## Consequences

- Dev saves roughly two thirds of the NAT cost.
- A single NAT gateway is a single point of failure in dev. This is acceptable
  for a non-production environment and is documented.
- Prod keeps full high availability.
- The `single_nat_gateway` flag is a module input, so the choice is explicit
  in each environment's wiring.

## References

- Amazon VPC pricing: https://aws.amazon.com/vpc/pricing/
