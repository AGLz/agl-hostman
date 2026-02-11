# =============================================================================
# Terraform AzureRM Backend Configuration
# AGL Hostman - Infrastructure as Code
# =============================================================================

terraform {
  backend "azurerm" {
    # These values should be configured via backend config or environment variables
    # Required:
    # resource_group_name  = "agl-infrastructure"
    # storage_account_name = "aglterraformstate"
    # container_name       = "terraform-state"
    # key                  = "proxmox-infrastructure/terraform.tfstate"

    # Optional (with defaults):
    # use_azuread_auth     = true
    # use_msi              = false
    # subscription_id       = null
    # tenant_id            = null
    # environment          = "public"
  }
}

# =============================================================================
# Azure Resource Group
# =============================================================================
resource "azurerm_resource_group" "terraform_state" {
  count = var.create_state_resources ? 1 : 0

  name     = var.resource_group_name
  location = var.azure_location

  tags = merge(
    var.default_tags,
    {
      Environment = var.environment
      ManagedBy   = "terraform"
      Purpose     = "terraform-state"
    }
  )
}

# =============================================================================
# Azure Storage Account
# =============================================================================
resource "azurerm_storage_account" "terraform_state" {
  count = var.create_state_resources ? 1 : 0

  name                      = var.storage_account_name
  resource_group_name       = var.resource_group_name
  location                 = azurerm_resource_group.terraform_state[0].location
  account_tier             = "Standard"
  account_replication_type  = var.account_replication_type
  account_kind             = "StorageV2"
  enable_https_traffic_only = true

  # Blob properties
  blob_properties {
    versioning_enabled       = true
    change_feed_enabled      = true
    default_action          = "Deny"

    dynamic "cors_rule" {
      for_each = var.enable_storage_cors ? [1] : []
      content {
        allowed_headers    = var.cors_allowed_headers
        allowed_methods   = var.cors_allowed_methods
        allowed_origins   = var.cors_allowed_origins
        exposed_headers   = var.cors_exposed_headers
        max_age_in_seconds = var.cors_max_age
      }
    }
  }

  # Customer-managed encryption key
  dynamic "customer_managed_key" {
    for_each = var.use_customer_managed_key ? [1] : []
    content {
      key_vault_key_id          = var.key_vault_key_uri
      user_assigned_identity_id = var.user_assigned_identity_id
    }
  }

  # Identity for accessing Key Vault
  identity {
    type = var.storage_account_identity_type
  }

  tags = merge(
    var.default_tags,
    {
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )
}

# =============================================================================
# Azure Storage Container
# =============================================================================
resource "azurerm_storage_container" "terraform_state" {
  count = var.create_state_resources ? 1 : 0

  name                  = var.container_name
  storage_account_name   = azurerm_storage_account.terraform_state[0].name
  container_access_type  = "private"

  # Lifecycle management
  dynamic "lifecycle_rule" {
    for_each = var.enable_lifecycle_rules ? [1] : []
    content {
      name    = "tfstate-version-expiry"

      enabled = true

      dynamic "rule" {
        content {
          action {
            delete_after_days_since_modification = var.state_retention_days
          }

          condition {
            match_blob_storage_class = ["HOT", "COOL"]
          }
        }
      }
    }
  }
}

# =============================================================================
# Azure Storage Account Network Rules
# =============================================================================
resource "azurerm_storage_account_network_rules" "state_network" {
  count = var.create_state_resources && var.enable_network_rules ? 1 : 0

  storage_account_id = azurerm_storage_account.terraform_state[0].id

  default_action             = var.default_network_action
  bypass                   = var.network_bypass
  ip_rules                 = var.allowed_ip_ranges
  virtual_network_subnet_ids = var.allowed_subnet_ids

  dynamic "private_link_access" {
    for_each = var.enable_private_link ? [1] : []
    content {
      endpoint_resource_id = azurerm_storage_account.terraform_state[0].id
      endpoint_device_id  = null
    }
  }
}

# =============================================================================
# Azure Key Vault for State Encryption
# =============================================================================
resource "azurerm_key_vault" "terraform_state" {
  count = var.create_key_vault ? 1 : 0

  name                = var.key_vault_name
  location            = azurerm_resource_group.terraform_state[0].location
  resource_group_name = var.resource_group_name
  tenant_id          = var.tenant_id
  sku_name           = "standard"

  # Soft delete
  soft_delete_retention_days = var.soft_delete_retention_days
  enable_soft_delete       = true
  purge_protection_enabled = var.purge_protection_enabled

  # Access policies
  dynamic "access_policy" {
    for_each = var.access_policies
    content {
      tenant_id           = access_policy.value.tenant_id
      object_id          = access_policy.value.object_id

      key_permissions    = access_policy.value.key_permissions
      secret_permissions = access_policy.value.secret_permissions
    }
  }

  # RBAC
  enable_rbac_authorization = var.use_rbac_authorization

  tags = var.default_tags
}

# =============================================================================
# Key Vault Key for State Encryption
# =============================================================================
resource "azurerm_key_vault_key" "terraform_state" {
  count = var.create_key_vault ? 1 : 0

  name         = "terraform-state-key"
  key_vault_id = azurerm_key_vault.terraform_state[0].id
  key_type     = "RSA"
  key_size     = 2048
  key_opts     = ["decrypt", "encrypt", "sign", "unwrapKey", "verify", "wrapKey"]

  rotation_policy {
    automatic {
      time_before_expiry = "P30D"
    }

    expire_after         = "P90D"
    notify_before_expiry = "P29D"
  }
}

# =============================================================================
# Private Endpoint for Secure Access
# =============================================================================
resource "azurerm_private_endpoint" "state_storage" {
  count = var.create_state_resources && var.create_private_endpoint ? 1 : 0

  name                = "${var.storage_account_name}-pe"
  location            = azurerm_resource_group.terraform_state[0].location
  resource_group_name = var.resource_group_name
  subnet_id          = var.private_subnet_id

  private_service_connection {
    name                              = "terraform-state-psc"
    is_manual_connection               = false
    private_connection_resource_id      = azurerm_storage_account.terraform_state[0].id
    subresource_names                 = ["blob"]
  }

  tags = var.default_tags
}

resource "azurerm_private_dns_zone" "state_storage" {
  count = var.create_state_resources && var.create_private_endpoint ? 1 : 0

  name                = "privatelink.blob.core.windows.net"
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_group" "state_storage" {
  count = var.create_state_resources && var.create_private_endpoint ? 1 : 0

  name                 = "terraform-state-dns"
  private_dns_zone_ids = [azurerm_private_dns_zone.state_storage[0].id]
  private_endpoint_id  = azurerm_private_endpoint.state_storage[0].id
}
