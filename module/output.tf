# output "user_ID" {
#   value = data.aws_iam_user.EKS_Admin_ID
# }

output "bastion_ip" {
  description = "bastion-nat public IP"
  value       = module.vpc.bastion.public_ip
}
output "oidc_url" {
  description = "cluster_oidc_issuer_url"
  value       = module.eks.oidc_provider_arn
}

output "efs_id" {
  description = "Id of the EFS file system."
  value       = module.efs.efs_id
}

# output "private_subnet" {
#   value = module.vpc.aws_subnet.private[*].id
# }
