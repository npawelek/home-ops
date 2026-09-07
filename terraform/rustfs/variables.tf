variable "rustfs_server" {
  description = "RustFS S3 API endpoint (host:port, no scheme)"
  type        = string
}

variable "RUSTFS_ACCESS_KEY" {
  description = "RustFS root access key"
  type        = string
  sensitive   = true
}

variable "RUSTFS_SECRET_KEY" {
  description = "RustFS root secret key"
  type        = string
  sensitive   = true
}
