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
