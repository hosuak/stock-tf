################################################################################
# MariaDB
################################################################################

variable "create_mariadb_subnet" {
  description = "Controls if MariaDB should be created (it affects almost all resources)"
  type        = bool
  default     = false
}

variable "mariaDB_Master_ami" {
  description = "AMI ID for MariaDB instances"
  type        = string
  default     = "ami-04c46553eb65eb778"
}
variable "mariaDB_Slave_ami" {
  description = "AMI ID for MariaDB instances"
  type        = string
  default     = "ami-06d1e640f75bbe41e"
}
variable "instance_type" {
  description = "Instance type for MariaDB instances"
  type        = string
  default     = "t2.micro"
}

variable "single_mariaDB" {
  description = "Controls if a single MariaDB instance should be created"
  type        = bool
  default     = false
}

variable "db_name" {
  description = "List of database names"
  type        = list(string)
  default     = ["Master", "Slave"]
}

variable "ssh_enabled" {
  description = "Controls if SSH access should be enabled"
  type        = bool
  default     = false
}

variable "root_password" {
  description = "Root password for MariaDB"
  type        = string
  default     = "rootpass"
}

variable "dataBase_name" {
  description = "Database username"
  type        = string
  default     = "demo"
}
variable "db_username" {
  description = "Database username"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Database user password"
  type        = string
  default     = "mariapass"
}

variable "db_private_subnets" {
  type    = list(string)
  default = ["10.0.210.0/24", "10.0.220.0/24"]
}
variable "db_public_subnets" {
  description = "A list of public subnets inside the VPC"
  type        = list(string)
  default     = ["10.0.230.0/24", "10.0.240.0/24"]
}
################################################################################
# 
################################################################################
variable "create_mariadb_instance"{
  type        = bool
  default     = false
}
variable "key_name" {
  description = "Name of the EC2 key pair to associate with instances. Set to null if you don't want to associate a key pair."
  type        = string
  default     = "ec2-boot-key"
}

variable "name" {
  description = "Name to be used on all the resources as identifier"
  type        = string
  default     = ""
}
variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
variable "private_subnet_tags" {
  description = "Additional tags for the private subnets"
  type        = map(string)
  default     = {}
}
variable "private_subnet_tags_per_az" {
  description = "Additional tags for the private subnets where the primary key is the AZ"
  type        = map(map(string))
  default     = {}
}
variable "private_subnet_ipv6_native" {
  description = "Indicates whether to create an IPv6-only subnet. Default: `false`"
  type        = bool
  default     = false
}
variable "private_subnet_names" {
  description = "Explicit values to use in the Name tag on private subnets. If empty, Name tags are generated"
  type        = list(string)
  default     = []
}
variable "azs" {
  description = "A list of availability zones names or ids in the region"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
}
variable "public_subnet_ipv6_prefixes" {
  description = "Assigns IPv6 public subnet id based on the Amazon provided /56 prefix base 10 integer (0-256). Must be of equal length to the corresponding IPv4 subnet list"
  type        = list(string)
  default     = []
}
variable "private_subnet_ipv6_prefixes" {
  description = "Assigns IPv6 private subnet id based on the Amazon provided /56 prefix base 10 integer (0-256). Must be of equal length to the corresponding IPv4 subnet list"
  type        = list(string)
  default     = []
}
variable "vpc_id" {
  type = string
  default = "module.vpc.vpc_id"
}

################################################################################
# RDS
################################################################################

variable "create_rds" {
  description = "Controls if MariaDB should be created (it affects almost all resources)"
  type        = bool
  default     = false
}

