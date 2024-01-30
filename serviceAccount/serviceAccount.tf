data "aws_caller_identity" "current" {}

locals {
  oidc_issuer_domain = replace(var.cluster_oidc_issuer_url, "https://", "")
  role_name          = var.role_name != "" ? var.role_name : var.name
}

data "aws_iam_policy_document" "service_account_assume_role" {
  statement {
    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.oidc_issuer_domain}"]
    }
    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]
    condition {
    test     = "StringEquals"
    variable = "${local.oidc_issuer_domain}:aud"

    values = [
      "sts.amazonaws.com"
    ]
  }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_domain}:sub"

      values = [
        "system:serviceaccount:${var.namespace}:${var.name}"
      ]
    }
    
  }
}

resource "aws_iam_role" "role" {
  name                  = local.role_name
  force_detach_policies = true
  assume_role_policy    = data.aws_iam_policy_document.service_account_assume_role.json
  tags                  = var.role_tags
}
resource "kubernetes_service_account" "service_account" {
  metadata {
    name      = var.name
    namespace = var.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.role.arn
    }
  }
  # Kubernetes 서비스 어카운트의 토큰 자동 마운트 여부를 제어
  automount_service_account_token = var.automount_service_account_token
}

resource "aws_iam_policy" "policy" {
  count       = var.policy_json != "" ? 1 : 0
  name        = var.policy_name != "" ? var.policy_name : local.role_name
  description = "Policy used by the role ${aws_iam_role.role.name}"

  policy = var.policy_json
}

resource "aws_iam_role_policy_attachment" "policy_attachment" {
  count      = var.policy_json != "" ? 1 : 0
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.policy[0].arn
}

resource "aws_iam_role_policy_attachment" "external_policy_attachments" {
  for_each = toset(var.policy_arns)
  policy_arn = each.key
  role = aws_iam_role.role.name
}


# locals {
#   policy_json_file = "path/to/your/file.json"
#   policy_json      = jsondecode(file(local.policy_json_file))
# }

# variable "policy_json" {
#   type        = any
#   default     = local.policy_json
#   description = "If provided, create and attach a policy to the role"
# }