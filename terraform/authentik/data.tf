data "authentik_flow" "default_authorization_flow" {
  slug = "default-provider-authorization-implicit-consent"
}

data "authentik_flow" "default_invalidation_flow" {
  slug = "default-provider-invalidation-flow"
}

data "authentik_flow" "default_authentication_flow" {
  slug = "default-authentication-flow"
}

data "authentik_property_mapping_provider_scope" "scope_openid" {
  managed = "goauthentik.io/providers/oauth2/scope-openid"
}

data "authentik_property_mapping_provider_scope" "scope_profile" {
  managed = "goauthentik.io/providers/oauth2/scope-profile"
}

data "authentik_property_mapping_provider_scope" "scope_email" {
  managed = "goauthentik.io/providers/oauth2/scope-email"
}

data "authentik_certificate_key_pair" "default" {
  name = "authentik Self-signed Certificate"
}
