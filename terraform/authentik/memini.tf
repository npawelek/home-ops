resource "authentik_provider_proxy" "memini" {
  name                         = "memini-proxy"
  access_token_validity        = var.access_token_validity
  authorization_flow           = data.authentik_flow.default_authorization_flow.id
  invalidation_flow            = data.authentik_flow.default_invalidation_flow.id
  external_host                = "https://memini.${var.domain}"
  internal_host_ssl_validation = true
  mode                         = "forward_single"
  intercept_header_auth        = true
}

resource "authentik_application" "memini" {
  name               = "memini"
  slug               = "memini"
  protocol_provider  = authentik_provider_proxy.memini.id
  meta_icon          = "https://raw.githubusercontent.com/npawelek/home-ops/main/terraform/authentik/icons/memini.svg"
  meta_launch_url    = "https://memini.${var.domain}"
  policy_engine_mode = "any"
}

resource "authentik_outpost_provider_attachment" "memini" {
  outpost           = data.authentik_outpost.embedded.id
  protocol_provider = authentik_provider_proxy.memini.id
}

resource "authentik_policy_binding" "memini_admins_access" {
  target = authentik_application.memini.uuid
  group  = data.authentik_group.authentik_admins.id
  order  = 0
}
