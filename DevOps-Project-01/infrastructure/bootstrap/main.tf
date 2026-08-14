# Tao noi luu Terraform state.
#
# Cau hinh nay tu no dung local state - bai toan con ga qua trung: chua co
# bucket thi khong the luu state len S3. Chi apply MOT LAN, sau do gan nhu
# khong bao gio dong toi nua.

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-1"

  default_tags {
    tags = {
      Project   = "DevOps-Project-01"
      ManagedBy = "Terraform"
      Component = "tfstate-bootstrap"
    }
  }
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "tfstate" {
  bucket = "nghiand224-tfstate-${data.aws_caller_identity.current.account_id}"

  # Chan xoa nham. Mat state la mat quyen kiem soat toan bo ha tang:
  # Terraform khong con biet no dang quan ly nhung tai nguyen nao.
  # Muon xoa that thi phai sua dong nay truoc.
  lifecycle {
    prevent_destroy = true
  }
}

# Versioning cho phep khoi phuc state neu apply hong giua chung.
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# State file chua ID tai nguyen va cau hinh ha tang. Khong bao gio duoc public.
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bang lock chan hai lan apply chay dong thoi lam hong state.
resource "aws_dynamodb_table" "tfstate_lock" {
  name         = "nghiand224-tfstate-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
