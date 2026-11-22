# Offline contract for the AWS Budgets module (ADR-020).

mock_provider "aws" {}

variables {
  project          = "platformbox"
  environment      = "test"
  budget_email     = "test@example.com"
  budget_limit_usd = 50
}

run "budget_alerts" {
  command = plan

  assert {
    condition     = aws_budgets_budget.monthly.limit_amount == "50"
    error_message = "The budget limit must be the configured USD amount."
  }

  assert {
    condition     = aws_budgets_budget.monthly.limit_unit == "USD"
    error_message = "The budget unit must be USD."
  }

  assert {
    condition     = length(aws_budgets_budget.monthly.notification) == 3
    error_message = "The budget must notify at 50, 80 and 100 percent."
  }

  assert {
    condition = alltrue([
      for n in aws_budgets_budget.monthly.notification :
      contains(n.subscriber_email_addresses, var.budget_email)
    ])
    error_message = "Every notification must reach the configured e-mail address."
  }
}
