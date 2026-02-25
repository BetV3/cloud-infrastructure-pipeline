data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  flow_logs_kms_arn = (var.flow_logs_kms_key_arn != null ? var.flow_logs_kms_key_arn : (var.create_flow_logs_kms_key ? aws_kms_key.flow_logs[0].arn : null))
}

data "aws_iam_policy_document" "flow_logs_kms" {
  statement {
    sid = "EnableRootPermissions"
    effect = "Allow"
    principals {
      type = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid = "AllowCloudWatchLogsUse"
    effect = "Allow"
    principals {
      type = "Service"
      identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey"
    ]
    resources = ["*"]
  }
}

resource "aws_kms_key" "flow_logs" {
  count = var.enable_flow_logs && var.create_flow_logs_kms_key && var.flow_logs_kms_key_arn == null ? 1 : 0
  description = "KMS key for ${local.name} VPC flow logs"
  enable_key_rotation = true
  deletion_window_in_days = 30
  policy = data.aws_iam_policy_document.flow_logs_kms.json

  tags = {
    Name = "${local.name}-flow-logs-kms"
  }
}

resource "aws_kms_alias" "flow_logs" {
  count = length(aws_kms_key.flow_logs)
  name = "alias/${local.name}-flow-logs"
  target_key_id = aws_kms_key.flow_logs[0].key_id
}

resource "aws_cloudwatch_log_group" "vpc_flow" {
    count = var.enable_flow_logs ? 1 : 0
    name = "/aws/vpc-flow-logs/${local.name}"
    retention_in_days = var.flow_logs_retention_in_days


    kms_key_id = local.flow_logs_kms_arn
    
    tags = {
        Name = "${local.name}-vpc-flow-logs"
    }
}

data "aws_iam_policy_document" "flow_logs_assume_role" {
    statement {
      effect = "Allow"
      actions = ["sts:AssumeRole"]

      principals {
        type = "Service"
        identifiers = ["vpc-flow-logs.amazonaws.com"]
      }
    }
}

resource "aws_iam_role" "flow_logs" {
    count = var.enable_flow_logs ? 1 : 0
    name = "${local.name}-vpc-flow-logs-role"
    assume_role_policy = data.aws_iam_policy_document.flow_logs_assume_role.json
}

data "aws_iam_policy_document" "flow_logs_published" {
    statement {
      effect = "Allow"
      actions = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      resources = [
        aws_cloudwatch_log_group.vpc_flow[0].arn,
        "${aws_cloudwatch_log_group.vpc_flow[0].arn}:*"
      ]
    }
}

resource "aws_iam_role_policy" "flow_logs_published" {
    count = var.enable_flow_logs ? 1 : 0
    name = "${local.name}-vpc-flow-logs-publish"
    role = aws_iam_role.flow_logs[0].id
    policy = data.aws_iam_policy_document.flow_logs_published.json
}

resource "aws_flow_log" "vpc" {
    count = var.enable_flow_logs ? 1 : 0

    vpc_id = aws_vpc.this.id
    traffic_type = var.flow_logs_traffic_type
    log_destination_type = "cloud-watch-logs"
    log_destination = aws_cloudwatch_log_group.vpc_flow[0].arn
    iam_role_arn = aws_iam_role.flow_logs[0].arn
}