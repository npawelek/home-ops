resource "authentik_provider_oauth2" "sonarr_remux" {
  name               = "sonarr-remux-oauth"
  client_id          = "sonarr-remux"
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
      url               = "https://sonarr-remux.${var.domain}/signin-oidc"
    }
  ]
  signing_key                = data.authentik_certificate_key_pair.default.id
  access_token_validity      = var.access_token_validity
  refresh_token_validity     = var.refresh_token_validity
  client_type                = "confidential"
  include_claims_in_id_token = true
  sub_mode                   = "user_email"
  grant_types = [
    "authorization_code",
    "refresh_token",
  ]
}

resource "authentik_application" "sonarr_remux" {
  name               = "Sonarr Remux"
  slug               = "sonarr-remux"
  protocol_provider  = authentik_provider_oauth2.sonarr_remux.id
  meta_icon          = "https://raw.githubusercontent.com/loganmarchione/homelab-svg-assets/refs/heads/main/assets/sonarr.svg"
  meta_launch_url    = "https://sonarr-remux.${var.domain}"
  policy_engine_mode = "any"
}

resource "authentik_policy_binding" "sonarr_remux_admins_access" {
  target = authentik_application.sonarr_remux.uuid
  group  = data.authentik_group.authentik_admins.id
  order  = 0
}
