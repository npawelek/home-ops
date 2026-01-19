# Synology DSM OAuth2/OpenID Connect Integration
#
# After applying this configuration:
# 1. Note the Client ID (synology-dsm) and Client Secret from Terraform output
# 2. In Synology DSM Control Panel, navigate to Domain/LDAP > SSO Client
# 3. Enable OpenID Connect SSO service and configure:
#    - Profile: OIDC
#    - Account type: Domain/LDAP/local
#    - Name: authentik
#    - Well Known URL: https://auth.${var.domain}/application/o/synology-dsm/.well-known/openid-configuration
#    - Application ID: synology-dsm
#    - Application Key: <client_secret from terraform output>
#    - Redirect URL: https://racknas.${var.domain}
#    - Authorization Scope: openid profile email
#    - Username Claim: preferred_username
#
# Troubleshooting:
# - Ensure pop-ups are allowed in your browser
# - Verify the Redirect URL matches exactly (no trailing slash or #/signin)
# - Check that the Well Known URL is accessible

resource "authentik_provider_oauth2" "synology" {
  name               = "synology-oauth2"
  client_id          = "synology-dsm"
  authorization_flow = data.authentik_flow.default_authorization_flow.id
  invalidation_flow  = data.authentik_flow.default_invalidation_flow.id

  # Redirect URIs for Synology DSM
  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = "https://racknas.${var.domain}"
    }
  ]

  # Subject mode based on user's email as per documentation
  sub_mode = "user_email"

  # Required scopes for Synology DSM
  property_mappings = [
    data.authentik_property_mapping_provider_scope.scope_openid.id,
    data.authentik_property_mapping_provider_scope.scope_profile.id,
    data.authentik_property_mapping_provider_scope.scope_email.id,
  ]

  # Access token validity
  access_token_validity = var.access_token_validity
}

resource "authentik_application" "synology" {
  name               = "Synology DSM"
  slug               = "synology-dsm"
  protocol_provider  = authentik_provider_oauth2.synology.id
  meta_launch_url    = "https://racknas.${var.domain}"
  policy_engine_mode = "any"
}
