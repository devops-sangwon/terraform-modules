variable "name" {
  type = string
}

variable "cluster_autoscaler_values" {
  default = {}
}
variable "cluster_autoscaler_version" { # chart version not application version
  default = "9.21.0"
}

variable "aws_load_balancer_controller_values" {
  default = {}
}

variable "aws_load_balancer_controller_version" {
  default = "1.4.7"
}

variable "external_dns_zones" {
  type = list(string)
}

variable "external_dns_values" {
  default = {}
}

variable "external_dns_version" {
  default = "6.13.1"
}

variable "metric_server_version" {
  default = "3.8.3"
}

variable "kubernetes_dashboard_values" {
  default = {}
}

variable "kubernetes_dashboard_domain" {
  default = ""
}

variable "kubernetes_dashboard_version" {
  default = "6.0.0"
}

variable "vault_enabled" {
  default = true
}

variable "vault_chart_name" {
  default = "vault"
}

variable "vault_version" {
  default = "0.22.0"
}

variable "vault_namespace" {
  default = "vault"
}

variable "vault_values" {
  default = {}
}
variable "vault_domain" {
  default = {}
}

variable "alb_waf_id" {
  default = ""
}

variable "domain_acm" {
  default = "arn:aws:acm:ap-northeast-2:002174788893:certificate/f56f4ce7-0c36-493f-b2cf-c9cc4944faa0"
}



variable "tags" {
  default = {}
}

variable "aws_region" {
  type    = string
  default = "ap-northeast-2"
}
variable "output_eks" {
  default = {}
}
variable "profile" {
  type = string
}

variable "provider_url" {
  type = string
}

variable "eks_cluster_name" {
  type = string
}
