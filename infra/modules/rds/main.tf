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

resource "aws_db_subnet_group" "this" {
  count = var.enabled ? 1 : 0

  name       = "${var.project}-${var.environment}-postgres"
  subnet_ids = var.private_subnet_ids

  tags = local.common_tags
}

resource "aws_security_group" "this" {
  count = var.enabled ? 1 : 0

  name        = "${var.project}-${var.environment}-postgres"
  description = "PostgreSQL access from EKS nodes only."
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.node_security_group_id]
  }

  egress {
    description = "Outbound to VPC for backups and DNS"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/8"]
  }

  tags = local.common_tags
}

resource "aws_iam_role" "rds_monitoring" {
  count = var.enabled ? 1 : 0

  name = "${var.project}-${var.environment}-rds-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count = var.enabled ? 1 : 0

  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
resource "aws_db_instance" "this" {
  # checkov:skip=CKV_AWS_353:performance insights adds cost; enable in prod if needed
  # checkov:skip=CKV_AWS_157:Prod sets multi_az=true; dev stays single-AZ for cost
  # checkov:skip=CKV2_AWS_30:query logging requires a custom parameter group; enable in prod
  count = var.enabled ? 1 : 0

  identifier = "${var.project}-${var.environment}-postgres"

  engine         = "postgres"
  engine_version = "16"
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true
  multi_az          = var.multi_az

  db_name  = var.database_name
  username = var.master_username
  # Managed master password in Secrets Manager; no password in Terraform.
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this[0].name
  vpc_security_group_ids = [aws_security_group.this[0].id]

  backup_retention_period   = 7
  deletion_protection       = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.project}-${var.environment}-postgres-final"

  auto_minor_version_upgrade = true
  publicly_accessible        = false

  iam_database_authentication_enabled = true
  copy_tags_to_snapshot               = true
  enabled_cloudwatch_logs_exports     = ["postgresql"]

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring[0].arn

  tags = local.common_tags
}
