# =============================================================================
# Complete Stack Example
# AGL Hostman - Production Infrastructure
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = ">= 3.0.1-rc4"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 3.0.0"
    }
  }
}

# =============================================================================
# Provider Configuration
# =============================================================================
provider "proxmox" {
  pm_api_url          = var.proxmox_api_url
  pm_api_token_id     = var.proxmox_api_token_id
  pm_api_token_secret = var.proxmox_api_token_secret
  pm_tls_insecure     = var.proxmox_tls_insecure
}

# =============================================================================
# Network Configuration
# =============================================================================
module "network_bridge" {
  source = "../modules/proxmox_network"

  bridge_name = "vmbr1"
  node_name   = var.default_node
  bridge_type = "linux"

  bridge_address = "10.10.0.1"
  bridge_netmask = "24"
  bridge_gateway = "10.10.0.254"

  vlan_aware = true
}

# =============================================================================
# Storage Configuration
# =============================================================================
module "storage_nfs" {
  source = "../modules/proxmox_storage"

  storage_name   = "shared-storage"
  node_name      = var.default_node
  storage_type   = "nfs"

  nfs_server    = "192.168.0.250"
  nfs_export    = "/mnt/agl-storage"
  content_types = ["images", "backup", "iso"]
}

# =============================================================================
# Virtual Machines
# =============================================================================
module "vm_load_balancer" {
  source = "../modules/proxmox_vm"

  vm_name    = "haproxy-lb"
  vm_id      = 183
  node_name  = var.default_node

  cpu_cores = 2
  memory_gb = 2

  disks = [
    {
      type         = "scsi0"
      storage      = "local-lvm"
      size_gb      = 32
      ssd          = true
    }
  ]

  network_interfaces = [
    {
      model  = "virtio"
      bridge = "vmbr0"
      ip     = "192.168.0.183"
    }
  ]

  tags = ["load-balancer", "production"]
}

module "vm_app_server" {
  source = "../modules/proxmox_vm"

  vm_name    = "app-server"
  vm_id      = 179
  node_name  = var.default_node

  cpu_cores = 4
  memory_gb = 8

  disks = [
    {
      type         = "scsi0"
      storage      = "local-lvm"
      size_gb      = 64
      ssd          = true
    }
  ]

  network_interfaces = [
    {
      model  = "virtio"
      bridge = "vmbr0"
    }
  ]

  cloud_init = {
    enabled = true
    user    = "ubuntu"
  }

  tags = ["application", "production"]
}

module "vm_monitoring" {
  source = "../modules/proxmox_vm"

  vm_name    = "monitoring"
  vm_id      = 184
  node_name  = var.default_node

  cpu_cores = 2
  memory_gb = 4

  disks = [
    {
      type         = "scsi0"
      storage      = "local-lvm"
      size_gb      = 128
      ssd          = true
    }
  ]

  network_interfaces = [
    {
      model  = "virtio"
      bridge = "vmbr0"
    }
  ]

  tags = ["monitoring", "production"]
}

# =============================================================================
# LXC Containers
# =============================================================================
module "lxc_redis" {
  source = "../modules/proxmox_lxc"

  container_name = "redis"
  container_id   = 160
  node_name      = var.default_node

  cpu_cores = 2
  memory_mb = 4096

  storage = {
    storage  = "local-lvm"
    size_gb  = 32
  }

  features = {
    nesting = true
  }

  tags = ["database", "redis", "production"]
}

# =============================================================================
# Docker Services (on app_server VM)
# =============================================================================
module "docker_nginx" {
  source = "../modules/docker_service"

  service_name = "nginx"
  image        = "nginx"
  image_tag    = "alpine"

  ports = [
    {
      internal = 80
      external = 80
      protocol = "tcp"
    },
    {
      internal = 443
      external = 443
      protocol = "tcp"
    }
  ]

  volumes = [
    {
      host_path      = "/data/nginx/conf"
      container_path = "/etc/nginx"
      mode          = "ro"
    },
    {
      host_path      = "/data/nginx/html"
      container_path = "/usr/share/nginx/html"
      mode          = "ro"
    }
  ]

  labels = {
    "com.aglhostman.tier" = "frontend"
  }
}

module "docker_app" {
  source = "../modules/docker_service"

  service_name = "agl-app"
  image        = "aglhostman/app"
  image_tag    = "latest"

  ports = [
    {
      internal = 9000
      external = 9000
      protocol = "tcp"
    }
  ]

  environment = {
    APP_ENV = "production"
    DB_HOST  = "mysql.internal"
    REDIS_HOST = "redis.internal"
  }

  deploy_resources = {
    limits = {
      cpus   = "2.0"
      memory = "4g"
    }
    reservations = {
      cpus   = "0.5"
      memory = "512m"
    }
  }

  healthcheck = {
    command     = ["CMD", "curl", "-f", "http://localhost:9000/health"]
    interval    = "30s"
    timeout     = "5s"
    retries     = 3
    start_period = "10s"
  }
}

module "docker_registry" {
  source = "../modules/docker_registry"

  registry_name        = "agl-registry"
  registry_port        = 5000
  registry_ui_port     = 8080
  registry_ui_enabled  = true
  registry_auth_enabled = true
  registry_tls_enabled  = true

  registry_data_dir = "/data/registry"
}

# =============================================================================
# Docker Compose Stack
# =============================================================================
module "stack_monitoring" {
  source = "../modules/docker_compose"

  project_name = "monitoring"
  compose_file = "${path.module}/docker-compose.monitoring.yml"

  environment_files = [
    "${path.module}/.env.monitoring"
  ]
}

# =============================================================================
# Variables
# =============================================================================
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
  description = "Skip TLS verification"
  type        = bool
  default     = false
}

variable "default_node" {
  description = "Default Proxmox node"
  type        = string
  default     = "AGLSRV1"
}

# =============================================================================
# Outputs
# =============================================================================
output "load_balancer_ip" {
  description = "Load balancer IP"
  value       = module.vm_load_balancer.ip_address
}

output "app_server_ip" {
  description = "App server IP"
  value       = module.vm_app_server.ip_address
}

output "service_urls" {
  description = "Service URLs"
  value = {
    registry    = "http://192.168.0.179:8080"
    monitoring  = "http://192.168.0.184:3000"
  }
}
