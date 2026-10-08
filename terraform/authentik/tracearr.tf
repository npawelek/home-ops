resource "authentik_provider_oauth2" "tracearr" {
  name               = "tracearr-oauth"
  client_id          = "tracearr"
  authorization_flow = data.authentik_flow.default_authorization_flow.id
  invalidation_flow  = data.authentik_flow.default_invalidation_flow.id
  property_mappings = [
    data.authentik_property_mapping_provider_scope.scope_openid.id,
    data.authentik_property_mapping_provider_scope.scope_email.id,
    data.authentik_property_mapping_provider_scope.scope_profile.id,
  ]
  allowed_redirect_uris = [
    {
      matching_mode     = "strict"
      redirect_uri_type = "authorization"
      url               = "https://tracearr.${var.domain}/api/v1/auth/oauth2/callback/oidc"
    }
  ]
  signing_key                = data.authentik_certificate_key_pair.default.id
  access_token_validity      = var.access_token_validity
  refresh_token_validity     = var.refresh_token_validity
  client_type                = "confidential"
  include_claims_in_id_token = true
  grant_types = [
    "authorization_code",
    "refresh_token",
  ]
}

resource "authentik_application" "tracearr" {
  name               = "Tracearr"
  slug               = "tracearr"
  protocol_provider  = authentik_provider_oauth2.tracearr.id
  meta_icon          = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/tracearr.svg"
  meta_launch_url    = "https://tracearr.${var.domain}"
  policy_engine_mode = "any"
}

resource "authentik_policy_binding" "tracearr_admins_access" {
  target = authentik_application.tracearr.uuid
  group  = data.authentik_group.authentik_admins.id
  order  = 0
}

resource "authentik_group" "tracearr_users" {
  name         = "tracearr-users"
  is_superuser = false
}

resource "authentik_policy_binding" "tracearr_users_access" {
  target = authentik_application.tracearr.uuid
  group  = authentik_group.tracearr_users.id
  order  = 1
}
