# output "user_ID" {
#   value = data.aws_iam_user.EKS_Admin_ID
# }

output "bastion_ip" {
  description = "bastion-nat public IP"
  value       = module.vpc.nat_bastion.public_ip
}


