provider "aws" {
  region = "eu-west-1"
}

provider "aws" {
  region = "us-east-1"
  alias  = "certificate_provider"
}

resource "aws_route53_zone" "main" {
  name = "example.com"
}

resource "aws_route53_zone" "alternative" {
  name = "example.net"
}

module "static-example" {
  source = "../../"
  providers = {
    aws.certificate_provider = aws.certificate_provider
  }
  name_prefix = "static-example"
  domain_name = {
    name = "static.example.com"
    zone = aws_route53_zone.main.name
  }
  subject_alternative_names = [
    {
      name = "static.example.net"
      zone = aws_route53_zone.alternative.name
    }
  ]
}
