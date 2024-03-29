# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "name_prefix" {
  description = "A prefix used for naming resources."
  type        = string
}

variable "bucket_versioning" {
  description = "(Optional) Enable versioning. Once you version-enable a bucket, it can never return to an unversioned state. You can, however, suspend versioning on that bucket."
  type        = bool
  default     = true
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

variable "enable_directory_index" {
  description = "(Optional) Map URIs ending in / or without a file ending to 'index.html'"
  type        = bool
  default     = false
}
