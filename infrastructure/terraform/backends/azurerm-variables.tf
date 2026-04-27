# =============================================================================
# AzureRM Backend Variables
# AGL Hostman - Infrastructure as Code
# =============================================================================

variable "create_state_resources" {
  description = "Create Azure storage resources"
  type        = bool
  default     = true
}

variable "create_key_vault" {
  description = "Create Key Vault for state encryption"
  type        = bool
  default     = false
}

variable "resource_group_name" {
  description = "Azure resource group name"
  type        = string
  default     = "agl-infrastructure"
}

variable "storage_account_name" {
  description = "Azure storage account name"
  type        = string
  default     = "aglterraformstate"
}

variable "container_name" {
  description = "Storage container name"
  type        = string
  default     = "terraform-state"
}

variable "azure_location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "account_replication_type" {
  description = "Storage account replication type"
  type        = string
  default     = "GRS"

  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], var.account_replication_type)
    error_message = "Replication type must be LRS, GRS, RAGRS, ZRS, GZRS, or RAGZRS."
  }
}

variable "state_retention_days" {
  description = "Days to retain state file versions"
  type        = number
  default     = 90
}

variable "use_customer_managed_key" {
  description = "Use customer-managed encryption key"
  type        = bool
  default     = false
}

variable "key_vault_name" {
  description = "Key Vault name for state encryption"
  type        = string
  default     = "agl-terraform-kv"
}

variable "key_vault_key_uri" {
  description = "URI of Key Vault key for encryption"
  type        = string
  default     = null
}

variable "user_assigned_identity_id" {
  description = "User-assigned identity ID for Key Vault access"
  type        = string
  default     = null
}

variable "storage_account_identity_type" {
  description = "Identity type for storage account"
  type        = string
  default     = "SystemAssigned"
}

variable "soft_delete_retention_days" {
  description = "Soft delete retention days for Key Vault"
  type        = number
  default     = 90
}

variable "purge_protection_enabled" {
  description = "Enable purge protection for Key Vault"
  type        = bool
  default     = true
}

variable "access_policies" {
  description = "Key Vault access policies"
  type = list(object({
    tenant_id         = string
    object_id        = string
    key_permissions  = list(string)
    secret_permissions = list(string)
  }))
  default = []
}

variable "use_rbac_authorization" {
  description = "Use RBAC for Key Vault authorization"
  type        = bool
  default     = false
}

variable "enable_network_rules" {
  description = "Enable network rules for storage account"
  type        = bool
  default     = true
}

variable "default_network_action" {
  description = "Default network action"
  type        = string
  default     = "Deny"
}

variable "network_bypass" {
  description = "Network bypass settings"
  type        = list(string)
  default     = ["AzureServices"]
}

variable "allowed_ip_ranges" {
  description = "Allowed IP ranges for storage access"
  type        = list(string)
  default     = []
}

variable "allowed_subnet_ids" {
  description = "Allowed subnet IDs for storage access"
  type        = list(string)
  default     = []
}

variable "enable_private_link" {
  description = "Enable private link for storage"
  type        = bool
  default     = false
}

variable "private_subnet_id" {
  description = "Subnet ID for private endpoint"
  type        = string
  default     = null
}

variable "create_private_endpoint" {
  description = "Create private endpoint for storage"
  type        = bool
  default     = false
}

variable "enable_storage_cors" {
  description = "Enable CORS for storage account"
  type        = bool
  default     = false
}

variable "cors_allowed_headers" {
  description = "CORS allowed headers"
  type        = list(string)
  default     = ["*"]
}

variable "cors_allowed_methods" {
  description = "CORS allowed methods"
  type        = list(string)
  default     = ["GET", "PUT", "DELETE", "HEAD"]
}

variable "cors_allowed_origins" {
  description = "CORS allowed origins"
  type        = list(string)
  default     = []
}

variable "cors_exposed_headers" {
  description = "CORS exposed headers"
  type        = list(string)
  default     = ["*"]
}

variable "cors_max_age" {
  description = "CORS max age in seconds"
  type        = number
  default     = 3600
}

variable "enable_lifecycle_rules" {
  description = "Enable lifecycle rules for storage"
  type        = bool
  default     = true
}

variable "tenant_id" {
  description = "Azure AD tenant ID"
  type        = string
  default     = null
}

variable "default_tags" {
  description = "Default tags for resources"
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
