resource "authentik_provider_proxy" "jellyseerr" {
  name                         = "jellyseerr-proxy"
  access_token_validity        = var.access_token_validity
  authorization_flow           = data.authentik_flow.default_authorization_flow.id
  invalidation_flow            = data.authentik_flow.default_invalidation_flow.id
  external_host                = "https://jellyseerr.${var.domain}"
  internal_host_ssl_validation = true
  mode                         = "forward_single"
  intercept_header_auth        = true
}

resource "authentik_application" "jellyseerr" {
  name              = "Jellyseerr"
  slug              = "jellyseerr"
  protocol_provider = authentik_provider_proxy.jellyseerr.id
  meta_launch_url   = "https://jellyseerr.${var.domain}"
  policy_engine_mode = "any"
}

resource "authentik_outpost_provider_attachment" "jellyseerr" {
  outpost           = data.authentik_outpost.embedded.id
  protocol_provider = authentik_provider_proxy.jellyseerr.id
}
