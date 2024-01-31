# output "user_ID" {
#   value = data.aws_iam_user.EKS_Admin_ID
# }

output "bastion_ip" {
  description = "bastion-nat public IP"
  value       = module.vpc.nat_bastion.public_ip
}
output "oidc_url" {
  description = "cluster_oidc_issuer_url"
  value       = module.eks.oidc_provider_arn
}

