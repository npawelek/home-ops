resource "authentik_provider_proxy" "radarr_remux" {
  name                         = "radarr-remux-proxy"
  access_token_validity        = var.access_token_validity
  authorization_flow           = data.authentik_flow.default_authorization_flow.id
  invalidation_flow            = data.authentik_flow.default_invalidation_flow.id
  external_host                = "https://radarr-remux.${var.domain}"
  internal_host_ssl_validation = true
  mode                         = "forward_single"
  intercept_header_auth        = true
}

resource "authentik_application" "radarr_remux" {
  name               = "Radarr Remux"
  slug               = "radarr-remux"
  protocol_provider  = authentik_provider_proxy.radarr_remux.id
  meta_icon          = "https://raw.githubusercontent.com/loganmarchione/homelab-svg-assets/refs/heads/main/assets/radarr-dark.svg"
  meta_launch_url    = "https://radarr-remux.${var.domain}"
  policy_engine_mode = "any"
}

resource "authentik_outpost_provider_attachment" "radarr_remux" {
  outpost           = data.authentik_outpost.embedded.id
  protocol_provider = authentik_provider_proxy.radarr_remux.id
}
