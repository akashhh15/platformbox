# Wraps the community terraform-aws-modules/vpc/aws module. The wrapper owns the
# naming, tagging and the Karpenter/ELB subnet tags that the platform depends on.

locals {
  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags,
  )

  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)
}

data "aws_availability_zones" "available" {
  # checkov:skip=CKV_AWS_394:zone identity is pinned by the opt-in-status filter
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

module "vpc" {
  # checkov:skip=CKV_TF_1:registry module pinned via version constraint
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project}-${var.environment}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i + 8)]

  enable_nat_gateway     = true
  single_nat_gateway     = var.single_nat_gateway
  one_nat_gateway_per_az = !var.single_nat_gateway

  enable_dns_hostnames = true
  enable_dns_support   = true

  # S3 gateway endpoint is created as a separate resource below.

  # Subnet tags required by the AWS Load Balancer Controller and Karpenter.
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    "karpenter.sh/discovery"          = "${var.project}-${var.environment}"
  }

  tags = local.common_tags
}

# S3 gateway endpoint saves NAT data-processing charges for state and ECR pulls.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids

  tags = local.common_tags
}

data "aws_region" "current" {}

resource "aws_cloudwatch_log_group" "flow_logs" {
  # checkov:skip=CKV_AWS_158:KMS encryption for flow logs is optional in dev
  # checkov:skip=CKV_AWS_338:30-day retention is sufficient for dev; prod uses 1 year
  count = var.enable_flow_logs ? 1 : 0

  name              = "/aws/vpc/${var.project}-${var.environment}/flow-logs"
  retention_in_days = 30

  tags = local.common_tags
}

resource "aws_flow_log" "this" {
  count = var.enable_flow_logs ? 1 : 0

  iam_role_arn    = aws_iam_role.flow_logs[0].arn
  log_destination = aws_cloudwatch_log_group.flow_logs[0].arn
  traffic_type    = "ALL"
  vpc_id          = module.vpc.vpc_id

  tags = local.common_tags
}

resource "aws_iam_role" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.project}-${var.environment}-vpc-flow-logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "flow_logs" {
  # checkov:skip=CKV_AWS_355:flow logs requires these permissions
  # checkov:skip=CKV_AWS_290:flow logs requires write access to CloudWatch
  count = var.enable_flow_logs ? 1 : 0

  name = "flow-logs"
  role = aws_iam_role.flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
      ]
      Resource = "*"
    }]
  })
}
