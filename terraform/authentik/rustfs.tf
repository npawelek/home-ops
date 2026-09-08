resource "authentik_property_mapping_provider_scope" "scope_rustfs_roles" {
  name       = "RustFS Roles"
  scope_name = "rustfs"
  expression = <<-EOF
    roles = []
    if ak_is_group_member(request.user, name="authentik Admins"):
        roles.append("consoleAdmin")
    return {
        "roles": roles,
    }
  EOF
}

resource "authentik_provider_oauth2" "rustfs" {
  name               = "rustfs-oauth"
  client_id          = "rustfs"
  authorization_flow = data.authentik_flow.default_authorization_flow.id
  invalidation_flow  = data.authentik_flow.default_invalidation_flow.id
  property_mappings = [
    data.authentik_property_mapping_provider_scope.scope_openid.id,
    data.authentik_property_mapping_provider_scope.scope_profile.id,
    data.authentik_property_mapping_provider_scope.scope_email.id,
    authentik_property_mapping_provider_scope.scope_rustfs_roles.id,
  ]
  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = "https://rustfs.${var.domain}/rustfs/admin/v3/oidc/callback/default"
    }
  ]
  signing_key                = data.authentik_certificate_key_pair.default.id
  access_token_validity      = var.access_token_validity
  refresh_token_validity     = var.refresh_token_validity
  client_type                = "confidential"
  include_claims_in_id_token = true
  grant_types = [
    "authorization_code",
    "refresh_token",
  ]
}

resource "authentik_application" "rustfs" {
  name               = "RustFS"
  slug               = "rustfs"
  protocol_provider  = authentik_provider_oauth2.rustfs.id
  meta_icon          = "https://raw.githubusercontent.com/loganmarchione/homelab-svg-assets/refs/heads/main/assets/rust.svg"
  meta_launch_url    = "https://rustfs.${var.domain}"
  policy_engine_mode = "any"
}

resource "authentik_policy_binding" "rustfs_admins_access" {
  target = authentik_application.rustfs.uuid
  group  = data.authentik_group.authentik_admins.id
  order  = 0
}

output "rustfs_client_secret" {
  value     = authentik_provider_oauth2.rustfs.client_secret
  sensitive = true
}
