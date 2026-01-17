resource "authentik_provider_proxy" "radarr_anime" {
  name                         = "radarr-anime-proxy"
  access_token_validity        = var.access_token_validity
  authorization_flow           = data.authentik_flow.default_authorization_flow.id
  invalidation_flow            = data.authentik_flow.default_invalidation_flow.id
  external_host                = "https://radarr-anime.${var.domain}"
  internal_host_ssl_validation = true
  mode                         = "forward_single"
  intercept_header_auth        = true
}

resource "authentik_application" "radarr_anime" {
  name               = "Radarr Anime"
  slug               = "radarr-anime"
  protocol_provider  = authentik_provider_proxy.radarr_anime.id
  meta_launch_url    = "https://radarr-anime.${var.domain}"
  policy_engine_mode = "any"
}

resource "authentik_outpost_provider_attachment" "radarr_anime" {
  outpost           = data.authentik_outpost.embedded.id
  protocol_provider = authentik_provider_proxy.radarr_anime.id
}
