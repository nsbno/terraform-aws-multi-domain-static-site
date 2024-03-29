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
  bucket = "${data.aws_caller_identity.current-account.account_id}-${var.name_prefix}-static-website-bucket"
}

resource "aws_s3_bucket_acl" "website_bucket" {
  count = (var.use_external_bucket == false ? 1 : 0)

  bucket = aws_s3_bucket.website_bucket[0].bucket

  acl = "private"
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
  policy = data.aws_iam_policy_document.s3_policy.json
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "origin access identity for s3/cloudfront"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  depends_on = [
    aws_acm_certificate_validation.main,
  ]

  origin {
    domain_name = data.aws_s3_bucket.website_bucket.bucket_regional_domain_name
    origin_id   = aws_cloudfront_origin_access_identity.origin_access_identity.id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
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

    target_origin_id = aws_cloudfront_origin_access_identity.origin_access_identity.id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0

    dynamic "function_association" {
      for_each = aws_cloudfront_function.default_object_mapper

      content {
        event_type   = "viewer-request"
        function_arn = function_association.value.arn
      }
    }
  }

  price_class = "PriceClass_200"

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.cert_website.arn
    ssl_support_method  = "sni-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

resource "aws_cloudfront_function" "default_object_mapper" {
  count   = var.enable_directory_index ? 1 : 0
  name    = "DefaultObjectMapper"
  runtime = "cloudfront-js-1.0"
  comment = "Appends 'index.html' to requested URL if it ends in / or is missing file ending"
  publish = true
  code    = file("${path.module}/default_index_mapper.js")
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

data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${data.aws_s3_bucket.website_bucket.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn]
    }
  }

  statement {
    actions   = ["s3:ListBucket"]
    resources = [data.aws_s3_bucket.website_bucket.arn]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn]
    }
  }
}

