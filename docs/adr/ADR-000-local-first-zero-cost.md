# ADR-000: Local-first, zero-cost execution mode

- **Status:** Accepted
- **Date:** 2026-11-21
- **Deciders:** project owner and implementation agent

## Context

`AGENTS.md` specifies a production-style platform on Amazon EKS, provisioned
with Terraform and delivered with GitOps. That design is the right portfolio
target, but it cannot be run for free:

| Component | Approximate list cost in `ap-south-1` | Basis |
|---|---|---|
| EKS control plane | ~$73/month | $0.10 per cluster-hour |
| NAT gateway | ~$43/month | $0.059 per hour plus data processing |
| Application Load Balancer | ~$16/month before LCUs | $0.0225 per hour plus LCU charges |
| RDS `db.t4g.micro` | ~$15/month plus storage | $0.021 per hour |
| Two `m7g.large` nodes | ~$85/month on demand | $0.0583 per hour each |

These are list-price estimates, not measured bills. AWS Free Tier does not
include EKS, NAT gateways, load balancers or RDS in this shape. The project
owner requires **zero spend**, so the AWS architecture and the zero-cost
requirement conflict. `AGENTS.md` says to stop and ask which one wins; the
owner chose zero cost.

## Decision

The default execution mode is **local-first and zero cost**:

- The primary runtime is a local `kind` cluster on Docker Desktop.
- `make up` and `make down` create and delete that cluster. They never call
  AWS.
- The AWS Terraform in `infra/` remains the production target design. It is
  validated with `terraform fmt`, `terraform validate`, `tflint`, `checkov` and
  `terraform test` using mock providers. It is **never applied** by the agent.
- AWS-specific components have documented local substitutes in
  [ADR-004](ADR-004-local-substitutes.md).
- CI uses free tiers: GitHub Actions for public repositories, GitLab CI free
  tier, GHCR or the GitLab Container Registry, and Cosign keyless signing.
- The optional AWS path is guarded by `make aws-plan` and `make aws-apply`.
  `aws-apply` requires a typed confirmation and is a human-only action.

## Alternatives considered

| Alternative | Why it was not chosen |
|---|---|
| Apply the AWS dev environment for short demos and destroy it | Costs roughly $5–8 per four-hour session; the owner requires $0 |
| Use only AWS Free Tier services | EKS, NAT, ALB and RDS are not free at this scale; replacing them changes the architecture |
| Single free-tier EC2 instance running k3s | Still incurs EBS, Elastic IP and data charges, and diverges further from the EKS target |
| LocalStack | EKS, RDS and ALB are LocalStack Pro features, not free |
| Do not build the platform | Fails the portfolio and learning goals |

## Consequences

**Positive**

- The platform is reproducible by any reviewer at zero cost.
- Iteration is fast and does not require AWS credentials.
- GitOps, policy, observability, supply-chain signing and progressive delivery
  are exercised for real on kind.
- The Terraform code still demonstrates AWS design and is testable with mock
  providers.

**Negative and accepted risks**

- There is no real EKS, IRSA, ALB, Karpenter or RDS evidence. Those parts are
  design-validated only, and the README must say so.
- Some AWS behaviours (IAM propagation, load balancer provisioning, RDS
  failover) cannot be demonstrated locally.
- The local cluster consumes laptop resources; Docker Desktop needs at least
  8 GB of memory for the full stack.
- A reviewer may discount unapplied Terraform. The mitigation is honest
  documentation, mock-provider tests and a working local demo.

## References

- `AGENTS.md`, sections 2, 3, 5 and 11
- [ADR-004: Local substitutes](ADR-004-local-substitutes.md)
- AWS EKS pricing: <https://aws.amazon.com/eks/pricing/>
- Amazon VPC pricing: <https://aws.amazon.com/vpc/pricing/>
- Elastic Load Balancing pricing: <https://aws.amazon.com/elasticloadbalancing/pricing/>
- Amazon RDS for PostgreSQL pricing: <https://aws.amazon.com/rds/postgresql/pricing/>
