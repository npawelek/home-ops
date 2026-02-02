resource "authentik_user" "ldapservice" {
  username = "ldapservice"
  name     = "LDAP Service User"
  email    = "ldapservice@${var.domain}"
  path     = "users"
  password = var.ldapservice_password
}

resource "authentik_rbac_role" "ldap_search" {
  name = "LDAP search"
}

# Note: It's unclear whether this can be defined in terraform
# After successful apply, manually configure the LDAP search permission:
# -----
# 1. Go to Directory > Roles > LDAP search > Users tab
# 2. Click "Add existing user" and select "ldapservice" user
# 3. Click Assign
# 4. Go to Applications > Providers > jellyfin-ldap > Permissions tab
# 5. Click "Assign Object Permissions"
# 6. Select "LDAP search" role
# 7. Enable "Search full LDAP directory" permission
# 8. Click Assign

resource "authentik_provider_ldap" "jellyfin" {
  name        = "jellyfin-ldap"
  base_dn     = "DC=ldap,DC=goauthentik,DC=io"
  certificate = data.authentik_certificate_key_pair.default.id
  bind_flow   = data.authentik_flow.ldap_authentication_flow.id
  unbind_flow = data.authentik_flow.default_invalidation_flow.id
  mfa_support = false
}

resource "authentik_application" "jellyfin" {
  name              = "Jellyfin"
  slug              = "jellyfin"
  meta_icon         = "https://raw.githubusercontent.com/loganmarchione/homelab-svg-assets/refs/heads/main/assets/jellyfin.svg"
  meta_launch_url   = "https://jellyfin.${var.domain}/"
  protocol_provider = authentik_provider_ldap.jellyfin.id
}

resource "authentik_application_entitlement" "jellyfin_ent" {
  name        = "jellyfin-ent"
  application = authentik_application.jellyfin.uuid
}

resource "authentik_group" "jellyfin_users" {
  name         = "jellyfin-users"
  is_superuser = false
}

resource "authentik_policy_binding" "jellyfin_ent_admins_access" {
  target = authentik_application_entitlement.jellyfin_ent.id
  group  = data.authentik_group.authentik_admins.id
  order  = 0
}

resource "authentik_policy_binding" "jellyfin_ent_users_access" {
  target = authentik_application_entitlement.jellyfin_ent.id
  group  = authentik_group.jellyfin_users.id
  order  = 1
}
