

variable "role_name" {
  type        = string
  default     = ""
  description = "The name of the role to create, if different from $name"
}

variable "role_tags" {
  type        = map(any)
  default     = {}
  description = "AWS tags to add to the created IAM role"
}

variable "cluster_oidc_issuer_url" {
  type        = string
  description = "The Cluster OIDC Issuer URL (for example, per the cluster_oidc_issuer_url output on the official EKS terraform module at https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest?tab=outputs)"
}
variable "namespace" {
  type        = string
  default     = "default"
  description = "The namespace in Kubernetes under which to create the service account"
}

variable "name" {
  type        = string
  description = "The name of the created service account in Kubernetes"
}
variable "policy_json" {
  type        = string
  default     = ""
  description = "If provided, create and attach a policy to the role"
}


variable "automount_service_account_token" {
  type        = bool
  default     = true
  description = "Whether to set automountServiceAccountToken on the created service account in Kubernetes"
}
variable "policy_arns" {
  type = list(string)
  default = []
  description = "A list of ARNs of policies to attach to the role"
}