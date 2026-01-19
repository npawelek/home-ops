output "synology_client_id" {
  description = "OAuth2 Client ID for Synology DSM"
  value       = authentik_provider_oauth2.synology.client_id
}

output "synology_client_secret" {
  description = "OAuth2 Client Secret for Synology DSM (sensitive)"
  value       = authentik_provider_oauth2.synology.client_secret
  sensitive   = true
}

output "synology_openid_configuration_url" {
  description = "OpenID Configuration URL for Synology DSM"
  value       = "https://auth.${var.domain}/application/o/${authentik_application.synology.slug}/.well-known/openid-configuration"
}
