resource "grafana_dashboard" "otelcol_health" {
  config_json = file("${path.module}/dashboards/otelcol-health.json")
  overwrite   = true
}
