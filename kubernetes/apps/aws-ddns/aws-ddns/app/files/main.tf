terraform {

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.43.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "3.4.2"
    }
  }
}

variable "AWS_DOMAIN" {
  type        = string
  description = "Use the defined domain within TF_VAR_AWS_DOMAIN environment variable"
}

provider "aws" {}

data "aws_route53_zone" "domain" {
  name = var.AWS_DOMAIN
}

data "http" "ipv4" {
  url = "http://checkip.amazonaws.com"
}

resource "aws_route53_record" "ipv4" {
  zone_id = data.aws_route53_zone.domain.zone_id
  name    = "ipv4"
  type    = "A"
  ttl     = 1
  records = [chomp(data.http.ipv4.response_body)]
}

resource "aws_route53_record" "vpn" {
  zone_id = data.aws_route53_zone.domain.zone_id
  name    = "vpn"
  type    = "A"
  ttl     = 300
  records = [chomp(data.http.ipv4.response_body)]
}

resource "aws_route53_record" "video" {
  zone_id = data.aws_route53_zone.domain.zone_id
  name    = "video"
  type    = "A"
  ttl     = 300
  records = [chomp(data.http.ipv4.response_body)]
}

resource "aws_route53_record" "req" {
  zone_id = data.aws_route53_zone.domain.zone_id
  name    = "req"
  type    = "A"
  ttl     = 300
  records = [chomp(data.http.ipv4.response_body)]
}
