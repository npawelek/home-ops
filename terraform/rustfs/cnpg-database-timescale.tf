resource "minio_s3_bucket" "cnpg_database_timescale" {
  bucket = "cnpg-database-timescale"
  acl    = "private"
}

resource "minio_iam_user" "cnpg_database_timescale" {
  name          = "cnpg-database-timescale"
  force_destroy = true
}

resource "minio_iam_policy" "cnpg_database_timescale" {
  name = "cnpg-database-timescale-s3"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetBucketLocation", "s3:ListBucket"]
        Resource = "arn:aws:s3:::cnpg-database-timescale"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::cnpg-database-timescale/*"
      }
    ]
  })
}

resource "minio_iam_user_policy_attachment" "cnpg_database_timescale" {
  user_name   = minio_iam_user.cnpg_database_timescale.name
  policy_name = minio_iam_policy.cnpg_database_timescale.name
}

resource "minio_iam_service_account" "cnpg_database_timescale" {
  target_user = minio_iam_user.cnpg_database_timescale.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetBucketLocation", "s3:ListBucket"]
        Resource = "arn:aws:s3:::cnpg-database-timescale"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::cnpg-database-timescale/*"
      }
    ]
  })
}
