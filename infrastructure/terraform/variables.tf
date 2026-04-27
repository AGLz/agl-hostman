# Global Variables for Proxmox Infrastructure
variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "agl-hostman"
}

variable "region" {
  description = "Region/Location identifier"
  type        = string
  default     = "agl-primary"
}

# Proxmox API Configuration
variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
  sensitive   = true
}

variable "proxmox_api_token_id" {
  description = "Proxmox API Token ID"
  type        = string
  sensitive   = true
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API Token Secret"
  type        = string
  sensitive   = true
}

variable "proxmox_tls_insecure" {
  description = "Skip TLS verification for Proxmox API"
  type        = bool
  default     = false
}

variable "proxmox_timeout" {
  description = "API request timeout in seconds"
  type        = number
  default     = 300
}

variable "proxmox_debug" {
  description = "Enable debug logging for Proxmox API"
  type        = bool
  default     = false
}

variable "proxmox_log_enable" {
  description = "Enable file logging for Proxmox API"
  type        = bool
  default     = false
}

variable "proxmox_log_file" {
  description = "Log file path for Proxmox API"
  type        = string
  default     = "/tmp/terraform-proxmox.log"
}

# Proxmox Cluster Configuration
variable "proxmox_nodes" {
  description = "Proxmox cluster nodes"
  type = map(object({
    host          = string
    node_name     = string
    wireguard_ip  = optional(string)
    tailscale_ip  = optional(string)
    tags          = optional(list(string), [])
  }))
  default = {
    aglsrv1 = {
      host         = "192.168.0.245"
      node_name    = "AGLSRV1"
      wireguard_ip = "10.6.0.11"
      tailscale_ip = "100.107.113.33"
      tags         = ["primary", "controller"]
    }
    aglsrv6 = {
      host         = "192.168.0.246"
      node_name    = "AGLSRV6"
      wireguard_ip = "10.6.0.12"
      tailscale_ip = "100.80.30.59"
      tags         = ["secondary", "worker"]
    }
  }
}

variable "default_node" {
  description = "Default Proxmox node for resource placement"
  type        = string
  default     = "AGLSRV1"
}

# Network Configuration
variable "network_config" {
  description = "Global network configuration"
  type = object({
    bridge      = string
    vlan        = optional(number)
    gateway     = string
    dns_servers = list(string)
    search_domains = list(string)
  })
  default = {
    bridge         = "vmbr0"
    gateway        = "192.168.0.1"
    dns_servers    = ["192.168.0.1", "8.8.8.8"]
    search_domains = ["agl.local", "aglz.io"]
  }
}

variable "wireguard_config" {
  description = "WireGuard mesh network configuration"
  type = object({
    enabled    = bool
    network    = string
    port       = number
    peers      = map(object({
      public_key = string
      endpoint   = string
      allowed_ip = string
    }))
  })
  default = {
    enabled = false
    network = "10.6.0.0/24"
    port    = 51820
    peers   = {}
  }
}

# Storage Configuration
variable "storage_config" {
  description = "Storage pool configuration"
  type = map(object({
    type        = string
    storage     = string
    content     = list(string)
    shared      = optional(bool, false)
    backup_pool = optional(bool, false)
  }))
  default = {
    local-lvm = {
      type        = "lvm"
      storage     = "local-lvm"
      content     = ["images", "rootdir"]
      shared      = false
      backup_pool = false
    }
    local-btrfs = {
      type        = "btrfs"
      storage     = "local-btrfs"
      content     = ["images", "rootdir", "vztmpl", "backup", "iso"]
      shared      = false
      backup_pool = false
    }
    nfs-storage = {
      type        = "nfs"
      storage     = "nfs-storage"
      content     = ["images", "backup", "iso"]
      shared      = true
      backup_pool = true
    }
  }
}

variable "default_storage" {
  description = "Default storage pool for VMs and containers"
  type        = string
  default     = "local-lvm"
}

variable "backup_storage" {
  description = "Storage pool for backups"
  type        = string
  default     = "nfs-storage"
}

# Tags and Labels
variable "default_tags" {
  description = "Default tags applied to all resources"
  type        = list(string)
  default     = ["terraform-managed", "agl-hostman"]
}

variable "default_labels" {
  description = "Default labels for Kubernetes-style organization"
  type = map(string)
  default = {
    "managed-by" = "terraform"
    "project"    = "agl-hostman"
  }
}

# Ansible Configuration
variable "ansible_playbook_path" {
  description = "Path to Ansible playbooks directory"
  type        = string
  default     = "../ansible"
}

variable "ansible_inventory_path" {
  description = "Path to Ansible inventory file"
  type        = string
  default     = "../ansible/inventory/hosts.ini"
}
