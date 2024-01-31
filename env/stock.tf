#############################################
# VPC module
#############################################

module "vpc" {

  # ------------------------------------------------------------------------------------------------------------------------------ 기본 VPC 설정
  source          = "../aws_resource"
  name            = "${var.initial}stock-vpc"
  cidr            = "192.168.0.0/16"                         # default = "10.0.0.0/16"
  azs             = ["ap-northeast-2a", "ap-northeast-2c"]   # default =  ["ap-northeast-2a", "ap-northeast-2c"]
  private_subnets = ["192.168.1.0/24", "192.168.3.0/24"]     # default = ["10.0.10.0/24", "10.0.20.0/24"]
  public_subnets  = ["192.168.101.0/24", "192.168.103.0/24"] # default = ["10.0.110.0/24", "10.0.120.0/24"]

  # ------------------------------------------------------------------------------------------------------------------------------ NAT 설정 
  # ※ "0.0.0.0/0"으로 향하는 라우트가 이미 라우팅 테이블에 존재하면 생성 충돌이 나기 때문에 -> Nat Instance 와 Nat Gateway는 같이 사용이 불가능하다.
  # 
  # ※ Gateway 와 Instance 변경적용은 안되기에 라우팅 테이블을 삭제하길 요망 
  # -> terraform state rm 'module.vpc.aws_route_table.private' -> true,false 설정후->  terraform apply
  # 

  # Nat GateWay 설정  - enable_nat_gateway 일경우 bastion-instance가 생기게 된다.
  enable_nat_gateway = false # NAT GATWAY 생성시 default = false 이다.
  single_nat_gateway = true  # default = false 


  # Nat Instance 설정(Amazon Linux)
  enable_nat_instance = true # NAT INSTANCE 생성시 default = false 이다.
  single_nat_instance = true # default = false  # false 면 public 가용영역별로 Nat instance생성 그중 한개는 bastion
}


#############################################
# EKS module
#############################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  # EKS Cluster Setting
  cluster_name    = "${var.initial}eks"
  cluster_version = "1.28"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets

  # OIDC(OpenID Connect) 구성 
  enable_irsa = true # default = true 이다.

  # EKS Worker Node 정의 ( ManagedNode방식 / Launch Template 자동 구성 )
  eks_managed_node_groups = {
    "${var.initial}worker" = {
      instance_types         = ["t3.medium"]
      min_size               = 3
      max_size               = 3
      desired_size           = 3
      vpc_security_group_ids = [module.add_node_sg.security_group_id]
      iam_role_additional_policies = {
        AmazonS3FullAccess           = "arn:aws:iam::aws:policy/AmazonS3FullAccess",
        AmazonEKS_EFS_CSI_DriverRole = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
        AmazonEBSCSIDriverPolicy     = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }
    }
  }

  # public-subnet(bastion)과 API와 통신하기 위해 설정(443)
  cluster_additional_security_group_ids = [module.add_cluster_sg.security_group_id]
  cluster_endpoint_public_access        = true

  # K8s ConfigMap Object "aws_auth" 구성
  manage_aws_auth_configmap = true
  aws_auth_users = [
    {
      userarn  = "${data.aws_iam_user.EKS_Admin_ID.arn}"
      username = "${data.aws_iam_user.EKS_Admin_ID.user_name}"
      groups   = ["system:masters"]
    },
  ]
}
data "aws_iam_user" "EKS_Admin_ID" {
  user_name = var.EKS_Admin_ID # EKS_Admin_ID = 입력값으로 생성
}

data "aws_key_pair" "ec2-key" {
  key_name = var.key_name # default = ec2-boot-key
}


#-----------------------------------------------------------------------------------------------
module "add_cluster_sg" {
  source      = "terraform-aws-modules/security-group/aws"
  version     = "~> 5.0"
  name        = "add_cluster_sg"
  description = "add_cluster_sg"

  vpc_id          = module.vpc.vpc_id
  use_name_prefix = false

  ingress_with_cidr_blocks = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = module.vpc.vpc_cidr_block
    }
  ]
  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}
module "add_node_sg" {
  source      = "terraform-aws-modules/security-group/aws"
  version     = "~> 5.0"
  name        = "add_node_sg"
  description = "add_node_sg"

  vpc_id          = module.vpc.vpc_id
  use_name_prefix = false

  ingress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = module.vpc.vpc_cidr_block
    }
  ]
  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}
// Private Subnet Tag ( AWS Load Balancer Controller Tag / internal )
resource "aws_ec2_tag" "private_subnet_tag1" {
  resource_id = module.vpc.private_subnets[0]
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}
resource "aws_ec2_tag" "private_subnet_tag2" {
  resource_id = module.vpc.private_subnets[1]
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}

// Public Subnet Tag ( AWS Load Balancer Controller Tag / internet-facing )
resource "aws_ec2_tag" "public_subnet_tag1" {
  resource_id = module.vpc.public_subnets[0]
  key         = "kubernetes.io/role/elb"
  value       = "1"
}
resource "aws_ec2_tag" "public_subnet_tag2" {
  resource_id = module.vpc.public_subnets[1]
  key         = "kubernetes.io/role/elb"
  value       = "1"
}
##########################################################################
# kubernetes-serviceAccount-Role-Policy
##########################################################################
locals {
  oidc_url = try(module.eks.oidc_provider_arn, null)

}
resource "kubernetes_namespace" "namespace" {
  metadata {
    name = var.namespace
  }
}

module "sa_role_policy_ebs" {
  source = "../serviceAccount"

  policy_name = "AmazonEBSCSIDriverPolicy"
  role_name   = "${var.initial}AmazonEKS_EBS_CSI_DriverRole"
  namespace   = var.namespace
  sa_name     = "aws-mountpoint-s3-csi-driverte"

  cluster_oidc_issuer_url = local.oidc_url

}
module "sa_role_policy_s3" {
  source = "../serviceAccount"

  policy_name = "AmazonS3CSIDriverPolicy"
  role_name   = "${var.initial}AmazonEKS_S3_CSI_DriverRole"
  namespace   = var.namespace
  sa_name     = "ebs-csi-controller-sa"

  cluster_oidc_issuer_url = local.oidc_url

}
module "sa_role_policy_external-dns" {
  source = "../serviceAccount"

  policy_name = "ExternalDNSIAMPolicy"
  role_name   = "${var.initial}AmazonEKSExternalDNSRole"
  namespace   = var.namespace
  sa_name     = "external-dns"

  cluster_oidc_issuer_url = local.oidc_url

}
module "sa_role_policy_lb" {
  source = "../serviceAccount"

  policy_name = "AWSLoadBalancerControllerIAMPolicy"
  role_name   = "${var.initial}AmazonEKSLoadBalancerControllerRole"
  namespace   = var.namespace
  sa_name     = "aws-load-balancer-controller"

  cluster_oidc_issuer_url = local.oidc_url

}




















# module "mariaDB" {
#   source = "../mariaDB-instance"
#   name   = "stock"
#   vpc_id = module.vpc.vpc_id # default = module.vpc.vpc_id
#   # ------------------------------------------------------------------------------------------------------------------------------ 마리아DB 설정
#   # Maria DB 여는 설정
#   single_mariaDB          = false # default = false
#   create_mariadb_subnet   = false # deafault = false 
#   ssh_enabled             = false # db_ssh 보안그룹을 여는 옵션 default = false
#   create_mariadb_instance = false # default = false 
#   # db_private_subnets = ["172.16.201.0/24", "172.16.202.0/24"] # default = ["10.0.210.0/24", "10.0.220.0/24"]
#   # dataBase_name = "demo"      # default = demo
#   # db_username   = "admin"     # default = admin
#   # db_password   = "mariapass" # default = mariapass
# }


