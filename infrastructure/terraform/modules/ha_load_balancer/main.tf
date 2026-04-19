# =============================================================================
# Terraform Module: HA Load Balancer (HAProxy)
# AGL Hostman - High Availability Infrastructure
# =============================================================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = ">= 3.0"
    }
  }
}

# =============================================================================
# Variables
# =============================================================================
variable "lb_name" {
  description = "Name of the load balancer"
  type        = string
  default     = "haproxy-lb"
}

variable "node_name" {
  description = "Proxmox node name"
  type        = string
}

variable "vm_id" {
  description = "VM ID for the load balancer"
  type        = number
}

variable "lb_ip" {
  description = "Static IP address for the load balancer"
  type        = string
}

variable "lb_gateway" {
  description = "Gateway address"
  type        = string
}

variable "backend_servers" {
  description = "List of backend application servers"
  type = list(object({
    name   = string
    ip     = string
    port   = number
    backup = bool
  }))
  default = []
}

variable "mysql_servers" {
  description = "List of MySQL servers"
  type = list(object({
    name   = string
    ip     = string
    port   = number
    role   = string
  }))
  default = []
}

variable "redis_servers" {
  description = "List of Redis servers"
  type = list(object({
    name   = string
    ip     = string
    port   = number
  }))
  default = []
}

variable "ha_password" {
  description = "HAProxy stats password"
  type        = string
  sensitive   = true
}

variable "ssl_cert_path" {
  description = "Path to SSL certificate"
  type        = string
  default     = "/etc/haproxy/ssl"
}

# =============================================================================
# Local Variables
# =============================================================================
locals {
  backend_configs = flatten([
    for server in var.backend_servers : [
      {
        name   = server.name
        ip     = server.ip
        port   = server.port
        backup = server.backup ? "backup" : ""
      }
    ]
  ])

  mysql_configs = flatten([
    for server in var.mysql_servers : [
      {
        name = server.name
        ip   = server.ip
        port = server.port
        role = server.role
      }
    ]
  ])

  redis_configs = flatten([
    for server in var.redis_servers : [
      {
        name = server.name
        ip   = server.ip
        port = server.port
      }
    ]
  ])
}

# =============================================================================
# HAProxy VM
# =============================================================================
resource "proxmox_vm_qemu" "haproxy_lb" {
  name        = var.lb_name
  vmid        = var.vm_id
  target_node = var.node_name
  clone       = "ubuntu-22.04-template"
  full_clone  = true

  # CPU Configuration
  cores   = 2
  sockets = 1
  cpu     = "host"

  # Memory Configuration
  memory = 2048

  # Network Configuration
  network {
    model    = "virtio"
    bridge   = "vmbr0"
    firewall = true
    link_down = false
  }

  # IP Configuration (cloud-init)
  ipconfig0 = "ip=${var.lb_ip}/24,gw=${var.lb_gateway}"

  # SSH Keys
  sshkeys = <<-EOT
    ${var.ssh_public_key}
  EOT

  # Tags
  tags = "load-balancer;haproxy;production"

  # Agent
  agent = 1

  # Operating System
  os_type = "cloud-init"

  lifecycle {
    ignore_changes = [
      network,
      sshkeys
    ]
  }
}

# =============================================================================
# HAProxy Configuration Template
# =============================================================================
data "template_file" "haproxy_cfg" {
  template = file("${path.module}/templates/haproxy.cfg.tmpl")

  vars = {
    lb_name         = var.lb_name
    backend_servers = join("\n", [
      for server in local.backend_configs : "    server ${server.name} ${server.ip}:${server.port} check inter 2000 rise 3 fall 3 ${server.backup}"
    ])
    mysql_servers = join("\n", [
      for server in local.mysql_configs : "    server ${server.name} ${server.ip}:${server.port} check inter 2000 rise 2 fall 3"
    ])
    redis_servers = join("\n", [
      for server in local.redis_configs : "    server ${server.name} ${server.ip}:${server.port} check inter 2000 rise 2 fall 3"
    ])
    stats_password = var.ha_password
    ssl_cert_path  = var.ssl_cert_path
  }
}

# =============================================================================
# Provisioner - Install and Configure HAProxy
# =============================================================================
resource "null_resource" "configure_haproxy" {
  depends_on = [proxmox_vm_qemu.haproxy_lb]

  connection {
    type     = "ssh"
    host     = var.lb_ip
    user     = "root"
    password = var.ssh_password
  }

  # Install HAProxy
  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "apt-get install -y haproxy",
      "systemctl enable haproxy"
    ]
  }

  # Upload configuration
  provisioner "file" {
    content     = data.template_file.haproxy_cfg.rendered
    destination = "/etc/haproxy/haproxy.cfg"
  }

  # Restart HAProxy
  provisioner "remote-exec" {
    inline = [
      "haproxy -c -f /etc/haproxy/haproxy.cfg",
      "systemctl restart haproxy",
      "systemctl status haproxy"
    ]
  }
}

# =============================================================================
# Outputs
# =============================================================================
output "lb_name" {
  description = "Load balancer name"
  value       = proxmox_vm_qemu.haproxy_lb.name
}

output "lb_ip" {
  description = "Load balancer IP address"
  value       = var.lb_ip
}

output "backend_servers" {
  description = "Configured backend servers"
  value       = var.backend_servers
}
