# Smoke test for the bootstrap module.
# Uses a mock provider so it runs without AWS credentials. Validates that the
# module synthesizes a valid plan.

mock_provider "aws" {}

variables {
  state_bucket_name = "test-state-bucket-12345"
  budget_email      = "test@example.com"
}

run "plan" {
  command = plan

  assert {
    condition     = aws_s3_bucket.state.bucket == var.state_bucket_name
    error_message = "state bucket name must match the input"
  }
}
