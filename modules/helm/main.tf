terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.16.1"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.2"
    }
  }
}

locals {
  k8s_service_account_system_namespace = "kube-system"
  output_eks                           = var.output_eks
  profile                              = var.profile
}

data "aws_region" "region_name" {
  name = var.aws_region
}

data "aws_eks_cluster" "cluster" {
  name = var.eks_cluster_name
}

provider "helm" {
  kubernetes {
    host                   = local.output_eks.cluster_endpoint
    cluster_ca_certificate = base64decode(local.output_eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", local.output_eks.cluster_name, "--profile", local.profile]
    }
  }
}
