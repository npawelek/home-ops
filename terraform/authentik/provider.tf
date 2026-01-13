terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "~> 2025.10.0"
    }
  }
}

provider "authentik" {
  url   = "https://auth.${var.domain}"
  token = var.authentik_token
}
