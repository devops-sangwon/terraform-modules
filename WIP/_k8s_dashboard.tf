resource "local_file" "kubernetes_dashboard" {
  filename = "values/kubernetes_dashboard.yml"
  content = yamlencode(merge({
    extraArgs = [
      "--token-ttl=1800",
      "--enable-insecure-login"
    ]
    protocolHttp = true
    ingress = {
      enabled = true
      annotations = {
        "alb.ingress.kubernetes.io/certificate-arn" = var.domain_acm
        "alb.ingress.kubernetes.io/inbound-cidrs"   = "0.0.0.0/0"
        "alb.ingress.kubernetes.io/listen-ports"    = "[{\"HTTPS\":443}]"
        "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
        # "alb.ingress.kubernetes.io/waf-acl-id"      = var.alb_waf_id
        "alb.ingress.kubernetes.io/target-type"     = "ip"
        "kubernetes.io/ingress.class"               = "alb"
      }
      hosts = [var.kubernetes_dashboard_domain]
      paths = [
        "/",
        "/*"
      ]
    }
  }, var.kubernetes_dashboard_values))
}

resource "helm_release" "kubernetes_dashboard" {
  name             = "kubernetes-dashboard"
  repository       = "https://kubernetes.github.io/dashboard"
  version          = var.kubernetes_dashboard_version
  chart            = "kubernetes-dashboard"
  namespace        = "kubernetes-dashboard"
  cleanup_on_fail  = true
  atomic           = true
  create_namespace = true
  reset_values     = true

  values = [local_file.kubernetes_dashboard.content]
}


resource "kubernetes_service_account" "dashboard" {
  metadata {
    name      = "k8s-admin"
    namespace = "kubernetes-dashboard"
  }

  depends_on = [helm_release.kubernetes_dashboard]
}

resource "kubernetes_cluster_role_binding" "dashboard" {
  metadata {
    name = "k8s-dashboard"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.dashboard.metadata[0].name
    namespace = helm_release.kubernetes_dashboard.namespace
  }
}