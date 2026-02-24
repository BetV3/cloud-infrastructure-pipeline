data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs  = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  name = "${var.name_prefix}-${var.environment}"

  # Generate 2 * az_count subnets from vpc_cidr:
  # - public: netnums 0..(az_count-1)
  # - private: netnums az_count..(2*az_count-1)
  public_cidrs = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, var.subnet_newbits, i)]
  private_cidrs = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, var.subnet_newbits, i + var.az_count)]
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name}-igw"
  }
}

resource "aws_subnet" "public" {
  for_each = { for idx, az in local.azs : idx => az }

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.value
  cidr_block              = local.public_cidrs[each.key]
  map_public_ip_on_launch = false # Fixes CKV_AWS_130 from checkov

  tags = {
    Name = "${local.name}-public-${each.value}"
    Tier = "public"
  }
}

resource "aws_subnet" "private" {
  for_each = { for idx, az in local.azs : idx => az }

  vpc_id            = aws_vpc.this.id
  availability_zone = each.value
  cidr_block        = local.private_cidrs[each.key]

  tags = {
    Name = "${local.name}-private-${each.value}"
    Tier = "private"
  }
}

# Public routing
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name}-rt-public"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# NAT (optional)
resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : var.az_count) : 0
  domain = "vpc"

  tags = {
    Name = "${local.name}-eip-nat-${count.index}"
  }
}

resource "aws_nat_gateway" "this" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : var.az_count) : 0

  allocation_id = aws_eip.nat[count.index].id

  # Place NAT in public subnet(s)
  subnet_id = var.single_nat_gateway ? aws_subnet.public[0].id : aws_subnet.public[count.index].id

  tags = {
    Name = "${local.name}-nat-${count.index}"
  }

  depends_on = [aws_internet_gateway.this]
}

# Private routing (one per AZ)
resource "aws_route_table" "private" {
  for_each = aws_subnet.private

  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name}-rt-private-${each.value.availability_zone}"
  }
}

resource "aws_route" "private_default" {
  for_each = var.enable_nat_gateway ? aws_route_table.private : {}

  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"

  nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.this[0].id : aws_nat_gateway.this[tonumber(each.key)].id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}