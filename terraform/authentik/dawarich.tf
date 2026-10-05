# Authentiks managed email scope always sends email_verified=False. Dawarich refuses to
# link an OIDC login to an existing account (same email) unless the claim is true.
resource "authentik_property_mapping_provider_scope" "scope_dawarich_email" {
  name       = "Dawarich email (verified)"
  scope_name = "email"
  expression = <<-EOF
    return {
        "email": request.user.email,
        "email_verified": True,
    }
  EOF
}

resource "authentik_provider_oauth2" "dawarich" {
  name               = "dawarich-oauth"
  client_id          = "dawarich"
  authorization_flow = data.authentik_flow.default_authorization_flow.id
  invalidation_flow  = data.authentik_flow.default_invalidation_flow.id
  property_mappings = [
    data.authentik_property_mapping_provider_scope.scope_openid.id,
    data.authentik_property_mapping_provider_scope.scope_profile.id,
    authentik_property_mapping_provider_scope.scope_dawarich_email.id,
  ]
  allowed_redirect_uris = [
    {
      matching_mode     = "strict"
      redirect_uri_type = "authorization"
      url               = "https://dawarich.${var.domain}/users/auth/openid_connect/callback"
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

resource "authentik_application" "dawarich" {
  name               = "Dawarich"
  slug               = "dawarich"
  protocol_provider  = authentik_provider_oauth2.dawarich.id
  meta_icon          = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg/dawarich.svg"
  meta_launch_url    = "https://dawarich.${var.domain}"
  policy_engine_mode = "any"
}

resource "authentik_policy_binding" "dawarich_admins_access" {
  target = authentik_application.dawarich.uuid
  group  = data.authentik_group.authentik_admins.id
  order  = 0
}

resource "authentik_group" "dawarich_users" {
  name         = "dawarich-users"
  is_superuser = false
}

resource "authentik_policy_binding" "dawarich_users_access" {
  target = authentik_application.dawarich.uuid
  group  = authentik_group.dawarich_users.id
  order  = 1
}
