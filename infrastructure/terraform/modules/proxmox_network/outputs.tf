# Proxmox Network Module Outputs

output "bridge_name" {
  description = "Bridge device name"
  value       = var.bridge_name
}

output "bridge_address" {
  description = "Bridge IP address"
  value       = var.bridge_address
}

output "bridge_cidr" {
  description = "Bridge CIDR notation"
  value       = local.bridge_cidr
}

output "bridge_gateway" {
  description = "Bridge gateway"
  value       = var.bridge_gateway
}

output "vlan_aware" {
  description = "Whether bridge is VLAN-aware"
  value       = var.vlan_aware
}

output "bond_mode" {
  description = "Bonding mode (if configured)"
  value       = var.bond_mode
}

output "configuration_file" {
  description = "Path to network configuration file"
  value       = try(local_file.network_config[0].filename, null)
}
