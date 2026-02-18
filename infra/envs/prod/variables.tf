variable "domain_name" {
  type    = string
  default = "ronaldoauguste.com"

}
variable "www_domain_name" {
  type    = string
  default = "www.ronaldoauguste.com"

}
variable "region" {
  type    = string
  default = "us-east-2"

}
variable "site_bucket_name" {
  type    = string
  default = "ronaldo-auguste-resume"

}

variable "waf_web_acl_arn" {
  type        = string
  description = "WAFv2 Web ACL ARN to attach to CloudFront (global/us-east-1 scope)."
  default     = null
}