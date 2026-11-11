resource "authentik_property_mapping_provider_scope" "scope_kept_email" {
  name       = "Kept email (verified)"
  scope_name = "email"
  expression = <<-EOF
    return {
        "email": request.user.email,
        "email_verified": True,
    }
  EOF
}

resource "authentik_provider_oauth2" "kept" {
  name               = "kept-oauth"
  client_id          = "kept"
  authorization_flow = data.authentik_flow.default_authorization_flow.id
  invalidation_flow  = data.authentik_flow.default_invalidation_flow.id
  property_mappings = [
    data.authentik_property_mapping_provider_scope.scope_openid.id,
    data.authentik_property_mapping_provider_scope.scope_profile.id,
    authentik_property_mapping_provider_scope.scope_kept_email.id,
  ]
  allowed_redirect_uris = [
    {
      matching_mode     = "strict"
      redirect_uri_type = "authorization"
      url               = "https://kept.${var.domain}/api/v1/auth/callback/oidc"
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

resource "authentik_application" "kept" {
  name               = "Kept"
  slug               = "kept"
  protocol_provider  = authentik_provider_oauth2.kept.id
  meta_launch_url    = "https://kept.${var.domain}"
  policy_engine_mode = "any"
}

resource "authentik_policy_binding" "kept_admins_access" {
  target = authentik_application.kept.uuid
  group  = data.authentik_group.authentik_admins.id
  order  = 0
}

resource "authentik_group" "kept_users" {
  name         = "kept-users"
  is_superuser = false
}

resource "authentik_policy_binding" "kept_users_access" {
  target = authentik_application.kept.uuid
  group  = authentik_group.kept_users.id
  order  = 1
}
