# =============================================================================
# S3 Backend Variables
# AGL Hostman - Infrastructure as Code
# =============================================================================

variable "create_state_bucket" {
  description = "Create S3 bucket for Terraform state"
  type        = bool
  default     = true
}

variable "create_state_resources" {
  description = "Create DynamoDB lock table and other resources"
  type        = bool
  default     = true
}

variable "create_kms_key" {
  description = "Create KMS key for state encryption"
  type        = bool
  default     = false
}

variable "state_bucket_name" {
  description = "S3 bucket name for Terraform state"
  type        = string
  default     = "agl-terraform-state"
}

variable "state_lock_table_name" {
  description = "DynamoDB table name for state locking"
  type        = string
  default     = "terraform-state-lock"
}

variable "state_bucket_region" {
  description = "AWS region for state bucket"
  type        = string
  default     = "us-east-1"
}

variable "state_version_retention_days" {
  description = "Days to retain non-current state versions"
  type        = number
  default     = 90
}

variable "state_log_retention_days" {
  description = "Days to retain state access logs"
  type        = number
  default     = 90
}

variable "prevent_state_bucket_destroy" {
  description = "Prevent destruction of state bucket"
  type        = bool
  default     = true
}

variable "prevent_state_lock_destroy" {
  description = "Prevent destruction of lock table"
  type        = bool
  default     = true
}

variable "state_lock_pitr_enabled" {
  description = "Enable point-in-time recovery for lock table"
  type        = bool
  default     = true
}

variable "state_lock_encryption_enabled" {
  description = "Enable encryption for lock table"
  type        = bool
  default     = true
}

variable "state_lock_kms_key_arn" {
  description = "KMS key ARN for lock table encryption"
  type        = string
  default     = null
}

variable "state_bucket_policy" {
  description = "Bucket policy document"
  type        = string
  default     = null
}

variable "enable_state_notifications" {
  description = "Enable S3 event notifications"
  type        = bool
  default     = false
}

variable "state_notification_lambda_arn" {
  description = "Lambda function ARN for notifications"
  type        = string
  default     = null
}

variable "state_notification_lambda_name" {
  description = "Lambda function name for notifications"
  type        = string
  default     = null
}

variable "kms_key_deletion_window" {
  description = "KMS key deletion window in days"
  type        = number
  default     = 30
}

variable "default_tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "terraform"
    Project   = "agl-hostman"
  }
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

# =============================================================================
# Multi-region replication variables
# =============================================================================
variable "enable_state_replication" {
  description = "Enable cross-region replication"
  type        = bool
  default     = false
}

variable "state_replication_region" {
  description = "Destination region for replication"
  type        = string
  default     = "us-west-2"
}

variable "state_replication_bucket" {
  description = "Destination bucket name for replication"
  type        = string
  default     = null
}
