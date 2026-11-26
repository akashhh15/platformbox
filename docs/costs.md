# Cost model

Purpose: explain what drives AWS spend, what is estimated automatically, and how to
reduce or stop it. Every number in this file is a formula or an explicit
`TODO(measure)` item; no observed cost is claimed. The local `kind` path costs
`USD 0` because it creates no AWS resources (ADR-000).

## What the agent runs

The agent never calls a mutating AWS API and never applies AWS Terraform. It
runs `terraform validate`, `terraform test`, `terraform fmt`, `tflint`, `checkov`,
offline manifest rendering and mocked Python tests. The AWS path is validated,
not applied.

## Component cost formulas

| Component | Monthly formula | Notes |
|---|---|---|
| EKS control plane | `eks_hourly_rate × hours_in_month` | Rate depends on region and version. `TODO(measure)`: read the `ap-south-1` rate from the AWS Price List API. |
| EKS system node group | `Σ(instance_hours × instance_rate) + EBS GB-month × storage_rate` | Managed node group is always on; it does not scale to zero. |
| Karpenter spot nodes | `Σ(instance_hours × current_spot_rate)` | Spot-first policy with bounded on-demand fallback; rates vary by AZ. |
| Karpenter on-demand nodes | `Σ(instance_hours × on_demand_rate)` | Used when spot capacity is unavailable or interrupted. |
| NAT gateway | `nat_hourly_rate × hours_in_month + processed_GB × data_rate` | `single_nat_gateway` is a cost toggle in the network module. |
| S3 gateway endpoint | `processed_GB × endpoint_rate` | Gateway endpoints have no hourly charge; S3 traffic normally avoids NAT. |
| RDS (when `rds_enabled = true`) | `instance_hours × instance_rate + allocated_GB × storage_rate + backup_GB_above_allocated × backup_rate + IO requests over included tier × io_rate` | Disabled in some local-style variants; see the environment tfvars. |
| ECR | `stored_GB × storage_rate + data_transfer_GB × transfer_rate` | Three repositories, immutable tags and a lifecycle policy. |
| CloudWatch Logs | `ingested_GB × ingestion_rate + stored_GB × storage_rate + scanned_GB × insights_rate` | VPC flow logs and platform logs. |
| KMS | `key_monthly_rate × key_count + requests_over_free_tier × request_rate` | Keys for state, EKS, ECR and secrets. |
| SQS | `requests × request_rate / 1,000,000` | Karpenter interruption queue only. |
| Application Load Balancer | `alb_hourly_rate × hours_in_month + LCU_hours × lcu_rate` | Created by the AWS Load Balancer Controller, not Terraform; Infracost does not see it. |
| Data transfer | `egress_GB × rate_by_destination` | Cross-AZ and internet egress are usage-driven. |
| Cost Explorer reports | `requests × USD 0.01` | Every page of `get_cost_and_usage` is a billed request. The script prints the request count. |

## Infracost estimates on pull requests

`.github/workflows/terraform-ci.yml` runs the pinned
`ghcr.io/infracost/ci@sha256:e7ddb5c9026624456b47ec4208da00ef942ee390b29cb331d648b8c0d8731ee5`
container on same-repository pull requests when
`INFRACOST_CLI_AUTHENTICATION_TOKEN` is configured. It scans both dev and prod
from `infracost.yml`, using `infracost-usage.yml` for usage assumptions.

The CI container writes the Markdown diff to a file with
`--comment-out-file`; a separate job appends the local guardrail verdict and
upserts one PR comment with a stable marker. This keeps PR-write credentials out
of the pricing container.

Thresholds are evaluated from the rendered comment:

- **warn** at a monthly increase of **+10%** or more;
- **block** at a monthly increase of **+25%** or more.

Cloud-side Infracost guardrails remain authoritative if the human configures
them in Infracost Cloud; the repository-side check is deterministic and works
without dashboard configuration. Percentage parsing is covered by
`scripts/test_cost_guardrail.py`.

### Usage assumptions

`infracost-usage.yml` contains planning assumptions for CloudWatch Logs, RDS,
ECR, SQS and VPC endpoints. They are **not measurements**. Infracost silently
skips a missing usage file, so CI verifies that every configured path exists
before scanning.

| Assumption | Value source | Task |
|---|---|---|
| CloudWatch Logs ingest, storage and Insights scans | `infracost-usage.yml` | `TODO(measure)`: use 30-day CloudWatch metrics after a real demo. |
| RDS IO requests and backup storage | `infracost-usage.yml` | `TODO(measure)`: use CloudWatch `ReadIOPS`, `WriteIOPS` and `FreeStorageSpace`. |
| ECR stored GB | `infracost-usage.yml` | `TODO(measure)`: use ECR storage metrics after images have been pushed. |
| SQS requests | `infracost-usage.yml` | `TODO(measure)`: use `NumberOfMessagesSent` on the interruption queue. |
| NAT / endpoint processed GB | `infracost-usage.yml` | `TODO(measure)`: use VPC flow logs or Cost Explorer by usage type. |
| Spot vs on-demand mix and discount | Karpenter weights and limits | `TODO(measure)`: compare actual node hours and rates after a demo. |

## Actual spend

`scripts/cost_report.py` uses boto3 and AWS Cost Explorer with the `Project`
tag filter `cloud-platform-in-a-box`. It makes one billed API request per page.

<!-- cost-report:start -->
### Actual spend (AWS Cost Explorer)

No measured data has been committed. Run the script with human AWS credentials
to replace this section.

<!-- cost-report:end -->

Example (human-run, creates no resources but **does** incur Cost Explorer API charges):

```bash
.venv/bin/python scripts/cost_report.py \
  --project cloud-platform-in-a-box \
  --start 2026-11-01 \
  --end 2026-12-01
```

## Tag coverage

Every taggable AWS resource must carry `Project`, `Environment`, `ManagedBy`
and `Owner`. `scripts/tag_coverage_check.py` checks HCL locally in `make check`
and checks planned tags from `terraform show -json` in CI, where provider
`default_tags` are visible. Karpenter instances receive the same cost tags from
the cluster-specific `EC2NodeClass`.

## OpenCost view

OpenCost is deployed as an Argo CD Application in the `opencost` namespace and
scraped by the existing Prometheus. The Grafana dashboard
`PlatformBox / Cost by Namespace` uses OpenCost allocation metrics
(`container_cpu_allocation`, `container_memory_allocation_bytes`) joined to
`node_cpu_hourly_cost` and `node_ram_hourly_cost` by the `node` label.

Idle capacity and unallocated costs are deliberately **not** divided by
namespace. Use Cost Explorer for a bill-reconciled view and OpenCost for
relative allocation. `TODO(measure)`: compare both sources over one full
billing month before using the dashboard for chargeback.

## Reduce spend without deleting the cluster

1. Pause Argo CD auto-sync for the app Applications so self-heal cannot restore
   replicas (for example, `argocd app set <app> --sync-policy none`).
2. Scale application Deployments/Rollouts in `app-dev`, `app-staging` and
   `app-prod` to zero. Karpenter consolidates empty nodes according to the
   NodePool disruption budgets.
3. The EKS control plane, NAT gateway, RDS instance (if enabled), EBS volumes,
   log storage and state bucket still bill while paused. Spot nodes should
   drain, but on-demand fallback and the managed system node group remain.
4. Resume by restoring auto-sync and the desired replica counts.

This is a pause, not a teardown. It is suitable for a short demo break.

## Full teardown (human only)

The AWS production path is optional. A full teardown is a human-run
`terraform destroy` in each environment after state backup and approval; it
deletes paid resources. The agent never runs it. The local path uses
`make down`, which deletes only the `kind` cluster and costs nothing.

Destroy order matters: delete Kubernetes Applications and persisted data first,
then run Terraform destroy for `dev` and `prod`, then remove bootstrap state
resources last. Verify with Cost Explorer in the following billing cycle.
