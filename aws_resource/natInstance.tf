################################################################################
# NAT Instance
################################################################################

# locals {
#   nat_instance_count = var.single_nat_instance ? 1 : var.one_nat_instance_per_az ? length(var.azs) - 1 : local.max_subnet_length
# }

resource "aws_instance" "nat_instance" {
  count                       = local.create_vpc && var.enable_nat_instance && (var.single_nat_instance || !var.one_nat_instance_per_az) ? local.nat_instance_count : 0
  ami                         = var.nat_ami
  instance_type               = var.nat_intance_type
  source_dest_check           = false
  associate_public_ip_address = true

  subnet_id = element(aws_subnet.public[*].id, count.index % length(aws_subnet.public))

  vpc_security_group_ids = [aws_security_group.nat_instance_sg[0].id]

  key_name = count.index == 0 ? var.key_name : null

  tags = {
    Name = count.index == 0 ? "nat_bastion" : "nat_instance-${count.index}"
  }
}

resource "aws_security_group" "nat_instance_sg" {
  count       = local.create_vpc && var.enable_nat_instance ? 1 : 0
  name        = "nat_instance_sg"
  description = "Security group for NAT instances"
  vpc_id      = local.create_vpc ? aws_vpc.this[0].id : null

  ingress {
    description = "all"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "all"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "nat_instance_sg"
    # 추가적인 태그들을 여기에 추가할 수 있습니다.
  }
}
