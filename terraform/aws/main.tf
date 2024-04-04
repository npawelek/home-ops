terraform {

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.44.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "3.4.2"
    }
    sops = {
      source  = "carlpett/sops"
      version = "1.0.0"
    }
  }
}

variable "aws_access_key" {
  description = "AWS Access Key"
  type        = string
  sensitive   = true
}

variable "aws_secret_access_key" {
  description = "AWS Secret Access Key"
  type        = string
  sensitive   = true
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
  sensitive   = true
}

variable "aws_domain" {
  description = "AWS Domain"
  type        = string
  sensitive   = true
}

variable "ingress_internal" {
  description = "Ingress internal IP address"
  type        = string
  sensitive   = true
}

variable "ingress_external" {
  description = "Ingress external IP address"
  type        = string
  sensitive   = true
}

provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_access_key
  region     = var.aws_region
}

resource "aws_route53_zone" "domain" {
  name = var.aws_domain
}

data "http" "ipv4" {
  url = "http://checkip.amazonaws.com"
}

resource "aws_route53_record" "ipv4" {
  zone_id = aws_route53_zone.domain.zone_id
  name    = "ipv4"
  type    = "A"
  ttl     = 1
  records = [chomp(data.http.ipv4.response_body)]
}

resource "aws_route53_record" "vpn" {
  zone_id = aws_route53_zone.domain.zone_id
  name    = "vpn"
  type    = "A"
  ttl     = 300
  records = [chomp(data.http.ipv4.response_body)]
}

resource "aws_route53_record" "video" {
  zone_id = aws_route53_zone.domain.zone_id
  name    = "video"
  type    = "A"
  ttl     = 300
  records = [chomp(data.http.ipv4.response_body)]
}

resource "aws_route53_record" "req" {
  zone_id = aws_route53_zone.domain.zone_id
  name    = "req"
  type    = "A"
  ttl     = 300
  records = [chomp(data.http.ipv4.response_body)]
}

resource "aws_route53_record" "internal" {
  zone_id = aws_route53_zone.domain.zone_id
  name    = "internal"
  type    = "A"
  ttl     = 300
  records = [var.ingress_internal]
}

resource "aws_route53_record" "external" {
  zone_id = aws_route53_zone.domain.zone_id
  name    = "external"
  type    = "A"
  ttl     = 300
  records = [var.ingress_external]
}

resource "aws_route53_record" "caa" {
  zone_id = aws_route53_zone.domain.zone_id
  name    = var.aws_domain
  type    = "CAA"
  ttl     = 3600
  records = [
    "0 issue \"letsencrypt.org\"",
    "0 issuewild \"letsencrypt.org\""
  ]
}
