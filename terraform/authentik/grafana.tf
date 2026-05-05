resource "authentik_provider_oauth2" "grafana" {
  name               = "grafana-oauth"
  client_id          = "grafana"
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
      url           = "https://grafana.${var.domain}/login/generic_oauth"
    }
  ]
  signing_key            = data.authentik_certificate_key_pair.default.id
  access_token_validity  = var.access_token_validity
  refresh_token_validity = var.refresh_token_validity
  client_type            = "confidential"
  include_claims_in_id_token = true
  logout_uri             = "https://grafana.${var.domain}/logout"
  logout_method          = "frontchannel"
}

resource "authentik_application" "grafana" {
  name               = "Grafana"
  slug               = "grafana"
  protocol_provider  = authentik_provider_oauth2.grafana.id
  meta_icon          = "https://raw.githubusercontent.com/loganmarchione/homelab-svg-assets/refs/heads/main/assets/grafana.svg"
  meta_launch_url    = "https://grafana.${var.domain}"
  policy_engine_mode = "any"
}

resource "authentik_policy_binding" "grafana_admins_access" {
  target = authentik_application.grafana.uuid
  group  = data.authentik_group.authentik_admins.id
  order  = 0
}
