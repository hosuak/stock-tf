locals {
  create_mariadb = var.create_mariadb
  mariadb_count  = length(var.db_private_subnets)
}
resource "aws_subnet" "db-private" {
  count = local.create_mariadb ? var.single_mariaDB ? 1 : length(var.db_private_subnets) : 0

  availability_zone = element(var.azs, count.index)
  cidr_block        = var.private_subnet_ipv6_native ? null : element(concat(var.db_private_subnets, [""]), count.index)
  vpc_id            = aws_vpc.this[0].id

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

resource "aws_route_table_association" "db-private" {
  count          = local.create_mariadb && local.create_private_subnets ? local.len_private_subnets : 0
  subnet_id      = element(aws_subnet.db-private[*].id, count.index)
  route_table_id = element(aws_route_table.private[*].id, var.single_nat_gateway ? 0 : count.index)
}

resource "aws_security_group" "mariaDB-sg" {
  name        = "my-sg"
  description = "Allow HTTP, HTTPS"
  vpc_id      = aws_vpc.this[0].id


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

resource "aws_instance" "mariaDB" {
  count                  = local.create_mariadb ? var.single_mariaDB ? 1 : 2 : 0
  ami                    = var.mariaDB_ami
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = element(aws_subnet.db-private[*].id, count.index % length(aws_subnet.db-private))
  vpc_security_group_ids = [aws_security_group.mariaDB-sg.id]
  user_data = base64encode(<<-EOF
              #!/bin/bash
              apt update
              apt upgrade -y
              apt install -y mariadb-server-10.6
              
      
              cat <<EOL > /etc/mysql/my.cnf
[client-server]
port = 3306
socket = /run/mysqld/mysqld.sock
!includedir /etc/mysql/conf.d/
!includedir /etc/mysql/mariadb.conf.d/

[client]
character-sets-dir = utf8

[mysqld]
init_connect=SET collation_connection = utf8_general_ci
init_connect=SET NAMES utf8
character-set-server = utf8
collation-server = utf8_general_ci
general_log = 1
general_log_file = /var/log/mariadb/general.log
log_error = /var/log/mariadb/error.log
max_connections = 300

[mysqldump]
default-character-set = utf8

[mysql]
default-character-set = utf8
EOL
              
              
              systemctl daemon-reload
              systemctl restart mariadb.service
              
              
              systemctl enable mariadb
              
              mysql -u root <<-EOSQL
                ALTER USER 'root'@'localhost' IDENTIFIED BY '${var.root_password}';
                DELETE FROM mysql.user WHERE User='';
                DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
                DROP DATABASE IF EXISTS test;
                DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';
                FLUSH PRIVILEGES;
                CREATE DATABASE ${var.dataBase_name};
                CREATE USER '${var.db_username}'@'%' IDENTIFIED BY '${var.db_password}';
                GRANT ALL PRIVILEGES ON *.* TO '${var.db_username}'@'%' WITH GRANT OPTION;
              EOSQL
              EOF
  )
  tags = {
    Name = try(
      var.private_subnet_names[count.index],
      format("${var.name}-db-private-%s", element(var.db_name, count.index))
    )
  }
}
