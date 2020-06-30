# terraform-aws-multi-domain-static-site
A Terraform module that creates the necessary infrastructure for hosting a static frontend application on AWS using CloudFront and S3.

This includes the provisioning of at least an ACM certificate and a CloudFront distribution. The module can either create a new S3 bucket, or reuse an existing one.

## Caveats
There are many issues with the `aws_acm_certificate` resource, and it is due for a rewrite in v3.0 of the AWS provider. The progress of this can be tracked [here](https://github.com/terraform-providers/terraform-provider-aws/issues/13053).

If you have more than one item in `subject_alternative_names`, the certificate may be recreated even though changes haven't been made, which in turn will update the CloudFront distribution (which can take 5-15 minutes). As such, the module is best-suited for two domains: one given by `domain_name`, and one item in `subject_alternative_names`.
