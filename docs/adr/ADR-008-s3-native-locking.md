# ADR-008: S3 native state locking

- **Status:** Accepted
- **Date:** 2026-11-21
- **Deciders:** project owner and implementation agent

## Context

Terraform state must be locked to prevent concurrent writes. The traditional
approach uses a DynamoDB table alongside the S3 bucket. Terraform 1.10 added
native S3 locking using conditional writes, which needs no DynamoDB table.

## Decision

Use S3 native locking (`use_lockfile = true` in the S3 backend) on Terraform
1.10 or newer. No DynamoDB table is created.

## Alternatives considered

| Alternative | Why it was not chosen |
|---|---|
| DynamoDB locking | Adds a table to manage, monitor and pay for; unnecessary on Terraform 1.10+ |
| No locking | Unsafe for a shared state bucket; concurrent applies can corrupt state |
| Terraform Cloud / HCP Terraform | Managed and convenient, but it moves state off AWS and adds a dependency on a SaaS product |

## Consequences

- One less resource to create and maintain.
- The state bucket must have versioning enabled, which is already required.
- Older Terraform versions (below 1.10) cannot use this backend configuration.
- The `required_version` constraint in every root module enforces 1.10 or newer.

## References

- Terraform S3 backend: https://developer.hashicorp.com/terraform/language/settings/backends/s3
