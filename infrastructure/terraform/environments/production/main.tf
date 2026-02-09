# Production Environment Configuration
# This file defines the production infrastructure

terraform {
  source = "../../../"
}

# Include all modules
# Proxmox VMs
module "production_vm_harbor" {
  source = "../../modules/proxmox_vm"

  vm_name    = "harbor-registry"
  vm_id      = 182
  node_name  = var.proxmox_nodes.aglsrv1.node_name

  cpu_cores = 4
  cpu_sockets = 1
  memory_gb = 8

  disks = [
    {
      type         = "scsi0"
      storage      = "local-lvm"
      storage_type = "lvm"
      size_gb      = 128
      interface    = "scsi"
      ssd          = true
      discard      = true
      cache        = "writeback"
      backup       = true
    }
  ]

  network_interfaces = [
    {
      model    = "virtio"
      bridge   = "vmbr0"
      firewall = false
    }
  ]

  tags = ["registry", "harbor", "production"]
  labels = {
    service = "harbor"
  }

  ansible_playbook = "../../ansible/playbooks/harbor-setup.yml"
}

module "production_vm_dokploy" {
  source = "../../modules/proxmox_vm"

  vm_name   = "dokploy-platform"
  vm_id     = 180
  node_name = var.proxmox_nodes.aglsrv1.node_name

  cpu_cores = 4
  memory_gb = 8

  disks = [
    {
      type         = "scsi0"
      storage      = "local-lvm"
      storage_type = "lvm"
      size_gb      = 64
      interface    = "scsi"
      ssd          = true
      discard      = true
      cache        = "writeback"
      backup       = true
    }
  ]

  network_interfaces = [
    {
      model    = "virtio"
      bridge   = "vmbr0"
      firewall = false
    }
  ]

  tags = ["deployment", "dokploy", "production"]
  labels = {
    service = "dokploy"
  }

  ansible_playbook = "../../ansible/playbooks/dokploy-setup.yml"
}

# LXC Containers
module "production_lxc_app" {
  source = "../../modules/proxmox_lxc"

  container_name = "app-server"
  container_id   = 179
  node_name      = var.proxmox_nodes.aglsrv1.node_name

  cpu_cores = 4
  memory_mb = 8192

  template = {
    storage        = "local-lvm"
    template_file = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
  }

  storage = {
    storage = "local-lvm"
    size_gb = 64
  }

  features = {
    nesting = true # Enable Docker-in-LXC
    keyctl  = true
  }

  unprivileged = true

  network_interfaces = [
    {
      name   = "eth0"
      bridge = "vmbr0"
      ip     = "dhcp"
    }
  ]

  tags = ["application", "production"]
  labels = {
    service = "app"
  }

  ansible_playbook = "../../ansible/playbooks/app-server-setup.yml"
}

module "production_lxc_monitoring" {
  source = "../../modules/proxmox_lxc"

  container_name = "monitoring-stack"
  container_id   = 108
  node_name      = var.proxmox_nodes.aglsrv1.node_name

  cpu_cores = 2
  memory_mb = 4096

  template = {
    storage        = "local-lvm"
    template_file = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
  }

  storage = {
    storage = "local-lvm"
    size_gb = 32
  }

  features = {
    nesting = true
  }

  unprivileged = true

  network_interfaces = [
    {
      name   = "eth0"
      bridge = "vmbr0"
      ip     = "dhcp"
    }
  ]

  tags = ["monitoring", "prometheus", "grafana"]
  labels = {
    service = "monitoring"
  }

  ansible_playbook = "../../ansible/playbooks/monitoring-setup.yml"
}

# Storage
module "production_storage_nfs" {
  source = "../../modules/proxmox_storage"

  storage_name   = "nfs-storage"
  node_name      = var.proxmox_nodes.aglsrv1.node_name
  storage_type   = "nfs"

  nfs_server    = "192.168.0.250"
  nfs_export    = "/mnt/agl-storage"
  nfs_options   = "vers=4.2,soft,timeo=600,retrans=5"
  content_types = ["images", "backup", "iso", "vztmpl"]

  storage_shared     = true
  storage_backup_pool = true

  max_files = 14

  storage_prune = {
    keep_daily   = 7
    keep_weekly  = 4
    keep_monthly = 3
  }
}
