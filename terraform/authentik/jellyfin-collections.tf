resource "authentik_provider_proxy" "jellyfin_collections" {
  name                         = "jellyfin-collections-proxy"
  access_token_validity        = var.access_token_validity
  authorization_flow           = data.authentik_flow.default_authorization_flow.id
  invalidation_flow            = data.authentik_flow.default_invalidation_flow.id
  external_host                = "https://jellyfin-collections.${var.domain}"
  internal_host_ssl_validation = true
  mode                         = "forward_single"
  intercept_header_auth        = true
}

resource "authentik_application" "jellyfin_collections" {
  name               = "Jellyfin Collections"
  slug               = "jellyfin-collections"
  protocol_provider  = authentik_provider_proxy.jellyfin_collections.id
  meta_launch_url    = "blank://blank"
  policy_engine_mode = "any"
}

resource "authentik_outpost_provider_attachment" "jellyfin_collections" {
  outpost           = data.authentik_outpost.embedded.id
  protocol_provider = authentik_provider_proxy.jellyfin_collections.id
}

resource "authentik_user" "jellyfin_collections_cli" {
  username = "jellyfin-collections-cli"
  name     = "Jellyfin Collections CLI"
  path     = "service-accounts"
  type     = "service_account"
}

resource "authentik_policy_binding" "jellyfin_collections_cli_access" {
  target = authentik_application.jellyfin_collections.uuid
  user   = authentik_user.jellyfin_collections_cli.id
  order  = 0
}

resource "authentik_policy_binding" "jellyfin_collections_admins_access" {
  target = authentik_application.jellyfin_collections.uuid
  group  = data.authentik_group.authentik_admins.id
  order  = 1
}
