# =============================================================================
# S3 Backend Outputs
# AGL Hostman - Infrastructure as Code
# =============================================================================

output "state_bucket_name" {
  description = "S3 bucket name for Terraform state"
  value       = var.create_state_bucket ? aws_s3_bucket.terraform_state[0].id : var.state_bucket_name
}

output "state_bucket_arn" {
  description = "S3 bucket ARN"
  value       = var.create_state_bucket ? aws_s3_bucket.terraform_state[0].arn : null
}

output "state_bucket_domain_name" {
  description = "S3 bucket domain name"
  value       = var.create_state_bucket ? aws_s3_bucket.terraform_state[0].bucket_domain_name : null
}

output "state_logs_bucket" {
  description = "S3 bucket name for state logs"
  value       = var.create_state_bucket ? aws_s3_bucket.state_logs[0].id : null
}

output "state_lock_table_name" {
  description = "DynamoDB table name for state locking"
  value       = var.create_state_resources ? aws_dynamodb_table.terraform_state_lock[0].id : var.state_lock_table_name
}

output "state_lock_table_arn" {
  description = "DynamoDB table ARN"
  value       = var.create_state_resources ? aws_dynamodb_table.terraform_state_lock[0].arn : null
}

output "state_kms_key_id" {
  description = "KMS key ID for state encryption"
  value       = var.create_state_resources && var.create_kms_key ? aws_kms_key.terraform_state[0].id : null
}

output "state_kms_key_arn" {
  description = "KMS key ARN for state encryption"
  value       = var.create_state_resources && var.create_kms_key ? aws_kms_key.terraform_state[0].arn : null
}

output "state_backend_config" {
  description = "Backend configuration for use in other Terraform configs"
  value = {
    bucket         = var.state_bucket_name
    key            = "infrastructure/terraform.tfstate"
    region         = var.state_bucket_region
    encrypt        = true
    dynamodb_table = var.state_lock_table_name
    kms_key_id    = var.create_state_resources && var.create_kms_key ? aws_kms_alias.terraform_state[0].name : null
  }
}

output "aws_cli_profile" {
  description = "AWS CLI profile command"
  value       = "export AWS_PROFILE=${var.aws_profile}"
}

output "init_commands" {
  description = "Commands to initialize Terraform with this backend"
  value = {
    s3 = "terraform init -backend-config='bucket=${var.state_bucket_name}' -backend-config='key=infrastructure/terraform.tfstate' -backend-config='region=${var.state_bucket_region}'"
  }
}

output "migration_commands" {
  description = "Commands to migrate existing state to this backend"
  value = {
    from_local = "terraform init -migrate-state -backend-config='bucket=${var.state_bucket_name}'"
    from_azurerm = "terraform init -migrate-state -backend-config='bucket=${var.state_bucket_name}' -backend-config='key=infrastructure/terraform.tfstate'"
  }
}
