resource "minio_s3_bucket" "cnpg_authentik_postgres" {
  bucket = "cnpg-authentik-postgres"
  acl    = "private"
}

resource "minio_iam_user" "cnpg_authentik_postgres" {
  name          = "cnpg-authentik-postgres"
  force_destroy = true
}

resource "minio_iam_policy" "cnpg_authentik_postgres" {
  name = "cnpg-authentik-postgres-s3"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetBucketLocation", "s3:ListBucket"]
        Resource = "arn:aws:s3:::cnpg-authentik-postgres"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::cnpg-authentik-postgres/*"
      }
    ]
  })
}

resource "minio_iam_user_policy_attachment" "cnpg_authentik_postgres" {
  user_name   = minio_iam_user.cnpg_authentik_postgres.name
  policy_name = minio_iam_policy.cnpg_authentik_postgres.name
}

resource "minio_iam_service_account" "cnpg_authentik_postgres" {
  target_user = minio_iam_user.cnpg_authentik_postgres.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetBucketLocation", "s3:ListBucket"]
        Resource = "arn:aws:s3:::cnpg-authentik-postgres"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::cnpg-authentik-postgres/*"
      }
    ]
  })
}
