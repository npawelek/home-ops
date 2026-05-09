resource "grafana_service_account" "mcp_grafana" {
  name        = "mcp-grafana"
  role        = "Editor"
  is_disabled = false
}

resource "grafana_service_account_token" "mcp_grafana" {
  name               = "mcp-grafana-token"
  service_account_id = grafana_service_account.mcp_grafana.id
}

output "mcp_grafana_token" {
  value     = grafana_service_account_token.mcp_grafana.key
  sensitive = true
}
