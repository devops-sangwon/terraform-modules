resource "local_file" "kubecost" {
  count    = var.kubecost_enabled
  filename = "values/kubecost.yml"
  content = yamlencode(merge({
    prometheus = {
      nodeExporter = {
        enabled = false
      }
    }
    ingress = {
      enabled  = true
      pathType = "Prefix"
      annotations = {
        "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
        "alb.ingress.kubernetes.io/certificate-arn" = "${var.domain_acm}"
        "alb.ingress.kubernetes.io/listen-ports"    = "[{\"HTTPS\": 443}]"
        "alb.ingress.kubernetes.io/target-type"     = "ip"
        "external-dns.alpha.kubernetes.io/hostname" = var.external_dns_kubecost_hostname
        "kubernetes.io/ingress.class"               = "alb"
      }
      hosts = [var.kubecost_domain]
      paths = ["/"]
    }
  }, var.kubecost_values))
}

resource "helm_release" "kubecost" {
  count            = var.kubecost_enabled
  name             = "kubecost"
  chart            = "oci://public.ecr.aws/kubecost/cost-analyzer"
  version          = var.kubecost_version
  namespace        = var.kubecost_namespace
  cleanup_on_fail  = true
  atomic           = true
  reset_values     = true
  create_namespace = true
  values           = [local_file.kubecost.content]
  depends_on       = [local_file.kubecost]
}
