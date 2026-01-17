resource "authentik_provider_proxy" "radarr" {
  name                         = "radarr-proxy"
  access_token_validity        = var.access_token_validity
  authorization_flow           = data.authentik_flow.default_authorization_flow.id
  invalidation_flow            = data.authentik_flow.default_invalidation_flow.id
  external_host                = "https://radarr.${var.domain}"
  internal_host_ssl_validation = true
  mode                         = "forward_single"
  intercept_header_auth        = true
}

resource "authentik_application" "radarr" {
  name               = "Radarr"
  slug               = "radarr"
  protocol_provider  = authentik_provider_proxy.radarr.id
  meta_launch_url    = "https://radarr.${var.domain}"
  policy_engine_mode = "any"
}

resource "authentik_outpost_provider_attachment" "radarr" {
  outpost           = data.authentik_outpost.embedded.id
  protocol_provider = authentik_provider_proxy.radarr.id
}
