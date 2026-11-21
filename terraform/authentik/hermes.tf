resource "authentik_provider_proxy" "hermes" {
  name                         = "hermes-proxy"
  access_token_validity        = var.access_token_validity
  authorization_flow           = data.authentik_flow.default_authorization_flow.id
  invalidation_flow            = data.authentik_flow.default_invalidation_flow.id
  external_host                = "https://hermes.${var.domain}"
  internal_host_ssl_validation = true
  mode                         = "forward_single"
  intercept_header_auth        = true
}

resource "authentik_application" "hermes" {
  name               = "Hermes"
  slug               = "hermes"
  protocol_provider  = authentik_provider_proxy.hermes.id
  meta_icon          = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/hermes.svg"
  meta_launch_url    = "https://hermes.${var.domain}"
  policy_engine_mode = "any"
}

resource "authentik_outpost_provider_attachment" "hermes" {
  outpost           = data.authentik_outpost.embedded.id
  protocol_provider = authentik_provider_proxy.hermes.id
}

resource "authentik_policy_binding" "hermes_admins_access" {
  target = authentik_application.hermes.uuid
  group  = data.authentik_group.authentik_admins.id
  order  = 0
}

resource "authentik_provider_oauth2" "hermes_dashboard" {
  name               = "hermes-dashboard-oauth"
  client_id          = "hermes-dashboard"
  authorization_flow = data.authentik_flow.default_authorization_flow.id
  invalidation_flow  = data.authentik_flow.default_invalidation_flow.id
  property_mappings = [
    data.authentik_property_mapping_provider_scope.scope_openid.id,
    data.authentik_property_mapping_provider_scope.scope_profile.id,
    data.authentik_property_mapping_provider_scope.scope_email.id,
  ]
  allowed_redirect_uris = [
    {
      matching_mode     = "strict"
      redirect_uri_type = "authorization"
      url               = "https://hermes.${var.domain}/auth/callback"
    }
  ]
  signing_key                = data.authentik_certificate_key_pair.default.id
  access_token_validity      = var.access_token_validity
  refresh_token_validity     = var.refresh_token_validity
  client_type                = "public"
  include_claims_in_id_token = true
  grant_types = [
    "authorization_code",
    "refresh_token",
  ]
}

resource "authentik_application" "hermes_dashboard" {
  name               = "Hermes Dashboard (OIDC)"
  slug               = "hermes-dashboard"
  protocol_provider  = authentik_provider_oauth2.hermes_dashboard.id
  meta_launch_url    = "blank://blank"
  policy_engine_mode = "any"
}

resource "authentik_policy_binding" "hermes_dashboard_admins_access" {
  target = authentik_application.hermes_dashboard.uuid
  group  = data.authentik_group.authentik_admins.id
  order  = 0
}
