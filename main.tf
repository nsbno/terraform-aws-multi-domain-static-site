# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------

data "aws_caller_identity" "current-account" {}

locals {
  validation_options_by_domain_name = { for opt in aws_acm_certificate.cert_website.domain_validation_options : opt.domain_name => opt }
  all_domains_static                = { for obj in concat([var.domain_name], var.subject_alternative_names) : obj.name => obj }
  all_domains_dynamic = { for name, v in local.all_domains_static : name => merge(v, {
    /*
    // NOTE: `domain_validation_options` may reference stale data due to issues with the AWS provider,
    // so we default to a known value if this is the case.
    */
    validation_options = lookup(local.validation_options_by_domain_name, name, values(local.validation_options_by_domain_name)[0])
    zone_id            = data.aws_route53_zone.zone[name].id
    })
  }
}

data "aws_route53_zone" "zone" {
  for_each = local.all_domains_static
  name     = each.value.zone
}

resource "aws_acm_certificate" "cert_website" {
  domain_name               = var.domain_name.name
  validation_method         = "DNS"
  provider                  = aws.certificate_provider
  subject_alternative_names = [for obj in var.subject_alternative_names : obj.name]
  tags                      = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_website_validation" {
  depends_on      = [aws_acm_certificate.cert_website]
  for_each        = local.all_domains_static
  name            = local.all_domains_dynamic[each.key].validation_options.resource_record_name
  type            = local.all_domains_dynamic[each.key].validation_options.resource_record_type
  records         = [local.all_domains_dynamic[each.key].validation_options.resource_record_value]
  zone_id         = local.all_domains_dynamic[each.key].zone_id
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.cert_website.arn
  provider                = aws.certificate_provider
  validation_record_fqdns = values(aws_route53_record.cert_website_validation).*.fqdn
  timeouts {
    create = var.certificate_validation_timeout
  }
}

data "aws_s3_bucket" "website_bucket" {
  bucket = (var.website_bucket == "" ? aws_s3_bucket.website_bucket[0].id : var.website_bucket)
}

resource "aws_s3_bucket" "website_bucket" {
  count  = (var.use_external_bucket == false ? 1 : 0)
  bucket = "${data.aws_caller_identity.current-account.account_id}-${var.service_name}-static-files"
}

resource "aws_s3_bucket_ownership_controls" "website_bucket" {
  count  = (var.use_external_bucket == false ? 1 : 0)
  bucket = aws_s3_bucket.website_bucket[0].id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "website_bucket" {
  count  = (var.use_external_bucket == false ? 1 : 0)
  bucket = aws_s3_bucket.website_bucket[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_website_configuration" "website_bucket" {
  count = (var.use_external_bucket == false ? 1 : 0)

  bucket = aws_s3_bucket.website_bucket[0].bucket

  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_versioning" "website_bucket" {
  count = (var.use_external_bucket == false ? 1 : 0)

  bucket = aws_s3_bucket.website_bucket[0].bucket

  versioning_configuration {
    status = "Enabled"
  }
}


resource "aws_s3_bucket_policy" "website_bucket_policy" {
  bucket = data.aws_s3_bucket.website_bucket.id
  policy = var.use_oai ? data.aws_iam_policy_document.s3_policy_oai[0].json : data.aws_iam_policy_document.s3_policy_oac[0].json
}

resource "aws_cloudfront_origin_access_control" "origin_access_control" {
  count                             = var.use_oai ? 0 : 1
  name                              = "${data.aws_caller_identity.current-account.account_id}-${var.service_name}-oac"
  description                       = "Origin access control for S3 static site"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# OAI (optional legacy)
resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  count   = (var.use_oai || var.keep_oai_for_migration) ? 1 : 0
  comment = "origin access identity for s3/cloudfront"
}

resource "aws_cloudfront_cache_policy" "static_site_cache_policy" {
  name        = "${data.aws_caller_identity.current-account.account_id}-${var.service_name}-policy"
  comment     = "Cache policy for static site"
  default_ttl = var.cache_default_ttl
  max_ttl     = var.cache_max_ttl
  min_ttl     = var.cache_min_ttl

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }

    headers_config {
      header_behavior = "none"
    }

    query_strings_config {
      query_string_behavior = "none"
    }

    enable_accept_encoding_gzip   = true
    enable_accept_encoding_brotli = true
  }
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  depends_on = [
    aws_acm_certificate_validation.main,
  ]

  origin {
    domain_name = data.aws_s3_bucket.website_bucket.bucket_regional_domain_name
    origin_id   = "S3-${data.aws_s3_bucket.website_bucket.id}"

    # For OAC (default): set origin_access_control_id
    origin_access_control_id = var.use_oai ? null : aws_cloudfront_origin_access_control.origin_access_control[0].id

    # For OAI (legacy): include s3_origin_config
    dynamic "s3_origin_config" {
      for_each = var.use_oai ? [1] : []
      content {
        origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity[0].cloudfront_access_identity_path
      }
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  aliases             = keys(local.all_domains_static)

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  default_cache_behavior {
    allowed_methods = [
      "DELETE",
      "GET",
      "HEAD",
      "OPTIONS",
      "PATCH",
      "POST",
      "PUT",
    ]

    cached_methods = [
      "GET",
      "HEAD",
    ]

    target_origin_id = "S3-${data.aws_s3_bucket.website_bucket.id}"

    cache_policy_id        = aws_cloudfront_cache_policy.static_site_cache_policy.id
    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = var.cloudfront_price_class

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.cert_website.arn
    ssl_support_method  = "sni-only"
	minimum_protocol_version = var.minimum_protocol_version
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

resource "aws_route53_record" "www_a" {
  for_each = local.all_domains_static
  name     = "${each.key}."
  type     = "A"
  zone_id  = local.all_domains_dynamic[each.key].zone_id
  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

# OAC-style policy (default)
data "aws_iam_policy_document" "s3_policy_oac" {
  count = var.use_oai ? 0 : 1

  statement {
    sid       = "AllowCloudFrontReadOAC"
    actions   = ["s3:GetObject"]
    resources = ["${data.aws_s3_bucket.website_bucket.arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.s3_distribution.arn]
    }
  }
}

# OAI-style policy (legacy)
data "aws_iam_policy_document" "s3_policy_oai" {
  count = var.use_oai ? 1 : 0

  statement {
    sid       = "AllowOAIRead"
    actions   = ["s3:GetObject"]
    resources = ["${data.aws_s3_bucket.website_bucket.arn}/*"]
    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.origin_access_identity[0].iam_arn]
    }
  }
}
