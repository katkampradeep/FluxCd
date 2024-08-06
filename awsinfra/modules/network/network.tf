terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      configuration_aliases = [ aws ]
    }
  }
}

resource "aws_vpc" "vpc" {
    cidr_block = var.vpc_cidr_range
    instance_tenancy = "default"
    enable_dns_hostnames = true
    enable_dns_support = true
    enable_network_address_usage_metrics = true
    tags = {
        Name = "${var.prefix}-vpc"
    }
}

resource "aws_ssm_parameter" "vpc_ssm" {
  name  = "/v3/vpc/id"
  type  = "String"
  value = aws_vpc.vpc.id
  depends_on = [ aws_vpc.vpc ]
}

resource "aws_subnet" "private_subnets" {
  for_each = var.private_subnet_info
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = each.value.cidr_range
  availability_zone = each.value.az
  map_public_ip_on_launch = each.value.public_ip

  tags = each.value.tags
}

resource "aws_subnet" "public_subnets" {
  for_each = var.public_subnet_info
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = each.value.cidr_range
  availability_zone = each.value.az
  map_public_ip_on_launch = each.value.public_ip
  tags = each.value.tags
}

resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.prefix}-ig"
  }
}

resource "aws_eip" "eip" {
  domain = "vpc"
  tags = {
    Name = "v3-EIP"
  }
}


resource "aws_nat_gateway" "natgateway" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.public_subnets["${var.natgateway_public_subnet_name}"].id
  tags = {
    Name = "natgateway"
  }

  depends_on = [aws_internet_gateway.ig]

}


resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc.id
  route {
      cidr_block                 = "0.0.0.0/0"
      nat_gateway_id             = aws_nat_gateway.natgateway.id
    }
  tags = {
    Name = "${var.prefix}-public-route-table"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
      cidr_block                 = "0.0.0.0/0"
      gateway_id                 = aws_internet_gateway.ig.id
      
    }
  tags = {
    Name = "${var.prefix}-public-route-table"
  }
}

resource "aws_route_table_association" "private_route_table_association" {
  for_each = var.private_subnet_info
  subnet_id      = aws_subnet.private_subnets[each.key].id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "public_route_table_association" {
  for_each = var.public_subnet_info
  subnet_id      =  aws_subnet.public_subnets[each.key].id
  route_table_id = aws_route_table.public_route_table.id
}
  
