resource "minio_s3_bucket" "buzz" {
  bucket = "buzz"
  acl    = "private"
}

resource "minio_iam_user" "buzz" {
  name          = "buzz"
  force_destroy = true
}

resource "minio_iam_service_account" "buzz" {
  target_user = minio_iam_user.buzz.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetBucketLocation", "s3:ListBucket"]
        Resource = "arn:aws:s3:::buzz"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::buzz/*"
      }
    ]
  })
}
