# LDAP service user for binding
resource "authentik_user" "ldapservice" {
  username = "ldapservice"
  name     = "LDAP Service User"
  email    = "ldapservice@${var.domain}"
  path     = "users"
  password = var.ldapservice_password

  lifecycle {
    ignore_changes = [password]
  }
}

# Example regular user configuration
# Uncomment and modify to create users

# resource "authentik_user" "admin" {
#   username = "admin"
#   name     = "Admin User"
#   email    = "admin@${var.domain}"
#   groups   = [authentik_group.jellyfin_users.id]
# }

# resource "authentik_user" "user1" {
#   username = "user1"
#   name     = "User One"
#   email    = "user1@${var.domain}"
#   groups   = [authentik_group.jellyfin_users.id]
# }
