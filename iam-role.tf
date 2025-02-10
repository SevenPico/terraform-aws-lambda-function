
#--------------------------------------------------
# Base IAM Assume Role
#--------------------------------------------------
locals {
  service_principal_identifiers = var.lambda_at_edge ? ["edgelambda.amazonaws.com"] : ["lambda.amazonaws.com"]
  role_name                     = var.role_name == "" ? "${var.function_name}-${local.region}" : var.role_name
}

data "aws_iam_policy_document" "assume_role_policy" {
  count = module.context.enabled ? 1 : 0
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = local.service_principal_identifiers
    }
  }
}

resource "aws_iam_role" "this" {
  count              = local.enabled ? 1 : 0
  name               = local.role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy[0].json
  tags               = module.context.tags
}


#--------------------------------------------------
# Base IAM Role Policy
#--------------------------------------------------
data "aws_iam_policy_document" "this" {
  count                   = module.context.enabled ? 1 : 0
  source_policy_documents = var.lambda_role_source_policy_documents

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
}

resource "aws_iam_policy" "this" {
  count       = module.context.enabled ? 1 : 0
  description = "Provides minimum Cloudwatch permissions."
  name        = "${local.role_name}-policy"
  policy      = data.aws_iam_policy_document.this[0].json
  tags               = module.context.tags
}

resource "aws_iam_role_policy_attachment" "this" {
  count      = module.context.enabled ? 1 : 0
  policy_arn = aws_iam_policy.this[0].arn
  role       = aws_iam_role.this[0].name
}


#--------------------------------------------------
# SSM Policy
#--------------------------------------------------
# Allow Lambda to access specific SSM parameters
data "aws_iam_policy_document" "ssm" {
  count = try((local.enabled && var.ssm_parameter_names != null && length(var.ssm_parameter_names) > 0), false) ? 1 : 0

  statement {
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
    ]

    resources = formatlist("${local.arn_prefix}:ssm:${local.region}:${local.account_id}:parameter%s", var.ssm_parameter_names)
  }
}

resource "aws_iam_policy" "ssm" {
  count = try((local.enabled && var.ssm_parameter_names != null && length(var.ssm_parameter_names) > 0), false) ? 1 : 0

  description = "Provides minimum SSM read permissions."
  name        = "${local.role_name}-ssm-policy"
  policy      = data.aws_iam_policy_document.ssm[count.index].json
  tags        = module.context.tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  count      = try((local.enabled && var.ssm_parameter_names != null && length(var.ssm_parameter_names) > 0), false) ? 1 : 0
  policy_arn = aws_iam_policy.ssm[count.index].arn
  role       = aws_iam_role.this[0].name
}


#--------------------------------------------------
# Add Canned Policies as Needed
#--------------------------------------------------
resource "aws_iam_role_policy_attachment" "cloudwatch_insights" {
  count = local.enabled && var.cloudwatch_lambda_insights_enabled ? 1 : 0

  policy_arn = "${local.arn_prefix}:iam::aws:policy/CloudWatchLambdaInsightsExecutionRolePolicy"
  role       = aws_iam_role.this[0].name
}

resource "aws_iam_role_policy_attachment" "vpc_access" {
  count = local.enabled && var.vpc_config == null ? 1 : 0

  policy_arn = "${local.arn_prefix}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  role       = aws_iam_role.this[0].name
}

resource "aws_iam_role_policy_attachment" "xray" {
  count = local.enabled && var.tracing_config_mode == null ? 1 : 0

  policy_arn = "${local.arn_prefix}:iam::aws:policy/AWSXRayDaemonWriteAccess"
  role       = aws_iam_role.this[0].name
}
