resource "authentik_application" "jellyseerr" {
  name              = "Requests"
  slug              = "jellyseerr"
  meta_launch_url   = "https://requests.${var.domain}"
  meta_icon         = "https://raw.githubusercontent.com/loganmarchione/homelab-svg-assets/refs/heads/main/assets/jellyseerr.svg"
  open_in_new_tab   = true
  policy_engine_mode = "any"
}

resource "authentik_policy_binding" "jellyseerr_admins_access" {
  target = authentik_application.jellyseerr.uuid
  group  = data.authentik_group.authentik_admins.id
  order  = 0
}

resource "authentik_policy_binding" "jellyseerr_users_access" {
  target = authentik_application.jellyseerr.uuid
  group  = authentik_group.jellyfin_users.id
  order  = 1
}
