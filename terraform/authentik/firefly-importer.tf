resource "authentik_provider_proxy" "firefly_importer" {
  name                         = "firefly-importer-proxy"
  access_token_validity        = var.access_token_validity
  authorization_flow           = data.authentik_flow.default_authorization_flow.id
  invalidation_flow            = data.authentik_flow.default_invalidation_flow.id
  external_host                = "https://firefly-importer.${var.domain}"
  internal_host_ssl_validation = true
  mode                         = "forward_single"
  intercept_header_auth        = true
}

resource "authentik_application" "firefly_importer" {
  name               = "Firefly Importer"
  slug               = "firefly-importer"
  protocol_provider  = authentik_provider_proxy.firefly_importer.id
  meta_icon          = "https://raw.githubusercontent.com/loganmarchione/homelab-svg-assets/refs/heads/main/assets/firefly-iii.svg"
  meta_launch_url    = "https://firefly-importer.${var.domain}"
  policy_engine_mode = "any"
}

resource "authentik_outpost_provider_attachment" "firefly_importer" {
  outpost           = data.authentik_outpost.embedded.id
  protocol_provider = authentik_provider_proxy.firefly_importer.id
}

resource "authentik_policy_binding" "firefly_importer_admins_access" {
  target = authentik_application.firefly_importer.uuid
  group  = data.authentik_group.authentik_admins.id
  order  = 0
}
