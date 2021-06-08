locals {
  resource_name_prefix = "${var.environment}-${var.resource_tag_name}"
  origin_domain_name   = var.website == true ? join("", aws_s3_bucket.website.*.bucket_regional_domain_name) : join("", aws_s3_bucket.assets.*.bucket_regional_domain_name)
  s3_bucket_arn        = var.website == true ? join("", aws_s3_bucket.website.*.arn) : join("", aws_s3_bucket.assets.*.arn)

  tags = {
    Name        = var.resource_tag_name
    Environment = var.environment
  }
}

# -----------------------------------------------------------------------------
# S3: Access only via CloudFront distribution
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "assets" {
  count  = var.assets && var.cloudfront_web_assets_module_enabled ? 1 : 0
  bucket = var.domain_name
  acl    = "private"

  tags = local.tags
}

resource "aws_s3_bucket" "website" {
  count  = var.website && var.cloudfront_web_assets_module_enabled ? 1 : 0
  bucket = var.domain_name
  acl    = "private"

  website {
    index_document           = var.s3_index_document
    error_document           = var.s3_error_document
    redirect_all_requests_to = var.s3_redirect_all_requests_to
  }

  tags = local.tags
}

data "aws_iam_policy_document" "origin" {
  statement {
    sid = "S3GetObjectForCloudFront"

    actions   = ["s3:GetObject"]
    resources = ["${local.s3_bucket_arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity._.iam_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "website" {
  count  = var.website && var.cloudfront_web_assets_module_enabled ? 1 : 0
  bucket = join("", aws_s3_bucket.website.*.id)
  policy = data.aws_iam_policy_document.origin.json
}

resource "aws_s3_bucket_policy" "assets" {
  count  = var.assets && var.cloudfront_web_assets_module_enabled ? 1 : 0
  bucket = join("", aws_s3_bucket.assets.*.id)
  policy = data.aws_iam_policy_document.origin.json
}

# -----------------------------------------------------------------------------
# ACM Certificates
# -----------------------------------------------------------------------------

resource "aws_acm_certificate" "_" {
  count  = var.cloudfront_web_assets_module_enabled ? 1 : 0

  domain_name       = var.domain_name
  validation_method = var.acm_validation_method

  tags = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "_" {
  count  = var.cloudfront_web_assets_module_enabled ? 1 : 0
  
  certificate_arn = one(aws_acm_certificate._.*.arn)
}

# -----------------------------------------------------------------------------
# CloudFront
# -----------------------------------------------------------------------------
resource "aws_cloudfront_origin_access_identity" "_" {
  count  = var.cloudfront_web_assets_module_enabled ? 1 : 0

  comment = "${local.resource_name_prefix}-cloudfront-OAI for ${var.domain_name}"
}

# If there's a websocket connection, we need to whitelist these headers
resource "aws_cloudfront_origin_request_policy" "_" {
  count   = var.websocket && var.cloudfront_web_assets_module_enabled ? 1 : 0
  name    = "${local.resource_name_prefix}-cloudfront-websocket-policy"
  comment = "Websocket Header Allow Policy"

  cookies_config {
    cookie_behavior = "none"
  }

  query_strings_config {
    query_string_behavior = "all"
  }

  headers_config {
    header_behavior = "whitelist"
    headers {
      items = [
        "Sec-WebSocket-Key",
        "Sec-WebSocket-Version",
        "Sec-WebSocket-Protocol",
        "Sec-WebSocket-Accept"
      ]
    }
  }
}
resource "aws_cloudfront_distribution" "_" {
  count  = var.cloudfront_web_assets_module_enabled ? 1 : 0

  origin {
    domain_name = local.origin_domain_name
    origin_id   = var.domain_name
  
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity._.cloudfront_access_identity_path
    }
  }

  # Optional additional custom Origin configurations
  dynamic "origin" {
    for_each = [for i in var.dynamic_custom_origin_config : {
      name                     = i.domain_name
      id                       = i.origin_id
      path                     = lookup(i, "origin_path", null)
      http_port                = i.http_port
      https_port               = i.https_port
      origin_keepalive_timeout = i.origin_keepalive_timeout
      origin_read_timeout      = i.origin_read_timeout
      origin_protocol_policy   = i.origin_protocol_policy
      origin_ssl_protocols     = i.origin_ssl_protocols
      custom_header            = lookup(i, "custom_header", null)
    }]
    content {
      domain_name = origin.value.name
      origin_id   = origin.value.id
      origin_path = origin.value.path

      dynamic "custom_header" {
        for_each = origin.value.custom_header == null ? [] : [for i in origin.value.custom_header : {
          name  = i.name
          value = i.value
        }]
        content {
          name  = custom_header.value.name
          value = custom_header.value.value
        }
      }

      custom_origin_config {
        http_port                = origin.value.http_port
        https_port               = origin.value.https_port
        origin_keepalive_timeout = origin.value.origin_keepalive_timeout
        origin_read_timeout      = origin.value.origin_read_timeout
        origin_protocol_policy   = origin.value.origin_protocol_policy
        origin_ssl_protocols     = origin.value.origin_ssl_protocols
      }
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = var.s3_index_document

  aliases = [var.domain_name]

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = var.domain_name
    
    forwarded_values {
      query_string = true

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400

    dynamic "lambda_function_association" {
      for_each = var.lambda_function_association_map
      content {
        event_type   = lambda_function_association.value.event_type
        lambda_arn   = lambda_function_association.value.lambda_arn
        include_body = lambda_function_association.value.include_body
      }
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = var.dynamic_ordered_cache_behavior
    iterator = cache_behavior

    content {
      path_pattern     = cache_behavior.value.path_pattern
      allowed_methods  = cache_behavior.value.allowed_methods
      cached_methods   = cache_behavior.value.cached_methods
      target_origin_id = cache_behavior.value.target_origin_id
      compress         = lookup(cache_behavior.value, "compress", null)

      forwarded_values {
        query_string = cache_behavior.value.query_string
        cookies {
          forward = cache_behavior.value.cookies_forward
        }
        headers = lookup(cache_behavior.value, "headers", null)
      }

      dynamic "lambda_function_association" {
        iterator = lambda
        for_each = lookup(cache_behavior.value, "lambda_function_association", [])
        content {
          event_type   = lambda.value.event_type
          lambda_arn   = lambda.value.lambda_arn
          include_body = lookup(lambda.value, "include_body", null)
        }
      }

      viewer_protocol_policy = cache_behavior.value.viewer_protocol_policy
      min_ttl                = lookup(cache_behavior.value, "min_ttl", null)
      default_ttl            = lookup(cache_behavior.value, "default_ttl", null)
      max_ttl                = lookup(cache_behavior.value, "max_ttl", null)
    }
  } 

  # cheapest default
  price_class = var.price_class

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  tags = local.tags

  viewer_certificate {
    cloudfront_default_certificate = false
    acm_certificate_arn            = aws_acm_certificate._.arn
    ssl_support_method             = "sni-only"
  }

  lifecycle {
    ignore_changes = [ 
      origin,
      ordered_cache_behavior
     ]
  }
}