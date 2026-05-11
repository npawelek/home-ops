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
