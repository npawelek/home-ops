terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.31.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "3.5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_route53_zone" "domain" {
  name = var.domain
}

data "http" "ipv4" {
  url = "http://checkip.amazonaws.com"
}

resource "aws_route53_record" "vpn" {
  zone_id = data.aws_route53_zone.domain.zone_id
  name    = "vpn"
  type    = "A"
  ttl     = var.ttl
  records = [chomp(data.http.ipv4.response_body)]
}
