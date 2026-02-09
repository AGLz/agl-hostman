# Global Outputs for Proxmox Infrastructure

output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "proxmox_cluster_info" {
  description = "Proxmox cluster information"
  value = {
    api_url  = var.proxmox_api_url
    nodes    = var.proxmox_nodes
    defaults = {
      node    = var.default_node
      storage = var.default_storage
      bridge  = var.network_config.bridge
    }
  }
  sensitive = true
}

output "network_info" {
  description = "Network configuration"
  value = {
    bridge         = var.network_config.bridge
    gateway        = var.network_config.gateway
    dns_servers    = var.network_config.dns_servers
    wireguard      = var.wireguard_config
  }
}

output "storage_info" {
  description = "Storage configuration"
  value = {
    default_storage = var.default_storage
    backup_storage  = var.backup_storage
    pools           = var.storage_config
  }
}

output "ansible_config" {
  description = "Ansible configuration paths"
  value = {
    playbook_path = ansible_playbook_path
    inventory_path = var.ansible_inventory_path
  }
}
