data "aws_caller_identity" "current" {}

# Fetch Github's OIDC TLS cert chain thumbprint dynamically.
# This avoids brittle hardcoded thumbprints that can break OIDC auth. :contentReference[oacite:1]{index=1}
data "tls_certificate" "github_actions" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazon.com"]
  thumbprint_list = [data.tls_certificate.github_actions.certificates[0].sha1_fingerprint]

  tags = var.tags
}

locals {
  repo_full = "${var.github_org}/${var.github_repo}"
}

# Trust Policies
data "aws_iam_policy_document" "assume_plan" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Allow PRs + branches to assume PLAN role
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${local.repo_full}:pull_request",
        "repo:${local.repo_full}:ref:refs/heads/*"
      ]
    }
  }
}

data "aws_iam_policy_document" "assume_apply" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Only allow a protected branch (main) to assume APPLY role
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${local.repo_full}:ref:refs/heads/${var.apply_branch}"]
    }
  }
}

# Roles

resource "aws_iam_role" "plan" {
  name               = "cip-github-actions-plan"
  assume_role_policy = data.aws_iam_policy_document.assume_plan.json
  tags               = var.tags
}

resource "aws_iam_role" "apply" {
  name               = "cip-github-actions-apply"
  assume_role_policy = data.aws_iam_policy_document.assume_apply.json
  tags               = var.tags
}

# Permissions policies

# Backend access for Terraform (S3 State + DynamoDB locking)
data "aws_iam_policy_document" "tf_backend_plan" {
  statement {
    sid    = "StateBucketRead"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketVersioning",
      "s3:GetEncryptionConfiguration",
      "s3:GetBucketPublicAccessBlock",
      "s3:GetObject"
    ]
    resources = [
      "arn:aws:s3:::${var.state_bucket_name}",
      "arn:aws:s3:::${var.state_bucket_name}/*"
    ]
  }

  # Plan still needs DynamoDB write to acquire/release state locks
  statement {
    sid    = "LockTableRW"
    effect = "Allow"
    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "dynamodb:UpdateItem"
    ]
    resources = ["arn:aws:dynamodb:*:${data.aws_caller_identity.current.account_id}:table/${var.dynamodb_table_name}"]
  }
}

data "aws_iam_policy_document" "tf_backend_apply" {
  statement {
    sid    = "StateBucketRW"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketVersioning",
      "s3:GetEncryptionConfiguration",
      "s3:GetBucketPublicAccessBlock",
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [
      "arn:aws:s3:::${var.state_bucket_name}",
      "arn:aws:s3:::${var.state_bucket_name}/*"
    ]
  }

  statement {
    sid    = "LockTableRW"
    effect = "Allow"
    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "dynamodb:UpdateItem"
    ]
    resources = ["arn:aws:dynamodb:*:${data.aws_caller_identity.current.account_id}:table/${var.dynamodb_table_name}"]
  }
}

# VPC permissions for Terraform apply (dev slice)
data "aws_iam_policy_document" "apply_vpc" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateVpc",
      "ec2:DeleteVpc",
      "ec2:ModifyVpcAttribute",
      "ec2:Describe*",

      "ec2:CreateSubnet",
      "ec2:DeleteSubnet",

      "ec2:CreateInternetGateway",
      "ec2:DeleteInternetGateway",
      "ec2:AttachInternetGateway",
      "ec2:DetachInternetGateway",

      "ec2:CreateRouteTable",
      "ec2:DeleteRouteTable",
      "ec2:AssociateRouteTable",
      "ec2:DisassociateRouteTable",

      "ec2:CreateRoute",
      "ec2:ReplaceRoute",
      "ec2:DeleteRoute",

      "ec2:AllocateAddress",
      "ec2:ReleaseAddress",

      "ec2:CreateNatGateway",
      "ec2:DeleteNatGateway",
      "ec2:DescribeNatGateways",

      "ec2:CreateTags",
      "ec2:DeleteTags"
    ]
    resources = ["*"]
  }
}


resource "aws_iam_policy" "apply_vpc" {
  name   = "cip-apply-vpc"
  policy = data.aws_iam_policy_document.apply_vpc.json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "apply_vpc" {
  role       = aws_iam_role.apply.name
  policy_arn = aws_iam_policy.apply_vpc.arn
}

resource "aws_iam_policy" "backend_plan" {
  name   = "cip-terraform-backend-plan"
  policy = data.aws_iam_policy_document.tf_backend_plan.json
  tags   = var.tags
}

resource "aws_iam_policy" "backend_apply" {
  name   = "cip-terraform-backend-apply"
  policy = data.aws_iam_policy_document.tf_backend_apply.json
  tags   = var.tags
}

# Minimal “read” for plan to inspect AWS (keeps plan useful).
# We'll tighten later, but this keeps you moving.
resource "aws_iam_role_policy_attachment" "plan_readonly" {
  role       = aws_iam_role.plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "plan_backend" {
  role       = aws_iam_role.plan.name
  policy_arn = aws_iam_policy.backend_plan.arn
}

# Apply role: backend RW now, and we'll attach infra permissions next step as we add modules.
resource "aws_iam_role_policy_attachment" "apply_backend" {
  role       = aws_iam_role.apply.name
  policy_arn = aws_iam_policy.backend_apply.arn
}