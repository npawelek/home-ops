terraform {
  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "4.45.1"
    }
  }
}

provider "grafana" {
  url  = var.grafana_url
  auth = var.grafana_auth
}
