terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "~> 2025.12.0"
    }
  }
}

provider "authentik" {
  url   = "http://authentik-server.auth.svc.cluster.local"
  token = var.authentik_token
}
