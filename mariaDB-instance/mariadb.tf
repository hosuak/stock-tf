locals {
  create_mariadb = var.create_mariadb_subnet
  create_rds = var.create_rds
  mariadb_count  = length(var.db_private_subnets)
  len_public_subnets  = max(length(var.db_public_subnets), length(var.public_subnet_ipv6_prefixes))
  len_private_subnets = max(length(var.db_private_subnets), length(var.private_subnet_ipv6_prefixes))

  # 다양한 서브넷 유형(IPv4 및 IPv6) 중 최대 서브넷 길이를 찾습니다.
  max_subnet_length = max(
    local.len_private_subnets,
    local.len_public_subnets,)
}
resource "aws_subnet" "db-private" {
  count = local.create_mariadb ? var.single_mariaDB ? 1 : length(var.db_private_subnets) : 0

  availability_zone = element(var.azs, count.index)
  cidr_block        = var.private_subnet_ipv6_native ? null : element(concat(var.db_private_subnets, [""]), count.index)
  vpc_id            = var.vpc_id

  tags = merge(
    {
      Name = try(
        var.private_subnet_names[count.index],
        format("${var.name}-db-private-%s", element(var.azs, count.index))
      )
    },
    var.tags,
    var.private_subnet_tags,
    lookup(var.private_subnet_tags_per_az, element(var.azs, count.index), {})
  )
}
locals {
  create_db_private_subnets = local.create_mariadb && local.len_private_subnets > 0
  create_mariadb_instance =   var.create_mariadb_instance  && local.create_db_private_subnets
}
resource "aws_route_table" "db-private" {
  count  = local.create_mariadb || local.create_db_private_subnets ? 1 : 0
  vpc_id = var.vpc_id  # 모듈 변수에서 VPC ID 가져오기

  # 다른 설정...

  tags = {
    Name = "DB-private-rt"
  }
}

resource "aws_route_table_association" "db-private" {
  count          = local.create_mariadb || local.create_db_private_subnets ? local.len_private_subnets : 0
  subnet_id      = element(aws_subnet.db-private[*].id, count.index)
  route_table_id = aws_route_table.db-private[0].id
}

resource "aws_security_group" "mariaDB-sg" {
  name        = "my-sg"
  description = "Allow HTTP, HTTPS"
  vpc_id      = var.vpc_id


  # SSH 규칙이 필요한 경우 생성
  dynamic "ingress" {
    for_each = var.ssh_enabled ? [1] : []
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  # ICMP와 MariaDB 규칙은 정적으로 생성
  ingress {
    description = "ICMP from All"
    from_port   = -1
    to_port     = -1
    protocol    = "ICMP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "MariaDB from All"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-mariaDB-sg"
  }
}
# data "local_file" "mariadb_setup" {
#   filename = "../aws_resource/mariadb_primary.sh" # apply 디렉토리 기준에서 잡아줘야한다.
# }

resource "aws_instance" "mariaDB-Master" {
  count                  = local.create_mariadb_instance ? 1 : 0 
  ami                    = var.mariaDB_Master_ami
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = element(aws_subnet.db-private[*].id, count.index % length(aws_subnet.db-private))
  vpc_security_group_ids = [aws_security_group.mariaDB-sg.id]
  
  tags = {
    Name = try(
      var.private_subnet_names[count.index],
      format("${var.name}-db-private-${var.db_name[0]}")
    )
  }
}
resource "aws_instance" "mariaDB-Slave" {
  count                  = local.create_mariadb_instance && !var.single_mariaDB ? 1 : 0
  ami                    = var.mariaDB_Slave_ami
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = element(aws_subnet.db-private[*].id, count.index % length(aws_subnet.db-private))
  vpc_security_group_ids = [aws_security_group.mariaDB-sg.id]
  
  tags = {
    Name = try(
      var.private_subnet_names[count.index],
      format("${var.name}-db-${var.db_name[1]}")
    )
  }
}
