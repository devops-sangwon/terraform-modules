resource "helm_release" "metric_server" {
  name            = "metric-server"
  repository      = "https://kubernetes-sigs.github.io/metrics-server"
  chart           = "metrics-server"
  version         = var.metric_server_version
  namespace       = "kube-system"
  cleanup_on_fail = true
  atomic          = true
  reset_values    = true
}