# Main Terraform configuration for AWS infrastructure

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Cau hinh backend dang partial. Gia tri thuc nam o envs/<env>/backend.hcl
  # va duoc truyen vao bang:
  #   terraform init -backend-config=envs/dev/backend.hcl
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region

  # Gan tag cho MOI tai nguyen ma provider nay tao ra.
  # Nho vay loc chi phi theo Project trong Cost Explorer moi chinh xac.
  default_tags {
    tags = {
      Project     = "DevOps-Project-01"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "nghiand224"
    }
  }
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  environment     = var.environment
  vpc_cidr        = var.vpc_cidr
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
  azs             = var.availability_zones
}

# Security Module
module "security" {
  source = "./modules/security"

  environment             = var.environment
  vpc_id                  = module.vpc.vpc_id
  allowed_ssh_cidr_blocks = var.allowed_ssh_cidr_blocks
}

# RDS Module
module "rds" {
  source = "./modules/rds"

  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.security.db_security_group_id]
  db_name            = var.db_name
  db_username        = var.db_username
  db_password        = var.db_password
}

# Application Load Balancer Module
module "alb" {
  source = "./modules/alb"

  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  public_subnets    = module.vpc.public_subnet_ids
  security_group_id = module.security.alb_security_group_id
  health_check_path = var.health_check_path
}

# Auto Scaling Group Module
module "asg" {
  source = "./modules/asg"

  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  security_group_ids = [module.security.app_security_group_id]
  target_group_arns  = [module.alb.target_group_arn]
  instance_type      = var.instance_type
  key_name           = var.key_name
  min_size           = var.asg_min_size
  max_size           = var.asg_max_size
  desired_capacity   = var.asg_desired_capacity
}

# CloudWatch Module
module "monitoring" {
  source = "./modules/monitoring"

  environment     = var.environment
  rds_instance_id = module.rds.rds_instance_id
  asg_name        = module.asg.asg_name
} 