variable "minio_server" {
  description = "AIStor S3 API endpoint (host:port, no scheme). Port-forward locally: localhost:9000"
  type        = string
}

variable "minio_root_user" {
  description = "AIStor root username (MINIO_ROOT_USER from minio-secrets)"
  type        = string
  sensitive   = true
}

variable "minio_root_password" {
  description = "AIStor root password (MINIO_ROOT_PASSWORD from minio-secrets)"
  type        = string
  sensitive   = true
}

variable "minio_insecure" {
  description = "Skip TLS verification. Set true when port-forwarding (cert SAN won't match localhost)"
  type        = bool
  default     = true
}
