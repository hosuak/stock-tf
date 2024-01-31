variable "EKS_Admin_ID" { # IAM 사용자 
  description = "Who's EKS_Admin?"
  type        = string
  default     = "DAS"
}
variable "profile_name" { # vscode profile
  description = "Who's profile_name?"
  type        = string
  default     = "admin"
}
variable "key_name" {
  description = "Who's EKS_Admin?"
  type        = string
  default     = "ec2-boot-key"
}

variable "initial" {
  description = "What is your initail?"
  type        = string
  default     = "dh-"
}
