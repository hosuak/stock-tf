################################################################################
# VPC
################################################################################

output "vpc_id" {
  value = aws_vpc.this[0].id
}

################################################################################
# Publiс Subnets
################################################################################
output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = aws_subnet.public[*].id
}
output "public_subnets_cidr_blocks" {
  description = "List of cidr_blocks of public subnets"
  value       = compact(aws_subnet.public[*].cidr_block)
}
################################################################################
# Private Subnets
################################################################################
output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = aws_subnet.private[*].id
}
output "private_subnets_cidr_blocks" {
  description = "List of cidr_blocks of private subnets"
  value       = compact(aws_subnet.private[*].cidr_block)
}

################################################################################
# VPC
################################################################################
output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = try(aws_vpc.this[0].cidr_block, null)
}
################################################################################
# Nat_instance
################################################################################
output "nat_bastion" {
  description = "Nat_bastion"
  value = {
    public_ip = aws_instance.nat_instance[*].public_ip
  }
}
output "bastion" {
  description = "Bastion Host"
  value       = { public_ip = aws_instance.bastion.public_ip }
}
