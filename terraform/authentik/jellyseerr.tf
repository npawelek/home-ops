resource "authentik_application" "jellyseerr" {
  name              = "Jellyseerr"
  slug              = "jellyseerr"
  meta_launch_url   = "https://requests.${var.domain}"
  meta_icon         = "https://raw.githubusercontent.com/loganmarchione/homelab-svg-assets/refs/heads/main/assets/jellyseerr.svg"
  open_in_new_tab   = true
  policy_engine_mode = "any"
}
