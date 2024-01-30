output "role_name" {
  description = "The name of the created IAM role"
  value = aws_iam_role.role.name
}
output "role_arn" {
  description = "The ARN of the created IAM role"
  value = aws_iam_role.role.arn
}
variable "policy_name" {
  type = string
  default = ""
  description = "The name of the created policy, if different from role name"
}
