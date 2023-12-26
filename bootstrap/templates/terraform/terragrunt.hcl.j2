remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket     = local.secrets.aws_s3_bucket
    key        = "${path_relative_to_include()}/terraform.tfstate"
    region     = local.secrets.aws_region
    encrypt    = true
    acl        = "private"
    kms_key_id = local.secrets.aws_kms_arn
  }
}

locals {
  secrets = yamldecode(sops_decrypt_file(("secret.sops.yaml")))
}

inputs = {
  aws_access_key        = local.secrets.aws_access_key
  aws_secret_access_key = local.secrets.aws_secret_access_key
  aws_region            = local.secrets.aws_region
  aws_domain            = local.secrets.aws_domain
  ingress_internal      = local.secrets.ingress_internal
  ingress_external      = local.secrets.ingress_external
}
