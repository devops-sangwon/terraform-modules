module "iam_role_external_dns" {
  providers = {
    aws = aws.dev
  }
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "5.10.0"
  create_role                   = true
  role_name                     = "external-dns-${var.eks_cluster_name}"
  provider_url                  = var.provider_url
  role_policy_arns              = [module.iam_policy_external_dns.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:${local.k8s_service_account_system_namespace}:external-dns"]
  depends_on                    = [module.iam_policy_external_dns]
}

# resource "aws_iam_openid_connect_provider" "cross_account_dns" {
#   provider        = aws.dev
#   url             = "https://${var.provider_url}"
#   client_id_list  = ["sts.amazonaws.com"]
#   thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]
# }

data "aws_route53_zone" "external_dns" {
  provider = aws.dev
  count    = length(var.external_dns_zones)
  name     = var.external_dns_zones[count.index]
}

module "iam_policy_external_dns" {
  source      = "terraform-aws-modules/iam/aws//modules/iam-policy"
  name        = "external_dns-${var.eks_cluster_name}"
  path        = "/"
  description = "EKS external_dns policy in ${var.eks_cluster_name}"

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "route53:ChangeResourceRecordSets"
        ],
        "Resource": ${jsonencode(formatlist("arn:aws:route53:::hostedzone/%s", data.aws_route53_zone.external_dns[*].zone_id))}
      },
      {
        "Effect": "Allow",
        "Action": [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets"
        ],
        "Resource": [
          "*"
        ]
      }
    ]
  }
  EOF
}


resource "local_file" "external_dns" {
  filename = "values/external_dns.yml"
  content = yamlencode(merge({
    provider   = "aws"
    registry   = "txt"
    txtOwnerId = var.name
    aws = {
      region   = var.aws_region
      zoneType = "public"
    }
    domainFilters = var.external_dns_zones
    serviceAccount = {
      name = "external-dns"
      annotations = {
        "eks.amazonaws.com/role-arn" : module.iam_role_external_dns.iam_role_arn
      }
    }
    sources = [
      "service",
      "ingress",
    ]
  }, var.external_dns_values))
}

resource "helm_release" "external_dns" {
  name            = "external-dns"
  repository      = "https://charts.bitnami.com/bitnami"
  version         = var.external_dns_version
  chart           = "external-dns"
  namespace       = "kube-system"
  cleanup_on_fail = true
  atomic          = true
  reset_values    = true

  values = [local_file.external_dns.content]
}