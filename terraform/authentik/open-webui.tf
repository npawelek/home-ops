resource "authentik_provider_oauth2" "open_webui" {
  name               = "open-webui-oauth"
  client_id          = "open-webui"
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
      url           = "https://open-webui.${var.domain}/oauth/oidc/callback"
    }
  ]
  signing_key            = data.authentik_certificate_key_pair.default.id
  access_token_validity  = var.access_token_validity
  refresh_token_validity = var.refresh_token_validity
  client_type            = "confidential"
  include_claims_in_id_token = true
}

resource "authentik_application" "open_webui" {
  name               = "Open WebUI"
  slug               = "open-webui"
  protocol_provider  = authentik_provider_oauth2.open_webui.id
  meta_icon          = "https://raw.githubusercontent.com/loganmarchione/homelab-svg-assets/refs/heads/main/assets/openai-white.svg"
  meta_launch_url    = "https://open-webui.${var.domain}"
  policy_engine_mode = "any"
}

resource "authentik_group" "open_webui_users" {
  name         = "open-webui-users"
  is_superuser = false
}

resource "authentik_policy_binding" "open_webui_admins_access" {
  target = authentik_application.open_webui.uuid
  group  = data.authentik_group.authentik_admins.id
  order  = 0
}

resource "authentik_policy_binding" "open_webui_users_access" {
  target = authentik_application.open_webui.uuid
  group  = authentik_group.open_webui_users.id
  order  = 1
}
