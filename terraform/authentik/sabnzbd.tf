resource "authentik_provider_proxy" "sabnzbd" {
  name               = "sabnzbd"
  external_host      = "https://sabnzbd.${var.secret_domain}"
  mode               = "forward_single"
  access_token_validity = "hours=24"
}

resource "authentik_application" "sabnzbd" {
  name              = "sabnzbd"
  slug              = "sabnzbd"
  protocol_provider = authentik_provider_proxy.sabnzbd.id
  meta_icon         = "https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/sabnzbd.png"
  meta_publisher    = "SABnzbd"
  group             = "Downloads"
}

resource "authentik_policy_binding" "sabnzbd_access" {
  target = authentik_application.sabnzbd.uuid
  group  = authentik_group.users.id
  order  = 0
}

output "sabnzbd_outpost_config" {
  value = authentik_provider_proxy.sabnzbd.id
}
