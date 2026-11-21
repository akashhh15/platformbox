locals {
  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags,
  )

  cluster_name = "${var.project}-${var.environment}"
}

module "eks" {
  # checkov:skip=CKV_TF_1:registry module pinned via version constraint
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = var.public_access_cidrs
  cluster_endpoint_private_access      = true

  # KMS encryption for secrets.
  cluster_encryption_config = {
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }

  # Control plane logging.
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  # Access entries instead of aws-auth ConfigMap.
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    system = {
      name           = "system"
      instance_types = var.node_instance_types
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size

      # IMDSv2 required.
      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 1
      }

      labels = {
        "node-role" = "system"
      }

      taints = []
    }
  }

  # Managed add-ons.
  cluster_addons = {
    vpc-cni = {
      most_recent = true
    }
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  tags = local.common_tags
}

# KMS key for EKS secrets encryption.
resource "aws_kms_key" "eks" {
  description             = "KMS key for EKS secrets encryption (${var.project}-${var.environment})"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccount"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowEKSService"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
        ]
        Resource = "*"
      },
    ]
  })

  tags = local.common_tags
}

data "aws_caller_identity" "current" {}

resource "aws_kms_alias" "eks" {
  name          = "alias/${var.project}-${var.environment}-eks"
  target_key_id = aws_kms_key.eks.key_id
}
