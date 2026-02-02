resource "authentik_provider_oauth2" "immich" {
  name               = "immich-oauth"
  client_id          = "immich"
  authorization_flow = data.authentik_flow.default_authorization_flow.id
  invalidation_flow  = data.authentik_flow.default_invalidation_flow.id
  property_mappings = [
    data.authentik_property_mapping_provider_scope.scope_openid.id,
    data.authentik_property_mapping_provider_scope.scope_profile.id,
    data.authentik_property_mapping_provider_scope.scope_email.id,
  ]
  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = "app.immich:///oauth-callback"
    },
    {
      matching_mode = "strict"
      url           = "https://immich.${var.domain}/auth/login"
    },
    {
      matching_mode = "strict"
      url           = "https://immich.${var.domain}/user-settings"
    }
  ]
  signing_key            = data.authentik_certificate_key_pair.default.id
  access_token_validity  = var.access_token_validity
  refresh_token_validity = var.refresh_token_validity
  client_type            = "confidential"
  include_claims_in_id_token = true
}

resource "authentik_application" "immich" {
  name               = "Immich"
  slug               = "immich"
  protocol_provider  = authentik_provider_oauth2.immich.id
  meta_icon          = "https://raw.githubusercontent.com/loganmarchione/homelab-svg-assets/refs/heads/main/assets/immich.svg"
  meta_launch_url    = "https://immich.${var.domain}/auth/login?autoLaunch=1"
  policy_engine_mode = "any"
}

resource "authentik_group" "immich_users" {
  name         = "immich-users"
  is_superuser = false
}

resource "authentik_policy_binding" "immich_admins_access" {
  target = authentik_application.immich.uuid
  group  = data.authentik_group.authentik_admins.id
  order  = 0
}

resource "authentik_policy_binding" "immich_users_access" {
  target = authentik_application.immich.uuid
  group  = authentik_group.immich_users.id
  order  = 1
}
