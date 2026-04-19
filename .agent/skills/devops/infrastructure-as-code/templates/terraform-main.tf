# Main Terraform Configuration
# This is the entry point for Terraform infrastructure provisioning

terraform {
  # Required Terraform version
  required_version = ">= 1.5.0"

  # Required providers with version constraints
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state backend configuration
  # Options: s3 (AWS), azurerm (Azure), gcs (GCP), remote (Terraform Cloud)
  backend "s3" {
    # AWS S3 bucket for state storage
    bucket         = "terraform-state-prod"
    key            = "infrastructure/terraform.tfstate"
    region         = "us-east-1"

    # State encryption
    encrypt        = true

    # State locking with DynamoDB
    dynamodb_table = "terraform-locks-prod"

    # Additional options
    kms_key_id     = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
  }
}

# AWS Provider Configuration
provider "aws" {
  region = var.aws_region

  # Default tags for all resources
  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "terraform"
      Project     = var.project_name
      CostCenter  = var.cost_center
    }
  }

  # Assume role for cross-account access (optional)
  # assume_role {
  #   role_arn     = "arn:aws:iam::123456789012:role/TerraformExecutionRole"
  #   session_name = "terraform-session"
  #   external_id  = var.external_id
  # }
}

# Azure Provider Configuration (optional)
# provider "azurerm" {
#   features {}
#
#   subscription_id = var.azure_subscription_id
#   tenant_id       = var.azure_tenant_id
#   client_id       = var.azure_client_id
#   client_secret   = var.azure_client_secret
# }

# GCP Provider Configuration (optional)
# provider "google" {
#   project = var.gcp_project
#   region  = var.gcp_region
# }

# Data Sources: Retrieve existing resources

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Remote state data sources for cross-module references
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "terraform-state-prod"
    key    = "network/terraform.tfstate"
    region = "us-east-1"
  }
}

# Local values for computed values
locals {
  common_tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = var.project_name
    CostCenter  = var.cost_center
    Compliance  = var.compliance_level
  }

  name_prefix = "${var.project_name}-${var.environment}"

  availability_zones = [
    "${var.aws_region}a",
    "${var.aws_region}b",
    "${var.aws_region}c"
  ]
}

# Resource Groupings
module "network" {
  source = "./modules/network"

  name            = local.name_prefix
  vpc_cidr        = var.vpc_cidr
  availability_zones = local.availability_zones

  enable_nat_gateway = var.enable_nat_gateway
  enable_vpn_gateway = var.enable_vpn_gateway

  tags = local.common_tags
}

module "compute" {
  source = "./modules/compute"

  name            = local.name_prefix
  instance_type   = var.instance_type
  ami_id          = data.aws_ami.ubuntu.id

  vpc_id          = module.network.vpc_id
  subnet_ids      = module.network.private_subnet_ids
  security_groups = [module.network.security_group_id]

  instance_count = var.instance_count

  tags = local.common_tags
}

module "database" {
  source = "./modules/database"

  name              = local.name_prefix
  engine            = var.database_engine
  engine_version    = var.database_version
  instance_class    = var.database_instance_class

  allocated_storage = var.database_storage
  username          = var.database_username
  password          = var.database_password

  vpc_id            = module.network.vpc_id
  subnet_ids        = module.network.database_subnet_ids
  security_group_id = module.network.database_security_group_id

  multi_az          = var.database_multi_az
  backup_retention  = var.database_backup_retention

  tags = local.common_tags
}

module "storage" {
  source = "./modules/storage"

  name        = local.name_prefix
  bucket_name = "${local.name_prefix}-storage"

  versioning  = var.storage_versioning
  encryption  = var.storage_encryption

  lifecycle_rules = var.storage_lifecycle_rules

  tags = local.common_tags
}

# Load Balancer (optional)
module "load_balancer" {
  source = "./modules/load_balancer"

  name         = local.name_prefix
  type         = var.load_balancer_type # "application" or "network"

  vpc_id       = module.network.vpc_id
  subnet_ids   = module.network.public_subnet_ids

  certificate_arn = var.acm_certificate_arn

  target_groups = [
    {
      name             = "web-servers"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
    }
  ]

  tags = local.common_tags

  count = var.enable_load_balancer ? 1 : 0
}

# Auto Scaling (optional)
module "autoscaling" {
  source = "./modules/autoscaling"

  name           = local.name_prefix
  image_id       = data.aws_ami.ubuntu.id
  instance_type  = var.instance_type

  vpc_id         = module.network.vpc_id
  subnet_ids     = module.network.private_subnet_ids
  security_groups = [module.network.security_group_id]

  min_size       = var.asg_min_size
  max_size       = var.asg_max_size
  desired_size   = var.asg_desired_size

  health_check_type = "EC2"
  health_check_grace_period = 300

  target_group_arns = var.enable_load_balancer ? [module.load_balancer[0].target_group_arns[0]] : []

  tags = local.common_tags

  count = var.enable_autoscaling ? 1 : 0
}

# Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.network.private_subnet_ids
}

output "instance_ids" {
  description = "EC2 instance IDs"
  value       = module.compute.instance_ids
}

output "instance_public_ips" {
  description = "EC2 instance public IPs"
  value       = module.compute.public_ips
}

output "database_endpoint" {
  description = "Database endpoint"
  value       = module.database.endpoint
  sensitive   = true
}

output "storage_bucket_name" {
  description = "S3 bucket name"
  value       = module.storage.bucket_name
}

output "load_balancer_dns" {
  description = "Load balancer DNS name"
  value       = var.enable_load_balancer ? module.load_balancer[0].dns_name : null
}

output "load_balancer_zone_id" {
  description = "Load balancer Route53 zone ID"
  value       = var.enable_load_balancer ? module.load_balancer[0].zone_id : null
}
