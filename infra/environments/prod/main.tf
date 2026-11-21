locals {
  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags,
  )
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
    }
  }
}

# checkov:skip=CKV_TF_1:local module
module "network" {
  source = "../../modules/network"

  project            = var.project
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  single_nat_gateway = false
  enable_flow_logs   = true
  tags               = var.tags
}

# checkov:skip=CKV_TF_1:local module
module "eks" {
  source = "../../modules/eks"

  project             = var.project
  environment         = var.environment
  cluster_version     = var.cluster_version
  vpc_id              = module.network.vpc_id
  private_subnet_ids  = module.network.private_subnet_ids
  public_access_cidrs = var.public_access_cidrs
  node_instance_types = ["t3.large"]
  node_min_size       = 3
  node_max_size       = 6
  node_desired_size   = 3
  tags                = var.tags
}

module "karpenter" {
  source = "../../modules/karpenter"

  project           = var.project
  environment       = var.environment
  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  tags              = var.tags
}

module "ecr" {
  source = "../../modules/ecr"

  project          = var.project
  environment      = var.environment
  repository_names = ["api", "worker", "frontend"]
  tags             = var.tags
}

module "irsa_lb_controller" {
  source = "../../modules/irsa"

  project              = var.project
  environment          = var.environment
  oidc_provider_arn    = module.eks.oidc_provider_arn
  oidc_provider_url    = module.eks.oidc_provider_url
  namespace            = "kube-system"
  service_account_name = "aws-load-balancer-controller"
  policy_json          = data.aws_iam_policy_document.lb_controller.json
  tags                 = var.tags
}

module "irsa_external_secrets" {
  source = "../../modules/irsa"

  project              = var.project
  environment          = var.environment
  oidc_provider_arn    = module.eks.oidc_provider_arn
  oidc_provider_url    = module.eks.oidc_provider_url
  namespace            = "external-secrets"
  service_account_name = "external-secrets"
  policy_json          = data.aws_iam_policy_document.external_secrets.json
  tags                 = var.tags
}

module "secrets" {
  source = "../../modules/secrets"

  project      = var.project
  environment  = var.environment
  secret_names = ["api/database", "api/redis", "slack/webhook"]
  tags         = var.tags
}

module "rds" {
  source = "../../modules/rds"

  project                = var.project
  environment            = var.environment
  enabled                = var.rds_enabled
  vpc_id                 = module.network.vpc_id
  private_subnet_ids     = module.network.private_subnet_ids
  node_security_group_id = module.eks.node_security_group_id
  instance_class         = "db.t4g.small"
  allocated_storage      = 50
  tags                   = var.tags
}

module "budgets" {
  source = "../../modules/budgets"

  project          = var.project
  environment      = var.environment
  budget_email     = var.budget_email
  budget_limit_usd = var.budget_limit_usd
  tags             = var.tags
}

data "aws_iam_policy_document" "lb_controller" {
  # checkov:skip=CKV_AWS_109:AWS Load Balancer Controller requires these permissions per upstream docs
  # checkov:skip=CKV_AWS_111:AWS Load Balancer Controller requires these permissions per upstream docs
  # checkov:skip=CKV_AWS_356:AWS Load Balancer Controller requires wildcard resources per upstream docs
  statement {
    effect    = "Allow"
    actions   = ["ec2:Describe*", "elasticloadbalancing:*", "iam:CreateServiceLinkedRole", "cognito-idp:DescribeUserPoolClient", "acm:ListCertificates", "acm:DescribeCertificate", "waf-regional:GetWebACL", "waf-regional:GetWebACLForResource", "wafv2:GetWebACL", "wafv2:GetWebACLForResource", "shield:GetSubscriptionState", "shield:DescribeProtection", "shield:CreateProtection", "shield:DeleteProtection"]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "external_secrets" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = ["arn:aws:secretsmanager:${var.aws_region}:*:secret:${var.project}/*"]
  }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "7.0.0"

  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }

  depends_on = [module.eks]
}

resource "kubernetes_manifest" "argocd_root_app" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "root"
      namespace = "argocd"
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://github.com/${var.project}/${var.project}.git"
        targetRevision = "main"
        path           = "gitops/bootstrap"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "argocd"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
      }
    }
  }

  depends_on = [helm_release.argocd]
}
