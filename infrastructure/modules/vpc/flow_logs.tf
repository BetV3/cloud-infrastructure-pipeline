resource "aws_cloudwatch_log_group" "vpc_flow" {
    count = var.enable_flow_logs ? 1 : 0
    name = "/aws/vpc-flow-logs/${local.name}"
    retention_in_days = var.flow_logs_retention_in_days

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