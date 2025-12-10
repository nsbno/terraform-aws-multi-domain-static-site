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

resource "aws_route53_zone" "alternative" {
  name = "test.demoinfra.vydev.io"
}

module "static_site" {
  source = "../../"

  providers = {
    aws.certificate_provider = aws.certificate_provider
  }

  service_name = "petstore"

  domain_name = {
    name = "dogstore.test.infrademo.vydev.io"
    zone = aws_route53_zone.main.name
  }

  subject_alternative_names = [
    {
      name = "catstore.test.demoinfra.vydev.io"
      zone = aws_route53_zone.alternative.name
    }
  ]
}
