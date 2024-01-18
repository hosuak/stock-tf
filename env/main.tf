# terraform {
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = "~> 5.0"
#     }
#   }
# }
# provider "aws" {
#   region  = "ap-northeast-2"
#   profile = "admin"
# }

module "vpc" {

  # ------------------------------------------------------------------------------------------------------------------------------ 기본 VPC 설정
  source = "../aws_resource"
  name   = "stock"
  # cidr            = "172.16.0.0/16"                        # default = "10.0.0.0/16"
  # azs             = ["ap-northeast-2a", "ap-northeast-2c"] # default =  ["ap-northeast-2a", "ap-northeast-2c"]
  # private_subnets = ["172.16.1.0/24", "172.16.3.0/24"]     # default = ["10.0.10.0/24", "10.0.20.0/24"]
  # public_subnets  = ["172.16.101.0/24", "172.16.103.0/24"] # default = ["10.0.110.0/24", "10.0.120.0/24"]

  # ------------------------------------------------------------------------------------------------------------------------------ NAT 설정 
  # ※ "0.0.0.0/0"으로 향하는 라우트가 이미 라우팅 테이블에 존재하면 생성 충돌이 나기 때문에 -> Nat Instance 와 Nat Gateway는 같이 사용이 불가능하다.
  # 
  # ※ Gateway 와 Instance 변경적용은 안되기에 라우팅 테이블을 삭제하길 요망 
  # -> terraform state rm 'module.vpc.aws_route_table.private' -> true,false 설정후->  terraform apply
  # 

  # Nat GateWay 설정
  enable_nat_gateway = false # NAT GATWAY 생성시 default = false 이다.
  single_nat_gateway = true  # default = false 

  # Nat Instance 설정(Amazon Linux)
  enable_nat_instance = true # NAT INSTANCE 생성시 default = false 이다.
  single_nat_instance = true # default = false  # false 면 public 가용영역별로 Nat instance생성 그중 한개는 bastion
  # ------------------------------------------------------------------------------------------------------------------------------ 마리아DB 설정
  # Maria DB 여는 설정
  create_mariadb = true
  ssh_enabled    = true # db_ssh 보안그룹을 여는 옵션 default = false
  # db_private_subnets = ["172.16.201.0/24", "172.16.202.0/24"] # default = ["10.0.210.0/24", "10.0.220.0/24"]
  # dataBase_name = "demo"      # default = demo
  # db_username   = "admin"     # default = admin
  # db_password   = "mariapass" # default = mariapass
}
