variable "grafana_url" {
  description = "Grafana instance URL"
  type        = string
}

variable "grafana_auth" {
  description = "Grafana auth credentials (admin:password or API key)"
  type        = string
  sensitive   = true
}
