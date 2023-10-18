output "arn" {
  description = "ARN of the lambda function"
  value       = local.enabled ? aws_lambda_function.this[0].arn : null
}

output "invoke_arn" {
  description = "Inkoke ARN of the lambda function"
  value       = local.enabled ? aws_lambda_function.this[0].invoke_arn : null
}

output "function_name" {
  description = "Function Name of the lambda function"
  value       = local.enabled ? aws_lambda_function.this[0].function_name : null
}

output "qualified_arn" {
  description = "ARN identifying your Lambda Function Version (if versioning is enabled via publish = true)"
  value       = local.enabled ? aws_lambda_function.this[0].qualified_arn : null
}

output "role_arn" {
  description = "ARN of the lambda function IAM Role"
  value       = local.enabled ? aws_iam_role.this[0].arn : null
}

output "role_name" {
  description = "The Name of the lambda function IAM Role"
  value       = local.enabled ? aws_iam_role.this[0].name : null
}

output "cloudwatch_log_group" {
  description = "The Name of the lambda function's log group"
  value       = local.enabled ? aws_cloudwatch_log_group.this[0].name : null
}
