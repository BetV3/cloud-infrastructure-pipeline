module "vpc" {
    source = "../modules/vpc"

    name_prefix = var.name_prefix
    environment = var.environment
    vpc_cidr = var.vpc_cidr
    az_count = var.az_count
    subnet_newbits = var.subnet_newbits
    enable_nat_gateway = var.enable_nat_gateway
    single_nat_gateway = var.single_nat_gateway
}