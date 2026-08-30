resource "authentik_property_mapping_provider_scope" "scope_minio_policy" {
  name       = "MinIO Policy"
  scope_name = "minio"
  expression = <<-EOF
    return {
        "policy": [
            entitlement.name
            for entitlement in request.user.app_entitlements(provider.application)
        ],
    }
  EOF
}

resource "authentik_provider_oauth2" "minio" {
  name               = "minio-oauth"
  client_id          = "minio"
  authorization_flow = data.authentik_flow.default_authorization_flow.id
  invalidation_flow  = data.authentik_flow.default_invalidation_flow.id
  property_mappings = [
    data.authentik_property_mapping_provider_scope.scope_openid.id,
    data.authentik_property_mapping_provider_scope.scope_profile.id,
    data.authentik_property_mapping_provider_scope.scope_email.id,
    authentik_property_mapping_provider_scope.scope_minio_policy.id,
  ]
  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = "https://minio.${var.domain}/oauth_callback"
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

resource "authentik_application" "minio" {
  name               = "MinIO"
  slug               = "minio"
  protocol_provider  = authentik_provider_oauth2.minio.id
  meta_icon          = "https://raw.githubusercontent.com/loganmarchione/homelab-svg-assets/refs/heads/main/assets/minio.svg"
  meta_launch_url    = "https://minio.${var.domain}"
  policy_engine_mode = "any"
}

resource "authentik_policy_binding" "minio_admins_access" {
  target = authentik_application.minio.uuid
  group  = data.authentik_group.authentik_admins.id
  order  = 0
}

resource "authentik_application_entitlement" "minio_console_admin" {
  name        = "consoleAdmin"
  application = authentik_application.minio.uuid
}

resource "authentik_policy_binding" "minio_admins_entitlement" {
  target = authentik_application_entitlement.minio_console_admin.id
  group  = data.authentik_group.authentik_admins.id
  order  = 0
}
