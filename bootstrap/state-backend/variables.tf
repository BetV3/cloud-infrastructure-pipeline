variable "aws_region" {
    type = string
    description = "Region to create the Terraform state backend resources in."
    default = "us-east-2"
}
variable "aws_profile" {
    type = string
    description = "AWS SSO Profile to authenticate to AWS"
}
variable "state_bucket_name" {
    type = string
    description = "Globally-unique S3 bucket name for Terraform remote state."
}

variable "dynamodb_table_name" {
    type = string
    description = "DynamoDB table name for Terraform state locking"
    default = "terraform-state-lock"
}

variable "tags" {
    type = map(string)
    description = "Tags to apply to resources"
    default = {
        Project = "cloud-infrastructure-pipeline"
        Owner = "elvis"
    }
}