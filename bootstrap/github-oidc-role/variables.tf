variable "aws_region" {
  type        = string
  description = "Region to create IAM resources in (IAM is global, but provider still needs a region)"
  default     = "us-east-2"
}
variable "github_org" {
  type        = string
  description = "Github org or username that owns the repo."
  default = "BetV3"
}

variable "github_repo" {
  type        = string
  description = "Github repository name (without org)."
  default = "cloud-infrastructure-pipeline"
}
variable "apply_branch" {
  type        = string
  description = "Branch allowed to assume the apply role"
  default = "main"
}

variable "state_bucket_name" {
  type        = string
  description = "S3 bucket name used for Terraform remote state"
}

variable "dynamodb_table_name" {
  type        = string
  description = "DynamoDB table name used for Terraform state loacking"
  default     = "terraform-state-lock"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to IAM resources"
  default = {
    "Project" = "cloud-infrastructure-pipeline"
  }
}