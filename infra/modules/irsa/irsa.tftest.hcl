# Offline contract for the IRSA module (ADR-020). These assertions stop a
# trust policy from being widened to another namespace or service account.

mock_provider "aws" {}

variables {
  project              = "platformbox"
  environment          = "test"
  oidc_provider_arn    = "arn:aws:iam::111122223333:oidc-provider/oidc.eks.ap-south-1.amazonaws.com/id/EXAMPLE"
  oidc_provider_url    = "https://oidc.eks.ap-south-1.amazonaws.com/id/EXAMPLE"
  namespace            = "external-secrets"
  service_account_name = "external-secrets"
  policy_json          = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":[\"secretsmanager:GetSecretValue\"],\"Resource\":\"*\"}]}"
}

run "trust_policy_is_scoped" {
  command = plan

  assert {
    condition     = jsondecode(aws_iam_role.this.assume_role_policy).Statement[0].Condition.StringEquals["oidc.eks.ap-south-1.amazonaws.com/id/EXAMPLE:sub"] == "system:serviceaccount:external-secrets:external-secrets"
    error_message = "The trust policy must be scoped to the exact namespace and service account."
  }

  assert {
    condition     = jsondecode(aws_iam_role.this.assume_role_policy).Statement[0].Condition.StringEquals["oidc.eks.ap-south-1.amazonaws.com/id/EXAMPLE:aud"] == "sts.amazonaws.com"
    error_message = "The trust policy audience must be sts.amazonaws.com."
  }

  assert {
    condition     = jsondecode(aws_iam_role.this.assume_role_policy).Statement[0].Action == "sts:AssumeRoleWithWebIdentity"
    error_message = "IRSA must use web identity federation."
  }

  assert {
    condition     = length(aws_iam_role_policy.this) == 1
    error_message = "A supplied policy document must be attached to the role."
  }

  assert {
    condition     = aws_iam_role.this.name == "platformbox-test-external-secrets-external-secrets"
    error_message = "Role names must follow the project-environment-namespace-serviceaccount convention."
  }
}
