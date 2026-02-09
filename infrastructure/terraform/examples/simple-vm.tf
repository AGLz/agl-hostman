# Example: Create a simple web server VM
# This example demonstrates basic VM provisioning

module "web_server" {
  source = "../modules/proxmox_vm"

  vm_name   = "web-server"
  vm_id     = 200
  node_name = "AGLSRV1"

  cpu_cores = 2
  memory_gb = 4

  disks = [
    {
      type         = "scsi0"
      storage      = "local-lvm"
      size_gb      = 32
      interface    = "scsi"
      ssd          = true
    }
  ]

  network_interfaces = [
    {
      model    = "virtio"
      bridge   = "vmbr0"
      ip       = "dhcp"
    }
  ]

  cloud_init = {
    enabled   = true
    user      = "ubuntu"
    password  = "SecurePassword123!"
    ssh_keys  = ["ssh-rsa AAAAB3..."]
    ipconfig0 = "ip=dhcp"
  }

  onboot = true
  tags    = ["web", "production"]
}

output "web_server_ip" {
  value = module.web_server.vm_ip
}
