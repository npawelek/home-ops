resource "authentik_provider_proxy" "garage_webui" {
  name                         = "garage-webui-proxy"
  access_token_validity        = var.access_token_validity
  authorization_flow           = data.authentik_flow.default_authorization_flow.id
  invalidation_flow            = data.authentik_flow.default_invalidation_flow.id
  external_host                = "https://garage.${var.domain}"
  internal_host_ssl_validation = true
  mode                         = "forward_single"
  intercept_header_auth        = true
}

resource "authentik_application" "garage_webui" {
  name               = "Garage"
  slug               = "garage-webui"
  protocol_provider  = authentik_provider_proxy.garage_webui.id
  meta_icon          = "https://raw.githubusercontent.com/loganmarchione/homelab-svg-assets/refs/heads/main/assets/garage.svg"
  meta_launch_url    = "https://garage.${var.domain}"
  policy_engine_mode = "any"
}

resource "authentik_outpost_provider_attachment" "garage_webui" {
  outpost           = data.authentik_outpost.embedded.id
  protocol_provider = authentik_provider_proxy.garage_webui.id
}

resource "authentik_policy_binding" "garage_webui_admins_access" {
  target = authentik_application.garage_webui.uuid
  group  = data.authentik_group.authentik_admins.id
  order  = 0
}
