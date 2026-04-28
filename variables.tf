variable "service_name" {
  description = "The name of the service using this module."
  type        = string
}

variable "use_oai" {
  description = "Use legacy CloudFront Origin Access Identity (OAI) instead of OAC. Default false (OAC)."
  type        = bool
  default     = false
}

variable "keep_oai_for_migration" {
  description = "Keeps the OAI resource so Terraform does not delete it during OAC migration."
  type        = bool
  default     = false
}

variable "tags" {
  description = "A map of tags (key-value pairs) passed to resources."
  type        = map(string)
  default     = {}
}

variable "domain_name" {
  description = "A map containing a domain and name of the associated hosted zone. The domain will be associated with the CloudFront distribution and ACM certificate."
  type        = map(string)
}

variable "subject_alternative_names" {
  description = "A list of maps containing domains and names of their associated hosted zones. The domains will be associated with the CloudFront distribution and ACM certificate."
  default     = []
  type        = list(map(string))
}

variable "use_external_bucket" {
  description = "Set this value to true if you wish to supply an existing bucket to use for this site"
  type        = bool
  default     = false
}

variable "website_bucket" {
  description = "(Optional) The name of an existing bucket to use - if not set the module will create a bucket"
  type        = string
  default     = ""
}

variable "certificate_validation_timeout" {
  description = "(Optional) How long to wait for the certificate to be issued."
  type        = string
  default     = "45m"
}

variable "cloudfront_price_class" {
  description = "The price class for CloudFront distribution. Options: PriceClass_All, PriceClass_200, PriceClass_100"
  type        = string
  default     = "PriceClass_100"
}

variable "cache_min_ttl" {
  description = "Minimum cache time to live in seconds"
  type        = number
  default     = 0
}

variable "cache_default_ttl" {
  description = "Default cache time to live in seconds"
  type        = number
  default     = 3600
}

variable "cache_max_ttl" {
  description = "Maximum cache time to live in seconds"
  type        = number
  default     = 86400
}

variable "minimum_protocol_version" {
  description = "The minimum SSL/TLS protocol that CloudFront will use to communicate with viewers."
  type        = string
  default     = "TLSv1.2_2021"
}
