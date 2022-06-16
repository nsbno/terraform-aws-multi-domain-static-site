terraform {
  required_version = ">= 0.12"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      configuration_aliases = [
        aws.certificate_provider
      ]
      version = ">= 2.65.0"
    }
  }
}
