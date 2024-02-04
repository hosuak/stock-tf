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
  cluster_name    = "${var.namespace}-eks"
  cluster_version = "1.28"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets

  # OIDC(OpenID Connect) 구성 
  enable_irsa = true

  # EKS Worker Node 정의 ( ManagedNode방식 / Launch Template 자동 구성 )
  eks_managed_node_groups = {
    "${var.namespace}-worker" = {
      instance_types         = ["t3.medium"]
      min_size               = 2
      max_size               = 4
      desired_size           = 2
      vpc_security_group_ids = [module.add_node_sg.security_group_id]
      iam_role_additional_policies = {
        AmazonS3FullAccess           = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
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
  sa_name     = "ebs-csi-controller-sa"

  cluster_oidc_issuer_url = local.oidc_url
  depends_on              = [resource.kubernetes_namespace.namespace]
}
module "sa_role_policy_s3" {
  source = "../serviceAccount"

  policy_name = "AmazonS3CSIDriverPolicy"
  role_name   = "${var.initial}AmazonEKS_S3_CSI_DriverRole"
  namespace   = var.namespace
  sa_name     = "aws-mountpoint-s3-csi-sa"

  cluster_oidc_issuer_url = local.oidc_url
  depends_on              = [resource.kubernetes_namespace.namespace]
}
module "sa_role_policy_efs" {
  source = "../serviceAccount"

  policy_name = "AmazonEFSCSIDriverPolicy"
  role_name   = "${var.initial}AmazonEKS_EFS_CSI_DriverRole"
  namespace   = var.namespace
  sa_name     = "efs-csi-controller-sa"

  cluster_oidc_issuer_url = local.oidc_url
  depends_on              = [resource.kubernetes_namespace.namespace]
}
module "sa_role_policy_external-dns" {
  source = "../serviceAccount"

  policy_name = "ExternalDNSIAMPolicy"
  role_name   = "${var.initial}AmazonEKSExternalDNSRole"
  namespace   = var.namespace
  sa_name     = "external-dns"

  cluster_oidc_issuer_url = local.oidc_url
  depends_on              = [resource.kubernetes_namespace.namespace]
}
module "sa_role_policy_lb" {
  source = "../serviceAccount"

  policy_name = "AWSLoadBalancerControllerIAMPolicy"
  role_name   = "${var.initial}AmazonEKSLoadBalancerControllerRole"
  namespace   = var.namespace
  sa_name     = "aws-load-balancer-controller"

  cluster_oidc_issuer_url = local.oidc_url
  depends_on              = [resource.kubernetes_namespace.namespace]
}

# module "db" {
#   source = "terraform-aws-modules/rds/aws"

#   create_db_instance = false

#   identifier = "stock-city"

#   engine            = "mariadb"
#   engine_version    = "10.6.16"
#   instance_class    = "db.t3a.large"
#   allocated_storage = 5

#   db_name  = "demo"
#   username = "admin"
#   port     = "3306"

#   iam_database_authentication_enabled = true

#   vpc_security_group_ids = ["${module.add_node_sg.security_group_id}"]

#   # maintenance_window = "Mon:00:00-Mon:03:00"
#   # backup_window      = "03:00-06:00"

#   # Enhanced Monitoring - see example for details on how to create the role
#   # by yourself, in case you don't want to create it automatically
#   monitoring_interval    = "30"
#   monitoring_role_name   = "MyRDSMonitoringRole"
#   create_monitoring_role = true

#   tags = {
#     Owner       = "user"
#     Environment = "dev"
#   }

#   # DB subnet group
#   create_db_subnet_group = true
#   subnet_ids             = ["${module.vpc.private_subnets[0]}", "${module.vpc.private_subnets[1]}"]

#   # DB parameter group
#   family = "mariadb10.6.16" # 이 부분을 MariaDB 버전에 맞게 수정하세요.

#   # Database Deletion Protection
#   deletion_protection = false

#   parameters = [
#     {
#       name  = "character_set_client"
#       value = "utf8mb4"
#     },
#     {
#       name  = "character_set_server"
#       value = "utf8mb4"
#     }
#   ]

#   options = [
#     {
#       option_name = "MARIADB_AUDIT_PLUGIN"

#       option_settings = [
#         {
#           name  = "SERVER_AUDIT_EVENTS"
#           value = "CONNECT"
#         },
#         {
#           name  = "SERVER_AUDIT_FILE_ROTATIONS"
#           value = "37"
#         },
#       ]
#     },
#   ]
# }




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


