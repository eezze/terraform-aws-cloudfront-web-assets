# Terraform AWS CloudFront for Web and Assets Storage on AWS S3

[![Open in Visual Studio Code](https://open.vscode.dev/badges/open-in-vscode.svg)](https://open.vscode.dev/eezze/terraform-aws-cloudfront-web-assets)

## About:

Deploys an AWS CloudFront distribution that supports two domains and optionally an AWS API Gateway Websocket domain;
  1) **Web application domain** (e.g. https://example.com). 
     - Enabled with ``domain_enabled`` set to ``true``, default; ``false``.
  2) **Assets domain** for image etc. storage that complements the web domain (e.g. https://assets.example.com). 
     - Enabled with ``assets_enabled`` set to ``true``, default; ``false``
  3) **AWS API Gateway** (e.g. https://example.com/api/) integration using ``apigateway`` origin_id setup as seen in the example. Must provide the ``var.api_domain_name`` variable.
      - Makes the usage of ``option`` methods (i.e. CORS) in your API Gateway stage configuration not required.
  4) Additionally, there's configuration support for **AWS API Gateway Websockets** (e.g. wss://example.com/ws/). Must provide the ``var.websocket_api_domain_name`` variable.
     - Websockets have specific requirements to allow Header passthrough when put behind an AWS Cloudfront CDN. Enabled with ``websocket_enabled`` set to ``true`` , default; ``false``

The ``domain_name`` parameter must be set.

The module can be switched on and off entirely with ``cloudfront_web_assets_module_enabled`` boolean switch.

## How to use:

```hcl
module "website_s3" {
  source = "github.com/eezze/terraform-aws-cloudfront-web-assets?ref=v1.0"

  resource_tag_name = var.resource_tag_name
  namespace         = var.namespace
  region            = var.region

  assets_domain_name    = var.assets_domain_name
  domain_name           = var.domain_name
  acm_validation_method = var.acm_validation_method

  website_enabled   = true
  websocket_enabled = true
  assets_enabled    = true

  dynamic_custom_origin_config = [
    {
      domain_name = replace("https://${var.api_domain_name}", "/^https?://([^/]*).*/", "$1")
      origin_id   = "apigateway"

      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "https-only"
      origin_ssl_protocols     = ["TLSv1.2"]
      origin_keepalive_timeout = 60
      origin_read_timeout      = 29
    },
    {
      domain_name = replace("wss://${var.websocket_api_domain_name}", "/^wss?://([^/]*).*/", "$1")
      origin_id   = "wss"

      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "https-only"
      origin_ssl_protocols     = ["TLSv1"]
      origin_keepalive_timeout = 60
      origin_read_timeout      = 29
    }
  ]

  dynamic_ordered_cache_behavior = [
    {
      path_pattern     = "/api/*"
      allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
      cached_methods   = ["GET", "HEAD"]
      target_origin_id = "apigateway"

      default_ttl = 0
      min_ttl     = 0
      max_ttl     = 0

      query_string    = true
      cookies_forward = "all"
      headers = [
        "Authorization"
      ]

      viewer_protocol_policy = "redirect-to-https"
    },
    {
      path_pattern     = "/ws/*"
      allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
      cached_methods   = ["GET", "HEAD"]
      target_origin_id = "wss"

      default_ttl = 0
      min_ttl     = 0
      max_ttl     = 0

      query_string    = true
      cookies_forward = "all"

      viewer_protocol_policy = "redirect-to-https"
    }
  ]

  # example how to apply custom authorization to assets domain.
  lambda_function_association_map = [
    {
      event_type   = "viewer-request"
      lambda_arn   = module.lambda-at-edge.lambda_qualified_arn
      include_body = false
    }
  ]
}
```

## Changelog

### v1.1
  - Added ACM certificate create for sub-domains, and Route53 record creation.
  - Merged ``assets_enabled`` create, added additional variable; ``assets_domain_name`` to allow for this. See updated example.

### v1.0
 - Initial release