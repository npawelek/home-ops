resource "authentik_property_mapping_provider_scope" "scope_trek_email" {
  name       = "TREK email (verified)"
  scope_name = "email"
  expression = <<-EOF
    return {
        "email": request.user.email,
        "email_verified": True,
    }
  EOF
}

resource "authentik_provider_oauth2" "trek" {
  name               = "trek-oauth"
  client_id          = "trek"
  authorization_flow = data.authentik_flow.default_authorization_flow.id
  invalidation_flow  = data.authentik_flow.default_invalidation_flow.id
  property_mappings = [
    data.authentik_property_mapping_provider_scope.scope_openid.id,
    data.authentik_property_mapping_provider_scope.scope_profile.id,
    authentik_property_mapping_provider_scope.scope_trek_email.id,
  ]
  allowed_redirect_uris = [
    {
      matching_mode     = "strict"
      redirect_uri_type = "authorization"
      url               = "https://trek.${var.domain}/api/auth/oidc/callback"
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

resource "authentik_application" "trek" {
  name               = "TREK"
  slug               = "trek"
  protocol_provider  = authentik_provider_oauth2.trek.id
  meta_icon          = "https://raw.githubusercontent.com/liketrek/TREK/main/client/public/logo-light.svg"
  meta_launch_url    = "https://trek.${var.domain}"
  policy_engine_mode = "any"
}

resource "authentik_policy_binding" "trek_admins_access" {
  target = authentik_application.trek.uuid
  group  = data.authentik_group.authentik_admins.id
  order  = 0
}
