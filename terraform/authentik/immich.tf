resource "authentik_provider_oauth2" "immich" {
  name               = "immich-oauth"
  client_id          = "immich"
  authorization_flow = data.authentik_flow.default_authorization_flow.id
  invalidation_flow  = data.authentik_flow.default_invalidation_flow.id
  property_mappings  = data.authentik_scope_mapping.oauth2.ids
  redirect_uris = [
    "app.immich:///oauth-callback",
    "https://immich.${var.domain}/auth/login",
    "https://immich.${var.domain}/user-settings"
  ]
  signing_key               = data.authentik_certificate_key_pair.default.id
  access_token_validity     = var.access_token_validity
  refresh_token_validity    = var.refresh_token_validity
  client_type               = "confidential"
  include_claims_in_id_token = true
}

resource "authentik_application" "immich" {
  name               = "Immich"
  slug               = "immich"
  protocol_provider  = authentik_provider_oauth2.immich.id
  meta_launch_url    = "https://immich.${var.domain}/auth/login?autoLaunch=1"
  policy_engine_mode = "any"
}
