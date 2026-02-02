resource "authentik_provider_proxy" "speedtest" {
  name                         = "speedtest-proxy"
  access_token_validity        = var.access_token_validity
  authorization_flow           = data.authentik_flow.default_authorization_flow.id
  invalidation_flow            = data.authentik_flow.default_invalidation_flow.id
  external_host                = "https://speedtest.${var.domain}"
  internal_host_ssl_validation = true
  mode                         = "forward_single"
  intercept_header_auth        = true
}

resource "authentik_application" "speedtest" {
  name               = "Speedtest"
  slug               = "speedtest"
  protocol_provider  = authentik_provider_proxy.speedtest.id
  meta_icon          = "https://raw.githubusercontent.com/loganmarchione/homelab-svg-assets/refs/heads/main/assets/ittools.svg"
  meta_launch_url    = "https://speedtest.${var.domain}"
  policy_engine_mode = "any"
}

resource "authentik_outpost_provider_attachment" "speedtest" {
  outpost           = data.authentik_outpost.embedded.id
  protocol_provider = authentik_provider_proxy.speedtest.id
}

resource "authentik_policy_binding" "speedtest_admins_access" {
  target = authentik_application.speedtest.uuid
  group  = data.authentik_group.authentik_admins.id
  order  = 0
}
