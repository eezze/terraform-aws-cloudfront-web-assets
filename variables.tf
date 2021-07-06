# -----------------------------------------------------------------------------
# Variables: General
# -----------------------------------------------------------------------------
variable "environment" {
  description = "AWS resource environment/prefix"
}

variable "region" {
  description = "AWS region"
}

variable "resource_tag_name" {
  description = "Resource tag name for cost tracking"
}

variable "cloudfront_web_assets_module_enabled" {
  type        = bool
  description = "(Optional) Whether to create resources within the module or not. Default is true."
  default     = true
}

# -----------------------------------------------------------------------------
# Variables: S3 CloudFront
# -----------------------------------------------------------------------------
variable "domain_name" {
  description = "Name of the domain and the S3 bucket"
}

variable "price_class" {
  type        = string
  description = "Valid Values in order of price (low, high): PriceClass_100 | PriceClass_200 | PriceClass_All"
  default     = "PriceClass_100"
}

variable "website_enabled" {
  type    = bool
  default = false
}

variable "websocket_enabled" {
  type    = bool
  default = false
}

variable "assets_enabled" {
  type    = bool
  default = false
}

variable "s3_index_document" {
  type        = string
  description = "(Required, unless using redirect_all_requests_to) Amazon S3 returns this index document when requests are made to the root domain or any of the subfolders."
  default     = "index.html"
}

variable "s3_error_document" {
  type        = string
  description = "(Optional) An absolute path to the document to return in case of a 4XX error."
  default     = "error.html"
}

variable "s3_redirect_all_requests_to" {
  description = "A hostname to redirect all website requests for this bucket to. Hostname can optionally be prefixed with a protocol (http:// or https://) to use when redirecting requests. The default is the protocol that is used in the original request."
  default     = null
}

variable "acm_validation_method" {
  type        = string
  default     = "DNS"
  description = "(Required) Which method to use for validation. DNS or EMAIL are valid, NONE can be used for certificates that were imported into ACM and then into Terraform."
}

variable "lambda_function_association_map" {
  type = list(object({
    event_type   = string
    lambda_arn   = string
    include_body = bool
  }))
  default     = []
  description = "(optional) The specific event to trigger this function. Valid values: viewer-request, origin-request, viewer-response, origin-response"
}

variable dynamic_ordered_cache_behavior {
  description = "Ordered Cache Behaviors to be used in dynamic block"
  type        = any
  default     = []
}

variable dynamic_custom_origin_config {
  description = "Additional Custom Origin Configuration (optional)"
  type        = any
  default     = []
}