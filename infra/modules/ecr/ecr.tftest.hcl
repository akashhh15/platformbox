# Offline contract for the ECR module (ADR-020). The mock provider means no
# credentials and no AWS API calls; these assertions run inside `terraform test`.

mock_provider "aws" {}

variables {
  project               = "platformbox"
  environment           = "test"
  repository_names      = ["api", "worker", "frontend"]
  image_retention_count = 20
}

run "repositories_are_hardened" {
  command = plan

  assert {
    condition = alltrue([
      for repo in values(aws_ecr_repository.this) :
      repo.image_tag_mutability == "IMMUTABLE" &&
      repo.image_scanning_configuration[0].scan_on_push == true &&
      repo.encryption_configuration[0].encryption_type == "KMS"
    ])
    error_message = "Every ECR repository must be immutable, scan on push and use KMS."
  }

  assert {
    condition     = length(aws_ecr_repository.this) == 3
    error_message = "One repository per application image is expected."
  }

  assert {
    condition     = aws_kms_key.ecr.enable_key_rotation == true
    error_message = "The ECR KMS key must rotate automatically."
  }

  assert {
    condition     = length(aws_ecr_lifecycle_policy.this) == 3
    error_message = "Every repository must have a lifecycle policy."
  }
}
