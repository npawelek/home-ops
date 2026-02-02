resource "authentik_provider_oauth2" "synology" {
  name               = "synology-oauth2"
  client_id          = "synology-dsm"
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
      url           = "https://racknas.${var.domain}:8079"
    }
  ]
  signing_key                = data.authentik_certificate_key_pair.default.id
  access_token_validity      = var.access_token_validity
  refresh_token_validity     = var.refresh_token_validity
  client_type                = "confidential"
  sub_mode                   = "user_email"
  include_claims_in_id_token = true
}

resource "authentik_application" "synology" {
  name               = "Synology DSM"
  slug               = "synology-dsm"
  protocol_provider  = authentik_provider_oauth2.synology.id
  meta_icon          = "https://raw.githubusercontent.com/loganmarchione/homelab-svg-assets/refs/heads/main/assets/synology-black.svg"
  meta_launch_url    = "https://racknas.${var.domain}"
  policy_engine_mode = "any"
}
