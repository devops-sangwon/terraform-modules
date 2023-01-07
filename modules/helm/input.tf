variable "name" {
  type = string
}

variable "cluster_autoscaler_values" {
  default = {}
}
variable "cluster_autoscaler_version" { # chart version not application version
  default = "9.21.0"
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
