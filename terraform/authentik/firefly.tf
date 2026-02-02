resource "authentik_provider_proxy" "firefly" {
  name                         = "firefly-proxy"
  access_token_validity        = var.access_token_validity
  authorization_flow           = data.authentik_flow.default_authorization_flow.id
  invalidation_flow            = data.authentik_flow.default_invalidation_flow.id
  external_host                = "https://firefly.${var.domain}"
  internal_host_ssl_validation = true
  mode                         = "forward_single"
  intercept_header_auth        = true
}

resource "authentik_application" "firefly" {
  name               = "Firefly III"
  slug               = "firefly-iii"
  protocol_provider  = authentik_provider_proxy.firefly.id
  meta_icon          = "https://raw.githubusercontent.com/loganmarchione/homelab-svg-assets/refs/heads/main/assets/firefly-iii.svg"
  meta_launch_url    = "https://firefly.${var.domain}"
  policy_engine_mode = "any"
}

resource "authentik_outpost_provider_attachment" "firefly" {
  outpost           = data.authentik_outpost.embedded.id
  protocol_provider = authentik_provider_proxy.firefly.id
}

resource "authentik_policy_binding" "firefly_admins_access" {
  target = authentik_application.firefly.uuid
  group  = data.authentik_group.authentik_admins.id
  order  = 0
}
