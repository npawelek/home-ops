resource "authentik_group" "jellyfin_users" {
  name         = "jellyfin-users"
  is_superuser = false
}
