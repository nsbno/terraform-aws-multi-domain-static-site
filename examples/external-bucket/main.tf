provider "aws" {
  region = "eu-west-1"
}

provider "aws" {
  region = "us-east-1"
  alias  = "certificate_provider"
}

resource "aws_route53_zone" "main" {
  name = "test.infrademo.vydev.io"
}

# Create an external S3 bucket
resource "aws_s3_bucket" "external" {
  bucket = "my-existing-static-site-bucket"
}

resource "aws_s3_bucket_versioning" "external" {
  bucket = aws_s3_bucket.external.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_website_configuration" "external" {
  bucket = aws_s3_bucket.external.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

module "static_site" {
  source = "../../"

  providers = {
    aws.certificate_provider = aws.certificate_provider
  }

  service_name = "petstore"

  domain_name = {
    name = "petstore.test.infrademo.vydev.io"
    zone = aws_route53_zone.main.name
  }

  use_external_bucket = true
  website_bucket      = aws_s3_bucket.external.id
}
