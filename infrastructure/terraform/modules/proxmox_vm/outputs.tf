# Proxmox VM Module Outputs

output "vm_id" {
  description = "VM ID"
  value       = proxmox_vm_qemu.this.vmid
}

output "vm_name" {
  description = "VM full name"
  value       = proxmox_vm_qemu.this.name
}

output "vm_ip" {
  description = "VM IP address (from cloud-init or QEMU agent)"
  value       = try(data.external.vm_ip[0].result.ip, null)
}

output "vnc_address" {
  description = "VNC console address"
  value       = "https://${var.proxmox_api_host}:8006/?console=kvm&vmid=${proxmox_vm_qemu.this.vmid}&node=${var.node_name}"
}

output "ssh_command" {
  description = "SSH command to connect to the VM"
  value       = try(external.vm_ip[0].result.ip != "unknown" ? "ssh ${coalesce(var.cloud_init.user, "root")}@${data.external.vm_ip[0].result.ip}" : null, null)
}

output "provisioning_complete" {
  description = "Whether Ansible provisioning completed"
  value       = var.ansible_playbook != null ? true : null
}
