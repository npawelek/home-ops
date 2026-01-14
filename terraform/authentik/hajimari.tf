resource "authentik_provider_proxy" "hajimari" {
  name                         = "hajimari-proxy"
  access_token_validity        = var.access_token_validity
  authorization_flow           = data.authentik_flow.default_authorization_flow.id
  invalidation_flow            = data.authentik_flow.default_invalidation_flow.id
  external_host                = "https://hajimari.${var.domain}"
  internal_host_ssl_validation = true
  mode                         = "forward_single"
  intercept_header_auth        = true
}

resource "authentik_application" "hajimari" {
  name              = "Hajimari"
  slug              = "hajimari"
  protocol_provider = authentik_provider_proxy.hajimari.id
  meta_launch_url   = "https://hajimari.${var.domain}"
  meta_description  = "Application Dashboard"
  policy_engine_mode = "any"
}

resource "authentik_outpost_provider_attachment" "hajimari" {
  outpost           = data.authentik_outpost.embedded.id
  protocol_provider = authentik_provider_proxy.hajimari.id
}
