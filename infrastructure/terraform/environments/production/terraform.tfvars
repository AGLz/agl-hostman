# Production Environment Variables

environment = "production"
project_name = "agl-hostman"

# Proxmox Configuration
proxmox_api_url        = "https://192.168.0.245:8006/api2/json"
proxmox_api_token_id    = "root@pam!terraform"
proxmox_api_token_secret = "" # Set via TF_VAR or secret management
proxmox_tls_insecure    = false
proxmox_timeout         = 300

# Cluster Nodes
proxmox_nodes = {
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

default_node = "AGLSRV1"

# Network
network_config = {
  bridge         = "vmbr0"
  gateway        = "192.168.0.1"
  dns_servers    = ["192.168.0.1", "8.8.8.8"]
  search_domains = ["agl.local", "aglz.io"]
}

# WireGuard Mesh
wireguard_config = {
  enabled = true
  network = "10.6.0.0/24"
  port    = 51820
  peers = {
    aglsrv1 = {
      public_key = "<public-key-1>"
      endpoint   = "192.168.0.245:51820"
      allowed_ip = "10.6.0.11/32"
    }
    aglsrv6 = {
      public_key = "<public-key-2>"
      endpoint   = "192.168.0.246:51820"
      allowed_ip = "10.6.0.12/32"
    }
  }
}

# Storage
storage_config = {
  local-lvm = {
    type        = "lvm"
    storage     = "local-lvm"
    content     = ["images", "rootdir"]
    shared      = false
    backup_pool = false
  }
  nfs-storage = {
    type        = "nfs"
    storage     = "nfs-storage"
    content     = ["images", "backup", "iso", "vztmpl"]
    shared      = true
    backup_pool = true
  }
}

default_storage = "local-lvm"
backup_storage  = "nfs-storage"

# Tags
default_tags = [
  "terraform-managed",
  "agl-hostman",
  "production",
  "backups-enabled"
]

default_labels = {
  "managed-by"    = "terraform"
  "project"       = "agl-hostman"
  "environment"   = "production"
  "backup-schedule" = "daily-2am"
}

# Ansible
ansible_playbook_path    = "../../../ansible"
ansible_inventory_path   = "../../../ansible/inventory/hosts.ini"
