resource "authentik_provider_proxy" "audiobookshelf" {
  name                         = "audiobookshelf-proxy"
  access_token_validity        = var.access_token_validity
  authorization_flow           = data.authentik_flow.default_authorization_flow.id
  invalidation_flow            = data.authentik_flow.default_invalidation_flow.id
  external_host                = "https://audiobookshelf.${var.domain}"
  internal_host_ssl_validation = true
  mode                         = "forward_single"
  intercept_header_auth        = true
}

resource "authentik_application" "audiobookshelf" {
  name               = "Audiobookshelf"
  slug               = "audiobookshelf"
  protocol_provider  = authentik_provider_proxy.audiobookshelf.id
  meta_icon          = "https://raw.githubusercontent.com/advplyr/audiobookshelf-app/refs/heads/master/android/src/main/res/mipmap-xxxhdpi/ic_launcher.png"
  meta_launch_url    = "https://audiobookshelf.${var.domain}"
  policy_engine_mode = "any"
}

resource "authentik_outpost_provider_attachment" "audiobookshelf" {
  outpost           = data.authentik_outpost.embedded.id
  protocol_provider = authentik_provider_proxy.audiobookshelf.id
}

resource "authentik_policy_binding" "audiobookshelf_admins_access" {
  target = authentik_application.audiobookshelf.uuid
  group  = data.authentik_group.authentik_admins.id
  order  = 0
}
