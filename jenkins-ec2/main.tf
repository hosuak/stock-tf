terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # 버전은 ~> 관계연산자 사용
    }
  }
}

provider "aws" {
  region  = "ap-northeast-2"
  profile = "tndk617"
}

resource "aws_vpc" "stock-vpc" {
  cidr_block           = "172.16.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "stock-vpc"
  }
}

variable "key_pair" {
  type    = string
  default = "ec2-boot-key"
}

resource "aws_subnet" "stock-vpc-public-subnet" {
  vpc_id            = aws_vpc.stock-vpc.id
  availability_zone = "ap-northeast-2c"
  cidr_block        = "172.16.1.0/24"
  tags = {
    Name = "stock-vpc-public-subnet"
  }
}


resource "aws_internet_gateway" "stock-vpc-igw" {
  vpc_id = aws_vpc.stock-vpc.id

  tags = {
    Name = "stock-vpc-igw"
  }
}

resource "aws_route_table" "stock-public-rt" {
  vpc_id = aws_vpc.stock-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.stock-vpc-igw.id
  }

  tags = {
    Name = "stock-public-rt"
  }
}

resource "aws_route_table_association" "stock-public-rt-association" {
  subnet_id      = aws_subnet.stock-vpc-public-subnet.id
  route_table_id = aws_route_table.stock-public-rt.id
}

resource "aws_instance" "jenkins-ec2" {
  ami                         = "ami-00b5066635986fa89"
  instance_type               = "t3.medium"
  key_name                    = var.key_pair
  subnet_id                   = aws_subnet.stock-vpc-public-subnet.id
  security_groups             = [aws_security_group.stock-private-sg.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 20
    volume_type = "gp2"
  }

  tags = {
    Name = "jenkins-ec2"
  }
}

resource "aws_security_group" "stock-private-sg" {
  name        = "allow_SSH_ICMP_HTTP"
  description = "Allow SSH/ICMP/HTTP inbound traffic"
  vpc_id      = aws_vpc.stock-vpc.id

  ingress {
    description = "SSH from All Network"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from All Network"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from All Network"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Custom Port (8080) from All Network"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ICMP from All Network"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "stock-private-sg"
  }
}

