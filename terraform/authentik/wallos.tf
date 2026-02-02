resource "authentik_provider_oauth2" "wallos" {
  name               = "wallos-oauth"
  client_id          = "wallos"
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
      url           = "https://wallos.${var.domain}/index.php"
    }
  ]
  signing_key            = data.authentik_certificate_key_pair.default.id
  access_token_validity  = var.access_token_validity
  refresh_token_validity = var.refresh_token_validity
  client_type            = "confidential"
  include_claims_in_id_token = true
}

resource "authentik_application" "wallos" {
  name               = "Wallos"
  slug               = "wallos"
  protocol_provider  = authentik_provider_oauth2.wallos.id
  meta_icon          = "https://raw.githubusercontent.com/loganmarchione/homelab-svg-assets/refs/heads/main/assets/dockge.svg"
  meta_launch_url    = "https://wallos.${var.domain}"
  policy_engine_mode = "any"
}

resource "authentik_policy_binding" "wallos_admins_access" {
  target = authentik_application.wallos.uuid
  group  = data.authentik_group.authentik_admins.id
  order  = 0
}
