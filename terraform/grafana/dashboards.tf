resource "grafana_dashboard" "cluster_logs" {
  folder      = grafana_folder.observability.uid
  config_json = file("${path.module}/dashboards/cluster-logs.json")
  overwrite   = true
}

resource "grafana_dashboard" "otelcol_health" {
  folder      = grafana_folder.observability.uid
  config_json = file("${path.module}/dashboards/otelcol-health.json")
  overwrite   = true
}

resource "grafana_dashboard" "cilium_health" {
  folder      = grafana_folder.infrastructure.uid
  config_json = file("${path.module}/dashboards/cilium-health.json")
  overwrite   = true
}

resource "grafana_dashboard" "coredns_health" {
  folder      = grafana_folder.infrastructure.uid
  config_json = file("${path.module}/dashboards/coredns-health.json")
  overwrite   = true
}

resource "grafana_dashboard" "metrics_server_health" {
  folder      = grafana_folder.infrastructure.uid
  config_json = file("${path.module}/dashboards/metrics-server-health.json")
  overwrite   = true
}

resource "grafana_dashboard" "nfd_health" {
  folder      = grafana_folder.infrastructure.uid
  config_json = file("${path.module}/dashboards/nfd-health.json")
  overwrite   = true
}

resource "grafana_dashboard" "reloader_health" {
  folder      = grafana_folder.infrastructure.uid
  config_json = file("${path.module}/dashboards/reloader-health.json")
  overwrite   = true
}

resource "grafana_dashboard" "spegel_health" {
  folder      = grafana_folder.infrastructure.uid
  config_json = file("${path.module}/dashboards/spegel-health.json")
  overwrite   = true
}

resource "grafana_dashboard" "longhorn_health" {
  folder      = grafana_folder.storage.uid
  config_json = file("${path.module}/dashboards/longhorn-health.json")
  overwrite   = true
}

resource "grafana_dashboard" "victoriametrics_health" {
  folder      = grafana_folder.observability.uid
  config_json = file("${path.module}/dashboards/victoriametrics-health.json")
  overwrite   = true
}

resource "grafana_dashboard" "metallb_health" {
  folder      = grafana_folder.infrastructure.uid
  config_json = file("${path.module}/dashboards/metallb-health.json")
  overwrite   = true
}

resource "grafana_dashboard" "loki_health" {
  folder      = grafana_folder.observability.uid
  config_json = file("${path.module}/dashboards/loki-health.json")
  overwrite   = true
}

resource "grafana_dashboard" "garage_health" {
  folder      = grafana_folder.storage.uid
  config_json = file("${path.module}/dashboards/garage-health.json")
  overwrite   = true
}

resource "grafana_dashboard" "grafana_health" {
  folder      = grafana_folder.observability.uid
  config_json = file("${path.module}/dashboards/grafana-health.json")
  overwrite   = true
}

resource "grafana_dashboard" "envoy_gateway_health" {
  folder      = grafana_folder.infrastructure.uid
  config_json = file("${path.module}/dashboards/envoy-gateway-health.json")
  overwrite   = true
}

resource "grafana_dashboard" "flux_control_plane" {
  folder      = grafana_folder.platform.uid
  config_json = file("${path.module}/dashboards/flux-control-plane.json")
  overwrite   = true
}

resource "grafana_dashboard" "flux_cluster" {
  folder      = grafana_folder.platform.uid
  config_json = file("${path.module}/dashboards/flux-cluster.json")
  overwrite   = true
}

resource "grafana_dashboard" "cert_manager_health" {
  folder      = grafana_folder.platform.uid
  config_json = file("${path.module}/dashboards/cert-manager-health.json")
  overwrite   = true
}

resource "grafana_dashboard" "postgres_health" {
  folder      = grafana_folder.platform.uid
  config_json = file("${path.module}/dashboards/postgres-health.json")
  overwrite   = true
}

resource "grafana_dashboard" "authentik_health" {
  folder      = grafana_folder.auth.uid
  config_json = file("${path.module}/dashboards/authentik-health.json")
  overwrite   = true
}

resource "grafana_dashboard" "node_metrics" {
  folder      = grafana_folder.infrastructure.uid
  config_json = file("${path.module}/dashboards/node-metrics.json")
  overwrite   = true
}
