output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "private_subnet_ids" {
  value = tomap({
    for k, subnet in aws_subnet.private_subnets : k => subnet.id
  })
}

