output "id" {
  description = "Budget ID."
  value       = aws_budgets_budget.this.id
}

output "name" {
  description = "Budget name."
  value       = aws_budgets_budget.this.name
}
