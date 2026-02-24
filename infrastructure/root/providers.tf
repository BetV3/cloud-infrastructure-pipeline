provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(
      var.tags,
      {
        Environment = var.environment
        ManagedBy   = "terraform-test"
        Project     = "cloud-infrastructure-pipeline"
      }
    )
  }
}