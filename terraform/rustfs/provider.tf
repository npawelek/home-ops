terraform {
  required_providers {
    minio = {
      source  = "aminueza/minio"
      version = "~> 3.0"
    }
  }
}

provider "minio" {
  minio_server   = var.rustfs_server
  minio_user     = var.RUSTFS_ACCESS_KEY
  minio_password = var.RUSTFS_SECRET_KEY
  minio_ssl      = false
}
