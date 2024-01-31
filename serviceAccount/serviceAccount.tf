data "aws_caller_identity" "current" {}
data "aws_iam_policy" "selected_policy" {
  name = var.policy_name
}

locals {
  oidc_issuer_domain = var.cluster_oidc_issuer_url
  role_name          = var.role_name != "" ? var.role_name : var.sa_name
}
resource "kubernetes_namespace" "example" {
  metadata {
    name = var.namespace
  }
}

data "aws_iam_policy_document" "service_account_assume_role" {
  statement {
    principals {
      type        = "Federated"
      identifiers = ["${local.oidc_issuer_domain}"]
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
        "system:serviceaccount:${var.namespace}:${var.sa_name}"
      ]
    }

  }
}

resource "aws_iam_role" "role" {
  name                  = local.role_name
  force_detach_policies = true
  assume_role_policy    = data.aws_iam_policy_document.service_account_assume_role.json
  tags = {
    Name = local.role_name
  }
}

resource "aws_iam_role_policy_attachment" "policy_attachment" {
  count      = var.policy_name != "" ? 1 : 0
  role       = aws_iam_role.role.name
  policy_arn = data.aws_iam_policy.selected_policy.arn
}


resource "kubernetes_service_account" "service_account" {
  metadata {
    name      = var.sa_name
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/component" = "controller"
      "app.kubernetes.io/name"      = var.sa_name
    }
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.role.arn
    }
  }

  automount_service_account_token = var.automount_service_account_token
}


