terraform {
  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "4.41.0"
    }
  }
}

provider "grafana" {
  url  = var.grafana_url
  auth = var.grafana_auth
}
