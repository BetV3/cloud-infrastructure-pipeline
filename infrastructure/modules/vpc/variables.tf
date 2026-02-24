variable "name_prefix" {
    type = string
    description = "Prefix for naming resources"
}

variable "environment" {
    type = string
    description = "Environment name."
}

variable "vpc_cidr" {
    type = string
    description = "VPC CIDR"
}

variable "az_count" {
    type = number
    description = "How many AZ to use."
    default = 2
}

variable "subnet_newbits" {
    type = number
    description = "Newbits for subnetting"
    default = 8
}

variable "enable_nat_gateway" {
    type = bool
    description = "Create NAT gateways"
    default = true
}

variable "single_nat_gateway" {
    type = bool
    description = "One NAT for all AZs (cheaper dev) vs one per AZ"
    default = true
}

variable "enable_flow_logs" {
    type = bool
    description = "Enable VPC Flow Logs for this VPC"
    default = true
}

variable "flow_logs_traffic_type" {
    type = string
    description = "Flow logs traffic type: ACCEPT, REJECT, OR ALL"
    default = "REJECT"
}

variable "flow_logs_retention_in_days" {
    type = number
    description = "Cloudwatch retention for VPC flow logs"
    default = 90
}