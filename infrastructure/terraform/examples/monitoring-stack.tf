# Example: Deploy complete monitoring stack
# This example creates monitoring infrastructure

module "monitoring_vm" {
  source = "../modules/proxmox_vm"

  vm_name   = "monitoring-server"
  vm_id     = 202
  node_name = "AGLSRV1"

  cpu_cores = 4
  memory_gb = 16

  disks = [
    {
      type         = "scsi0"
      storage      = "local-lvm"
      size_gb      = 128
      interface    = "scsi"
      ssd          = true
      cache        = "writeback"
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
  }

  tags = ["monitoring", "production"]

  # Deploy monitoring stack via Ansible
  ansible_playbook = "../../ansible/playbooks/monitoring-setup.yml"
  ansible_extra_vars = {
    grafana_admin_password = "GrafanaAdmin123!"
    prometheus_retention   = "30d"
  }
}

output "monitoring_urls" {
  value = {
    prometheus  = "http://${module.monitoring_vm.vm_ip}:9090"
    grafana     = "http://${module.monitoring_vm.vm_ip}:3000"
    alertmanager = "http://${module.monitoring_vm.vm_ip}:9093"
  }
}
