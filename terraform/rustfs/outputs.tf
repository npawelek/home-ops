output "buzz_access_key" {
  value = minio_iam_service_account.buzz.access_key
}

output "buzz_secret_key" {
  value     = minio_iam_service_account.buzz.secret_key
  sensitive = true
}
