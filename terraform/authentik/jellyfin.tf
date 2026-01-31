resource "authentik_provider_ldap" "jellyfin" {
  name        = "jellyfin-ldap"
  base_dn     = "DC=ldap,DC=goauthentik,DC=io"
  certificate = data.authentik_certificate_key_pair.default.id
  bind_flow   = data.authentik_flow.default_authentication_flow.id
  unbind_flow = data.authentik_flow.default_invalidation_flow.id
  mfa_support = false
}

resource "authentik_application" "jellyfin" {
  name              = "Jellyfin"
  slug              = "jellyfin"
  protocol_provider = authentik_provider_ldap.jellyfin.id
}

resource "authentik_policy_binding" "jellyfin_users_access" {
  target = authentik_application.jellyfin.uuid
  group  = authentik_group.jellyfin_users.id
  order  = 0
}
