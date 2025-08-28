provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    bucket = "terraform-state-myapp"
    key    = "devel/terraform.tfstate"
    region = "us-east-1"
  }
}

module "s3_cloudfront" {
  source = "../../modules/s3_cloudfront"

  environment        = "devel"
  app_name           = var.app_name
  challenge_end_date = var.challenge_end_date
  
  tags = {
    Environment = "devel"
    ManagedBy   = "terraform"
    Project     = var.app_name
  }
}

output "cloudfront_domain" {
  value = module.s3_cloudfront.cloudfront_domain_name
}

output "app_bucket_name" {
  value = module.s3_cloudfront.app_bucket_name
}