locals {
  offsite_backup_buckets = [
    minio_s3_bucket.buzz.bucket,
    minio_s3_bucket.cnpg_authentik_postgres.bucket,
    minio_s3_bucket.cnpg_database_postgres.bucket,
    minio_s3_bucket.cnpg_database_timescale.bucket,
  ]

  offsite_backup_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetBucketLocation", "s3:ListBucket"]
        Resource = [for b in local.offsite_backup_buckets : "arn:aws:s3:::${b}"]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = [for b in local.offsite_backup_buckets : "arn:aws:s3:::${b}/*"]
      }
    ]
  })
}

resource "minio_iam_user" "offsite_backup" {
  name          = "offsite-backup"
  force_destroy = true
}

resource "minio_iam_policy" "offsite_backup" {
  name   = "offsite-backup-read"
  policy = local.offsite_backup_policy
}

resource "minio_iam_user_policy_attachment" "offsite_backup" {
  user_name   = minio_iam_user.offsite_backup.name
  policy_name = minio_iam_policy.offsite_backup.name
}

resource "minio_iam_service_account" "offsite_backup" {
  target_user = minio_iam_user.offsite_backup.name
  policy      = local.offsite_backup_policy
}
