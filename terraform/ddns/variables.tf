variable "domain" {
  type        = string
  description = "The Route53 hosted zone domain name"
}

variable "ttl" {
  type        = number
  description = "TTL for DNS records in seconds"
  default     = 300
}

variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}
