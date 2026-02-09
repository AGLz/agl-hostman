# Proxmox LXC Container Module Outputs

output "container_id" {
  description = "Container ID"
  value       = proxmox_lxc.this.vmid
}

output "container_name" {
  description = "Container full name"
  value       = proxmox_lxc.this.name
}

output "container_hostname" {
  description = "Container hostname"
  value       = proxmox_lxc.this.hostname
}

output "container_ip" {
  description = "Primary IP address"
  value       = try(var.network_interfaces[0].ip, null)
}

output "ssh_command" {
  description = "SSH command to connect to the container"
  value       = "pct enter ${proxmox_lxc.this.vmid}"
}

output "provisioning_complete" {
  description = "Whether Ansible provisioning completed"
  value       = var.ansible_playbook != null ? true : null
}

output "network_info" {
  description = "Network configuration"
  value = {
    interfaces = var.network_interfaces
    hostname   = proxmox_lxc.this.hostname
    nameserver = proxmox_lxc.this.nameserver
  }
}
