output "buzz_access_key" {
  value = minio_iam_service_account.buzz.access_key
}

output "buzz_secret_key" {
  value     = minio_iam_service_account.buzz.secret_key
  sensitive = true
}

output "cnpg_database_postgres_access_key" {
  value = minio_iam_service_account.cnpg_database_postgres.access_key
}

output "cnpg_database_postgres_secret_key" {
  value     = minio_iam_service_account.cnpg_database_postgres.secret_key
  sensitive = true
}

output "cnpg_authentik_postgres_access_key" {
  value = minio_iam_service_account.cnpg_authentik_postgres.access_key
}

output "cnpg_authentik_postgres_secret_key" {
  value     = minio_iam_service_account.cnpg_authentik_postgres.secret_key
  sensitive = true
}
