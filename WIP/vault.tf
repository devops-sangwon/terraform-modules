module "iam_role_vault" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "5.10.0"
  create_role                   = true
  role_name                     = "vault"
  provider_url                  = var.provider_url
  role_policy_arns              = [module.iam_policy_vault.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:${var.vault_namespace}:vault"]
  depends_on                    = [module.iam_policy_vault]
}

module "iam_policy_vault" {
  count       = var.vault_enabled ? 1 : 0
  source      = "terraform-aws-modules/iam/aws//modules/iam-policy"
  name        = "vault-${var.eks_cluster_name}"
  path        = "/"
  description = "EKS vault policy in ${var.eks_cluster_name}"
  policy      = <<-EOF
  {
      "Version": "2012-10-17",
      "Statement": [
          {
              "Effect": "Allow",
              "Action": [
                  "kms:Encrypt",
                  "kms:DescribeKey",
                  "kms:Decrypt"
              ],
              "Resource": "${aws_kms_key.vault.arn}"
          },
          {
              "Effect": "Allow",
              "Action": [
                  "dynamodb:ListTables",
                  "dynamodb:DescribeLimits",
                  "dynamodb:DescribeTimeToLive",
                  "dynamodb:ListTagsOfResource",
                  "dynamodb:DescribeReservedCapacityOfferings",
                  "dynamodb:DescribeReservedCapacity",
                  "dynamodb:ListTables",
                  "dynamodb:BatchGetItem",
                  "dynamodb:BatchWriteItem",
                  "dynamodb:CreateTable",
                  "dynamodb:DeleteItem",
                  "dynamodb:GetItem",
                  "dynamodb:GetRecords",
                  "dynamodb:PutItem",
                  "dynamodb:Query",
                  "dynamodb:UpdateItem",
                  "dynamodb:Scan",
                  "dynamodb:DescribeTable"
              ],
              "Resource": "${aws_dynamodb_table.vault.arn}"
          }
      ]
  }
  EOF
}

resource "local_file" "vault" {
  filename = "values/vault.yml"
  content = yamlencode({
    server = merge({
      dev = {
        enabled = false
      }
      injector = {
        enabled = true
      }
      service = {
        enabled = true
        type    = "NodePort"
      }

      ingress = {
        enabled  = true
        pathType = "Prefix"
        "labels" = {
          "project" = "eks-cost-project-dev"
          "OWNER"   = "EleSangwon"
        }
        "annotations" = {
          "kubernetes.io/ingress.class"                = "alb"
          "alb.ingress.kubernetes.io/certificate-arn"  = "${var.domain_acm}"
          "alb.ingress.kubernetes.io/listen-ports"     = "[{\"HTTPS\": 443}]"
          "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
          "alb.ingress.kubernetes.io/healthcheck-path" = "/v1/sys/health?standbyok=true"
        }
        "hosts" = [{
          "host"  = "${var.vault_domain}"
          "paths" = ["/"]
        }]
      }

      serviceAccount = {
        annotations = {
          "eks.amazonaws.com/role-arn" : module.iam_role_vault.iam_role_arn
        }
      }

      ha = {
        enabled  = true
        replicas = 3
        config   = <<-EOF
            ui = true
            listener "tcp" {
              tls_disable = 1
              address = "[::]:8200"
              cluster_address = "[::]:8201"
            }
            storage "dynamodb" {
              ha_enabled = "true"
              region     = "ap-northeast-2"
              table      = "${aws_dynamodb_table.vault.id}"
            }
            service_registration "kubernetes" {}
            seal "awskms" {
              region = "ap-northeast-2"
              kms_key_id = "${aws_kms_key.vault.key_id}"
            }
        EOF
      }
    }, var.vault_values)
  })
}


resource "helm_release" "vault" {
  count            = var.vault_enabled ? 1 : 0
  name             = var.vault_chart_name
  repository       = "https://helm.releases.hashicorp.com"
  chart            = "vault"
  version          = var.vault_version
  namespace        = var.vault_namespace
  cleanup_on_fail  = true
  atomic           = true
  create_namespace = "true"

  values = [local_file.vault.content]
}

resource "aws_dynamodb_table" "vault" {
  count        = var.vault_enabled ? 1 : 0
  name         = "vault-in-${var.eks_cluster_name}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "Path"
  range_key    = "Key"
  attribute {
    name = "Path"
    type = "S"
  }
  attribute {
    name = "Key"
    type = "S"
  }

  tags = var.tags
}

resource "aws_kms_key" "vault" {
  count       = var.vault_enabled ? 1 : 0
  description = "Vault KMS key in ${var.eks_cluster_name}"
  tags        = var.tags
}
resource "aws_kms_alias" "vault" {
  count         = var.vault_enabled ? 1 : 0
  name          = "alias/vault-${var.eks_cluster_name}"
  target_key_id = aws_kms_key.vault.key_id
  depends_on    = [aws_kms_key.vault]
}
