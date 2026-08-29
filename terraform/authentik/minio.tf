resource "authentik_provider_proxy" "minio" {
  name                         = "minio-proxy"
  access_token_validity        = var.access_token_validity
  authorization_flow           = data.authentik_flow.default_authorization_flow.id
  invalidation_flow            = data.authentik_flow.default_invalidation_flow.id
  external_host                = "https://minio.${var.domain}"
  internal_host_ssl_validation = true
  mode                         = "forward_single"
  intercept_header_auth        = true
}

resource "authentik_application" "minio" {
  name               = "AIStor"
  slug               = "minio"
  protocol_provider  = authentik_provider_proxy.minio.id
  meta_icon          = "https://raw.githubusercontent.com/loganmarchione/homelab-svg-assets/refs/heads/main/assets/minio.svg"
  meta_launch_url    = "https://minio.${var.domain}"
  policy_engine_mode = "any"
}

resource "authentik_outpost_provider_attachment" "minio" {
  outpost           = data.authentik_outpost.embedded.id
  protocol_provider = authentik_provider_proxy.minio.id
}

resource "authentik_policy_binding" "minio_admins_access" {
  target = authentik_application.minio.uuid
  group  = data.authentik_group.authentik_admins.id
  order  = 0
}
