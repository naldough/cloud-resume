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

# --- AI resume assistant ---

variable "assistant_subdomain" {
  type        = string
  description = "Subdomain the resume assistant API is served on, e.g. \"api\" -> api.<domain_name>."
  default     = "api"
}

variable "anthropic_model" {
  type        = string
  description = "Anthropic model ID used by the resume assistant Lambda."
  default     = "claude-haiku-4-5-20251001"
}

variable "assistant_rate_limit_max_requests" {
  type        = number
  description = "Max chat requests a single IP may make per assistant_rate_limit_window_seconds."
  default     = 8
}

variable "assistant_rate_limit_window_seconds" {
  type        = number
  description = "Length of the fixed window (seconds) used for per-IP rate limiting."
  default     = 3600
}