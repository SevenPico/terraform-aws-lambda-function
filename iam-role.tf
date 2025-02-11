locals {
  service_principal_identifiers = var.lambda_at_edge ? ["edgelambda.amazonaws.com"] : ["lambda.amazonaws.com"]
  role_name                     = var.role_name == "" ? "${var.function_name}-${local.region}" : var.role_name
}

#--------------------------------------------------
# Base Policy
#--------------------------------------------------

data "aws_iam_policy_document" "lambda_base_policy" {
  count = module.context.enabled ? 1 : 0
  statement {
    sid = "Logging"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    effect = "Allow"
    resources = [
      "${aws_cloudwatch_log_group.this[0].arn}:*"
    ]
  }

  dynamic "statement" {
    for_each = var.lambda_role_source_policy_documents != null ? var.lambda_role_source_policy_documents : {}
    content {
      sid       = lookup(each.value, "sid", null)
      actions   = lookup(each.value, "actions", [])
      resources = lookup(each.value, "resources", [])
      effect    = lookup(each.value, "effect", "Allow")
    }
  }
}

#--------------------------------------------------
# SSM Policy
#--------------------------------------------------
data "aws_iam_policy_document" "ssm_policy" {
  count = try((module.context.enabled && var.ssm_parameter_names != null && length(var.ssm_parameter_names) > 0), false) ? 1 : 0

  statement {
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
    ]

    resources = formatlist("${local.arn_prefix}:ssm:${local.region}:${local.account_id}:parameter%s", var.ssm_parameter_names)
  }
}

# --------------------------------------------------
# Lambda Role
# --------------------------------------------------
module "role" {
  count = module.context.enabled ? 1 : 0

  source  = "registry.terraform.io/SevenPicoForks/iam-role/aws"
  version = "2.0.2" # Or latest

  context    = module.context.self
  attributes = [local.role_name]

  assume_role_actions = ["sts:AssumeRole"]
  principals = {
    Service : local.service_principal_identifiers
  }

  max_session_duration = 3600
  path                 = "/aws/lambda"
  permissions_boundary = ""
  role_description     = "IAM role for Lambda function ${var.function_name}"

  policy_description = "Policy for Lambda function ${var.function_name}"
  policy_documents = [
    data.aws_iam_policy_document.lambda_base_policy[0].json,
    try(data.aws_iam_policy_document.ssm_policy[0].json, null),
  ]

  managed_policy_arns = concat(
    module.context.enabled && var.cloudwatch_lambda_insights_enabled ? ["arn:aws:iam::aws:policy/CloudWatchLambdaInsightsExecutionRolePolicy"] : [],
    module.context.enabled && var.vpc_config == null ? ["arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"] : [],
    module.context.enabled && var.tracing_config_mode == null ? ["arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"] : [],
    var.lambda_role_managed_policy_arns
  )

  use_fullname = true
  tags         = module.context.tags
}

