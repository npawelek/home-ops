resource "authentik_provider_proxy" "jellyfin" {
  name                         = "jellyfin-proxy"
  access_token_validity        = var.access_token_validity
  authorization_flow           = data.authentik_flow.default_authorization_flow.id
  invalidation_flow            = data.authentik_flow.default_invalidation_flow.id
  external_host                = "https://jellyfin.${var.domain}"
  internal_host_ssl_validation = true
  mode                         = "forward_single"
  intercept_header_auth        = true
}

resource "authentik_application" "jellyfin" {
  name              = "Jellyfin"
  slug              = "jellyfin"
  protocol_provider = authentik_provider_proxy.jellyfin.id
  meta_launch_url   = "https://jellyfin.${var.domain}"
  policy_engine_mode = "any"
}

resource "authentik_outpost_provider_attachment" "jellyfin" {
  outpost           = data.authentik_outpost.embedded.id
  protocol_provider = authentik_provider_proxy.jellyfin.id
}
