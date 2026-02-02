resource "authentik_provider_proxy" "sabnzbd" {
  name                         = "sabnzbd-proxy"
  access_token_validity        = var.access_token_validity
  authorization_flow           = data.authentik_flow.default_authorization_flow.id
  invalidation_flow            = data.authentik_flow.default_invalidation_flow.id
  external_host                = "https://sabnzbd.${var.domain}"
  internal_host_ssl_validation = true
  mode                         = "forward_single"
  intercept_header_auth        = true
}

resource "authentik_application" "sabnzbd" {
  name               = "SABnzbd"
  slug               = "sabnzbd"
  protocol_provider  = authentik_provider_proxy.sabnzbd.id
  meta_icon          = "https://raw.githubusercontent.com/loganmarchione/homelab-svg-assets/refs/heads/main/assets/sabnzbd.svg"
  meta_launch_url    = "https://sabnzbd.${var.domain}"
  policy_engine_mode = "any"
}

resource "authentik_outpost_provider_attachment" "sabnzbd" {
  outpost           = data.authentik_outpost.embedded.id
  protocol_provider = authentik_provider_proxy.sabnzbd.id
}

resource "authentik_policy_binding" "sabnzbd_admins_access" {
  target = authentik_application.sabnzbd.uuid
  group  = data.authentik_group.authentik_admins.id
  order  = 0
}
