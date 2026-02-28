resource "authentik_provider_proxy" "node_red" {
  name                         = "node-red-proxy"
  access_token_validity        = var.access_token_validity
  authorization_flow           = data.authentik_flow.default_authorization_flow.id
  invalidation_flow            = data.authentik_flow.default_invalidation_flow.id
  external_host                = "https://nodered.${var.domain}"
  internal_host_ssl_validation = true
  mode                         = "forward_single"
  intercept_header_auth        = true
}

resource "authentik_application" "node_red" {
  name               = "Node-RED"
  slug               = "node-red"
  protocol_provider  = authentik_provider_proxy.node_red.id
  meta_icon          = "https://raw.githubusercontent.com/loganmarchione/homelab-svg-assets/refs/heads/main/assets/nodered.svg"
  meta_launch_url    = "https://nodered.${var.domain}"
  policy_engine_mode = "any"
}

resource "authentik_outpost_provider_attachment" "node_red" {
  outpost           = data.authentik_outpost.embedded.id
  protocol_provider = authentik_provider_proxy.node_red.id
}

resource "authentik_policy_binding" "node_red_admins_access" {
  target = authentik_application.node_red.uuid
  group  = data.authentik_group.authentik_admins.id
  order  = 0
}
