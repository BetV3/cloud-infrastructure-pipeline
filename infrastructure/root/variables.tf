variable "environment" {
    type = string
    description = "Environment name: dev/staging/prod"
}

variable "aws_region" {
    type = string
    description = "AWS region for this environment"
}

variable "tags" {
    type = map(string)
    description = "Extra tags applied to all resources"
    default = {}
}

variable "vpc_cidr" {
    type = string
    description = "VPC CIDR block (e.g 10.0.0.0/8)"
}

variable "az_count" {
    type = number
    description = "How many AZs to use."
    default = 2
}

variable "subnet_newbits" {
    type = number
    description = "How many bits to add for subnets. /16 with 8 -> /24 subnets"
}

variable "enable_nat_gateway" {
    type = bool
    description = "Create NAT gateways for private subnet egress"
    default = false
}

variable "single_nat_gateway" {
    type = bool
    description = "If true, craete 1 NAT for all AZs (cheaper for dev). If false, 1 per AZ"
    default = false
}

variable "aws_prefix" {
    type = string
    description = "Prefix for naming resources"
    default = "cip"
}