variable "domain" {
  description = "Base domain for applications"
  type        = string
}

variable "authentik_token" {
  description = "Authentik API token"
  type        = string
  sensitive   = true
}

variable "access_token_validity" {
  description = "Access token validity duration for proxy providers"
  type        = string
  default     = "hours=24"
}

variable "refresh_token_validity" {
  description = "Refresh token validity duration for OAuth providers"
  type        = string
}

variable "ldapservice_password" {
  description = "Password for LDAP service user"
  type        = string
  sensitive   = true
}
