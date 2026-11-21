locals {
  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags,
  )

  oidc_url = replace(var.oidc_provider_url, "https://", "")
}

# ---------------------------------------------------------------------------
# Controller IAM role (IRSA)
# ---------------------------------------------------------------------------

resource "aws_iam_role" "controller" {
  name = "${var.project}-${var.environment}-karpenter-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = var.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_url}:aud" = "sts.amazonaws.com"
          "${local.oidc_url}:sub" = "system:serviceaccount:karpenter:karpenter"
        }
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "controller" {
  # checkov:skip=CKV_AWS_288:EC2 wildcard actions required for Karpenter node provisioning
  # checkov:skip=CKV_AWS_355:EC2 wildcard resources required for Karpenter
  # checkov:skip=CKV_AWS_290:EC2 write access required for Karpenter node lifecycle
  name = "karpenter-controller"
  role = aws_iam_role.controller.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2"
        Effect = "Allow"
        Action = [
          "ec2:CreateFleet",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateTags",
          "ec2:DeleteLaunchTemplate",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeImages",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeSubnets",
          "ec2:RunInstances",
          "ec2:TerminateInstances",
        ]
        Resource = "*"
      },
      {
        Sid      = "IAMPassRole"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = aws_iam_role.node.arn
      },
      {
        Sid    = "SQS"
        Effect = "Allow"
        Action = [
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ReceiveMessage",
        ]
        Resource = aws_sqs_queue.interruption.arn
      },
      {
        Sid      = "SSM"
        Effect   = "Allow"
        Action   = "ssm:GetParameter"
        Resource = "*"
      },
      {
        Sid      = "Pricing"
        Effect   = "Allow"
        Action   = "pricing:GetProducts"
        Resource = "*"
      },
    ]
  })
}

# ---------------------------------------------------------------------------
# Node IAM role (assumed by Karpenter-launched instances)
# ---------------------------------------------------------------------------

resource "aws_iam_role" "node" {
  name = "${var.project}-${var.environment}-karpenter-node"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "node_ssm" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "node_eks_worker" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_ecr" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "node_cni" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_instance_profile" "node" {
  name = "${var.project}-${var.environment}-karpenter-node"
  role = aws_iam_role.node.name

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Interruption queue + EventBridge rules
# ---------------------------------------------------------------------------

resource "aws_sqs_queue" "interruption" {
  name                      = "${var.project}-${var.environment}-karpenter-interruption"
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true

  tags = local.common_tags
}

resource "aws_sqs_queue_policy" "interruption" {
  queue_url = aws_sqs_queue.interruption.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = ["events.amazonaws.com", "sqs.amazonaws.com"] }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.interruption.arn
    }]
  })
}

resource "aws_cloudwatch_event_rule" "scheduled_change" {
  name        = "${var.project}-${var.environment}-karpenter-scheduled-change"
  description = "Karpenter interruption handling for scheduled changes."

  event_pattern = jsonencode({
    source      = ["aws.health"]
    detail-type = ["AWS Health Event"]
  })

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "scheduled_change" {
  rule      = aws_cloudwatch_event_rule.scheduled_change.name
  target_id = "karpenter"
  arn       = aws_sqs_queue.interruption.arn
}

resource "aws_cloudwatch_event_rule" "spot_interruption" {
  name        = "${var.project}-${var.environment}-karpenter-spot-interruption"
  description = "Karpenter interruption handling for spot instances."

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "spot_interruption" {
  rule      = aws_cloudwatch_event_rule.spot_interruption.name
  target_id = "karpenter"
  arn       = aws_sqs_queue.interruption.arn
}

resource "aws_cloudwatch_event_rule" "rebalance" {
  name        = "${var.project}-${var.environment}-karpenter-rebalance"
  description = "Karpenter interruption handling for rebalance recommendations."

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance Rebalance Recommendation"]
  })

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "rebalance" {
  rule      = aws_cloudwatch_event_rule.rebalance.name
  target_id = "karpenter"
  arn       = aws_sqs_queue.interruption.arn
}

# ---------------------------------------------------------------------------
# Helm release for the Karpenter controller
# ---------------------------------------------------------------------------

resource "helm_release" "karpenter" {
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = "1.0.0"
  namespace        = "karpenter"
  create_namespace = true

  set {
    name  = "settings.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "settings.clusterEndpoint"
    value = var.cluster_endpoint
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.controller.arn
  }

  set {
    name  = "settings.interruptionQueue"
    value = aws_sqs_queue.interruption.name
  }
}
