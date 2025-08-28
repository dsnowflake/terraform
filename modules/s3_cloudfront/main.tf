provider "aws" {
  region = "us-east-1" # CloudFront requires ACM certificates in us-east-1
}

# S3 bucket for the application
resource "aws_s3_bucket" "app_bucket" {
  bucket = "${var.app_name}-${var.environment}"
  tags   = merge(var.tags, { Environment = var.environment })
}

resource "aws_s3_bucket_ownership_controls" "app_bucket" {
  bucket = aws_s3_bucket.app_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "app_bucket" {
  bucket                  = aws_s3_bucket.app_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "app_bucket" {
  bucket = aws_s3_bucket.app_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket for CloudFront access logs
resource "aws_s3_bucket" "logs_bucket" {
  bucket = "${var.app_name}-${var.environment}-logs"
  tags   = merge(var.tags, { Environment = var.environment })
}

resource "aws_s3_bucket_ownership_controls" "logs_bucket" {
  bucket = aws_s3_bucket.logs_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "logs_bucket" {
  bucket                  = aws_s3_bucket.logs_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Origin access identity for CloudFront
resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "OAI for ${var.app_name} ${var.environment}"
}

# Policy to allow CloudFront to access the S3 bucket
data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.app_bucket.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.oai.iam_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.app_bucket.id
  policy = data.aws_iam_policy_document.s3_policy.json
}

# CloudFront distribution
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.app_bucket.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.app_bucket.id}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.app_name} ${var.environment} distribution"
  default_root_object = "index.html"

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.logs_bucket.bucket_domain_name
    prefix          = "cloudfront-logs/"
  }

  # Ensure the distribution is only accessible during the challenge period
  # by setting a Web Application Firewall (WAF) restriction
  web_acl_id = aws_wafv2_web_acl.time_restriction.arn

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.app_bucket.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_100" # Use only North America and Europe

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = merge(var.tags, { Environment = var.environment })

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# Create a WAF Web ACL to restrict access based on time
resource "aws_wafv2_web_acl" "time_restriction" {
  name        = "${var.app_name}-${var.environment}-time-restriction"
  description = "Web ACL to restrict access after challenge end date"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "time-based-restriction"
    priority = 1

    action {
      block {}
    }

    statement {
      size_constraint_statement {
        field_to_match {
          single_header {
            name = "date"
          }
        }
        comparison_operator = "GT"
        size                = 0 # This is a placeholder, we'll use a custom rule with AWS WAF
        text_transformation {
          priority = 0
          type     = "NONE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "TimeBasedRestriction"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "TimeBasedWebACL"
    sampled_requests_enabled   = true
  }
}