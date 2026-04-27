# =============================================================================
# Terraform S3 Backend Configuration
# AGL Hostman - Infrastructure as Code
# =============================================================================

terraform {
  # S3 Backend for Terraform State
  backend "s3" {
    # These values should be configured via backend config or environment variables
    # Required:
    # bucket         = "agl-terraform-state"
    # key            = "proxmox-infrastructure/terraform.tfstate"
    # region         = "us-east-1"

    # Optional (with defaults):
    # encrypt        = true
    # dynamodb_table = "terraform-state-lock"
    # acl            = "private"

    # Versioning and locking:
    # kms_key_id    = "alias/terraform-state"
    # profile       = "default"

    # Performance:
    # max_retries   = 3
  }
}

# =============================================================================
# AWS S3 Bucket for Terraform State
# =============================================================================
resource "aws_s3_bucket" "terraform_state" {
  count = var.create_state_bucket ? 1 : 0

  bucket_prefix = var.state_bucket_name
  bucket        = var.state_bucket_name

  # Enable versioning
  versioning {
    enabled = true
  }

  # Enable server-side encryption
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  # Enable logging
  logging {
    target_bucket = aws_s3_bucket.state_logs[0].id
    target_prefix = "log/"
  }

  # Lifecycle rules
  lifecycle_rule {
    id      = "tfstate-version-expiry"
    enabled = true

    noncurrent_version_expiration {
      noncurrent_days = var.state_version_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  # Lock the bucket from accidental deletion
  lifecycle {
    prevent_destroy = var.prevent_state_bucket_destroy
  }

  tags = merge(
    var.default_tags,
    {
      Name        = var.state_bucket_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Purpose     = "terraform-state"
    }
  )
}

# =============================================================================
# S3 Bucket for State Logs
# =============================================================================
resource "aws_s3_bucket" "state_logs" {
  count = var.create_state_bucket ? 1 : 0

  bucket_prefix = "${var.state_bucket_name}-logs"
  bucket        = "${var.state_bucket_name}-logs"

  # Enable versioning
  versioning {
    enabled = true
  }

  # Lifecycle rules
  lifecycle_rule {
    id      = "log-expiry"
    enabled = true

    expiration {
      days = var.state_log_retention_days
    }
  }

  tags = merge(
    var.default_tags,
    {
      Name        = "${var.state_bucket_name}-logs"
      Environment = var.environment
      ManagedBy   = "terraform"
      Purpose     = "terraform-state-logs"
    }
  )
}

# =============================================================================
# DynamoDB Table for State Locking
# =============================================================================
resource "aws_dynamodb_table" "terraform_state_lock" {
  count = var.create_state_resources ? 1 : 0

  name           = var.state_lock_table_name
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  # Point-in-time recovery
  point_in_time_recovery {
    enabled = var.state_lock_pitr_enabled
  }

  # Server-side encryption
  server_side_encryption {
    enabled     = var.state_lock_encryption_enabled
    kms_key_arn = var.state_lock_kms_key_arn
  }

  # Tags
  tags = merge(
    var.default_tags,
    {
      Name        = var.state_lock_table_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Purpose     = "terraform-state-lock"
    }
  )

  lifecycle {
    prevent_destroy = var.prevent_state_lock_destroy
  }
}

# =============================================================================
# S3 Bucket Policy (restrict to specific accounts/IPs)
# =============================================================================
resource "aws_s3_bucket_policy" "state_bucket_policy" {
  count = var.create_state_bucket && var.state_bucket_policy != null ? 1 : 0

  bucket = aws_s3_bucket.terraform_state[0].id

  policy = var.state_bucket_policy
}

# =============================================================================
# S3 Bucket Public Access Block
# =============================================================================
resource "aws_s3_bucket_public_access_block" "state_public_access" {
  count = var.create_state_bucket ? 1 : 0

  bucket = aws_s3_bucket.terraform_state[0].id

  # Block all public access
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# =============================================================================
# KMS Key for State Encryption
# =============================================================================
resource "aws_kms_key" "terraform_state" {
  count = var.create_state_resources && var.create_kms_key ? 1 : 0

  description             = "KMS key for Terraform state encryption"
  deletion_window_in_days = var.kms_key_deletion_window
  enable_key_rotation     = true

  tags = merge(
    var.default_tags,
    {
      Name        = "${var.state_bucket_name}-kms"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )
}

resource "aws_kms_alias" "terraform_state" {
  count = var.create_state_resources && var.create_kms_key ? 1 : 0

  name          = "alias/${var.state_bucket_name}-kms"
  target_key_id = aws_kms_key.terraform_state[0].id
}

# =============================================================================
# S3 Bucket Notifications (for state change events)
# =============================================================================
resource "aws_s3_bucket_notification" "state_notification" {
  count = var.create_state_bucket && var.enable_state_notifications ? 1 : 0

  bucket = aws_s3_bucket.terraform_state[0].id

  lambda_function {
    lambda_function_arn = var.state_notification_lambda_arn
    events              = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
    filter_prefix       = "terraform.tfstate"
    filter_suffix       = ".tfstate"
  }

  depends_on = [aws_lambda_permission.state_bucket_notification]
}

resource "aws_lambda_permission" "state_bucket_notification" {
  count = var.create_state_bucket && var.enable_state_notifications ? 1 : 0

  statement_id  = "AllowS3Invocation"
  action        = "lambda:InvokeFunction"
  function_name = var.state_notification_lambda_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.terraform_state[0].arn
}
