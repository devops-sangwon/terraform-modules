module "iam_role_cluster_autoscaler" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "5.10.0"
  create_role                   = true
  role_name                     = "cluster-autoscaler"
  provider_url                  = var.provider_url
  role_policy_arns              = [module.iam_policy_cluster_autoscaler.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:${local.k8s_service_account_system_namespace}:aws-cluster-autoscaler"]
  depends_on                    = [module.iam_policy_cluster_autoscaler]
}

module "iam_policy_cluster_autoscaler" {
  source      = "terraform-aws-modules/iam/aws//modules/iam-policy"
  name        = "cluster-autoscaler-${var.eks_cluster_name}"
  path        = "/"
  description = "EKS cluster-autoscaler policy in ${var.eks_cluster_name}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "ec2:DescribeLaunchTemplateVersions",
                "autoscaling:DescribeTags",
                "autoscaling:DescribeLaunchConfigurations",
                "autoscaling:DescribeAutoScalingInstances",
                "autoscaling:DescribeAutoScalingGroups"
            ],
            "Effect": "Allow",
            "Resource": "*",
            "Sid": "clusterAutoscalerAll"
        },
        {
            "Action": [
                "autoscaling:UpdateAutoScalingGroup",
                "autoscaling:TerminateInstanceInAutoScalingGroup",
                "autoscaling:SetDesiredCapacity"
            ],
            "Condition": {
                "StringEquals": {
                    "autoscaling:ResourceTag/k8s.io/cluster-autoscaler/enabled": "true",
                    "autoscaling:ResourceTag/kubernetes.io/cluster-autoscaler/${var.eks_cluster_name}": "owned"
                }
            },
            "Effect": "Allow",
            "Resource": "*",
            "Sid": "clusterAutoscalerOwn"
        }
    ]
}
EOF
}


resource "local_file" "cluster_autoscaler" {
  filename = "values/cluster_autoscaler.yaml"
  content = yamlencode(merge({
    awsRegion = var.aws_region
    autoDiscovery = {
      clusterName = var.eks_cluster_name
    }
    extraArgs = {
      "balance-similar-node-groups"   = "true"
      "skip-nodes-with-system-pods"   = "false"
      "skip-nodes-with-local-storage" = "false"
    }
    rbac = {
      create = true
      serviceAccount = {
        name = "aws-cluster-autoscaler"
        annotations = {
          "eks.amazonaws.com/role-arn" = module.iam_role_cluster_autoscaler.iam_role_arn
        }
      }
    }
  }, var.cluster_autoscaler_values))
}

resource "helm_release" "cluster_autoscaler" {
  name            = "autoscaler"
  chart           = "autoscaler/cluster-autoscaler"
  version         = var.cluster_autoscaler_version
  namespace       = "kube-system"
  cleanup_on_fail = true
  atomic          = true
  reset_values    = true
  values          = [local_file.cluster_autoscaler.content]
}