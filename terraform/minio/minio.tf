resource "minio_s3_bucket" "buzz" {
  bucket = "buzz"
  acl    = "private"
}

resource "minio_iam_user" "buzz" {
  name   = var.buzz_access_key
  secret = var.buzz_secret_key
}

resource "minio_iam_user_policy_attachment" "buzz_readwrite" {
  user_name   = minio_iam_user.buzz.name
  policy_name = "readwrite"
}
