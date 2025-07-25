terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    encrypt = true
    bucket = "mothersect-tf-state"
    dynamodb_table = "mothersect-tf-state-lock"
    key    = "cftest"
    region = "us-east-1"
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}

# Can possibly be replaced with the template module.
# https://registry.terraform.io/modules/hashicorp/dir/template/latest
locals {
  s3_origin_id = var.domain_url
  cf_logs_bucket = join("-", [replace(var.domain_url, ".", "-"), "logs"])
}

resource "aws_s3_bucket" "cftest" {
  bucket = var.domain_url
}

resource "aws_s3_bucket_public_access_block" "cftest" {
  bucket = aws_s3_bucket.cftest_logs.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "cftest_public_read" {
  bucket = aws_s3_bucket.cftest.id
  policy = data.aws_iam_policy_document.cftest_public_read.json
}

data "aws_iam_policy_document" "cftest_public_read" {
  statement {
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = [
      "s3:GetObject",
    ]

    resources = [
      "${aws_s3_bucket.cftest.arn}/*",
    ]
  }
}

resource "aws_s3_bucket_ownership_controls" "cftest" {
  bucket = aws_s3_bucket.cftest.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_website_configuration" "cftest" {
  bucket = aws_s3_bucket.cftest.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_route53_record" "cftest" {
  zone_id = var.zone_id
  name    = "${var.domain_url}."
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cftest.domain_name
    zone_id                = aws_cloudfront_distribution.cftest.hosted_zone_id
    evaluate_target_health = false
  }
}

# Load the source files.
resource "aws_s3_object" "index" {
  content_type = "text/html"
  bucket       = aws_s3_bucket.cftest.id
  key          = "index.html"
  source       = "index.html"
  etag        = filemd5("index.html")
}

resource "aws_s3_object" "kirsche" {
  content_type = "image/png"
  bucket       = aws_s3_bucket.cftest.id
  key          = "kirsche.png"
  source       = "kirsche.png"
  etag        = filemd5("kirsche.png")
}

