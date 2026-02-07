resource "authentik_provider_proxy" "adguard_primary" {
  name                         = "adguard-primary-proxy"
  access_token_validity        = var.access_token_validity
  authorization_flow           = data.authentik_flow.default_authorization_flow.id
  invalidation_flow            = data.authentik_flow.default_invalidation_flow.id
  external_host                = "https://adguard-primary.${var.domain}"
  internal_host_ssl_validation = true
  mode                         = "forward_single"
  intercept_header_auth        = true
}

resource "authentik_application" "adguard_primary" {
  name               = "AdGuard Home (Primary)"
  slug               = "adguard-primary"
  protocol_provider  = authentik_provider_proxy.adguard_primary.id
  meta_icon          = "https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/adguard-home.png"
  meta_description   = "Network-wide ads & trackers blocking DNS server (Primary)"
  meta_publisher     = "AdGuard"
  meta_launch_url    = "https://adguard-primary.${var.domain}"
  policy_engine_mode = "any"
}

resource "authentik_outpost_provider_attachment" "adguard_primary" {
  outpost           = data.authentik_outpost.embedded.id
  protocol_provider = authentik_provider_proxy.adguard_primary.id
}

resource "authentik_policy_binding" "adguard_primary_admins_access" {
  target = authentik_application.adguard_primary.uuid
  group  = data.authentik_group.authentik_admins.id
  order  = 0
}

resource "authentik_provider_proxy" "adguard_secondary" {
  name                         = "adguard-secondary-proxy"
  access_token_validity        = var.access_token_validity
  authorization_flow           = data.authentik_flow.default_authorization_flow.id
  invalidation_flow            = data.authentik_flow.default_invalidation_flow.id
  external_host                = "https://adguard-secondary.${var.domain}"
  internal_host_ssl_validation = true
  mode                         = "forward_single"
  intercept_header_auth        = true
}

resource "authentik_application" "adguard_secondary" {
  name               = "AdGuard Home (Secondary)"
  slug               = "adguard-secondary"
  protocol_provider  = authentik_provider_proxy.adguard_secondary.id
  meta_icon          = "https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/adguard-home.png"
  meta_description   = "Network-wide ads & trackers blocking DNS server (Secondary)"
  meta_publisher     = "AdGuard"
  meta_launch_url    = "https://adguard-secondary.${var.domain}"
  policy_engine_mode = "any"
}

resource "authentik_outpost_provider_attachment" "adguard_secondary" {
  outpost           = data.authentik_outpost.embedded.id
  protocol_provider = authentik_provider_proxy.adguard_secondary.id
}

resource "authentik_policy_binding" "adguard_secondary_admins_access" {
  target = authentik_application.adguard_secondary.uuid
  group  = data.authentik_group.authentik_admins.id
  order  = 0
}
