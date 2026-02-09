# Proxmox Network Module - Main Configuration
# This module configures network bridges and bonds on Proxmox VE

locals {
  bridge_cidr = var.bridge_address != null && var.bridge_netmask != null ? "${var.bridge_address}/${var.bridge_netmask}" : null
}

# Network Bridge Configuration
resource "proxmox_network_bridge" "this" {
  count = var.bridge_type == "linux" ? 1 : 0

  node = var.node_name
  name = var.bridge_name

  # Bridge Configuration
  address = var.bridge_address
  netmask = var.bridge_netmask
  gateway = var.bridge_gateway

  # Physical Ports
  bridge_ports = length(var.bond_slaves) > 0 ? null : join(",", var.bridge_ports)
  bridge_vids = var.vlan_aware ? null : null

  # Bridge Options
  bridge_stp = var.bridge_stp
  bridge_fd  = var.bridge_fd
  bridge_hello_time = var.bridge_hello_time
  bridge_max_age   = var.bridge_max_age
  bridge_priority  = var.bridge_priority

  # VLAN Configuration
  vlan_aware = var.vlan_aware
  vlan_tag   = var.vlan_tag

  # Bond Configuration (if slaves specified)
  bond_mode    = length(var.bond_slaves) > 0 ? var.bond_mode : null
  bond_slaves  = length(var.bond_slaves) > 0 ? join(",", var.bond_slaves) : null
  bond_miimon  = var.bond_miimon
  bond_xmit_hash_policy = length(var.bond_slaves) > 0 ? var.bond_xmit_hash_policy : null
  bond_lacp_rate = length(var.bond_slaves) > 0 ? var.bond_lacp_rate : null

  # Other Options
  autostart = var.autostart
  mtu       = var.mtu
  firewall  = var.firewall
  comment   = var.comment

  # Apply configuration
  apply_config = true
}

# Alternative: Manual network configuration via file
resource "local_file" "network_config" {
  count = var.bridge_type == "linux" ? 0 : 1

  content = templatefile("${path.module}/templates/network-interfaces.tpl", {
    bridge_name    = var.bridge_name
    bridge_address = var.bridge_address
    bridge_cidr    = local.bridge_cidr
    bridge_gateway = var.bridge_gateway
    bridge_ports   = length(var.bond_slaves) > 0 ? "bond0" : join(" ", var.bridge_ports)
    vlan_aware     = var.vlan_aware
    bridge_stp     = var.bridge_stp
    bridge_fd      = var.bridge_fd
    autostart      = var.autostart
    mtu            = var.mtu
    bond_mode      = var.bond_mode
    bond_slaves    = length(var.bond_slaves) > 0 ? join(" ", var.bond_slaves) : ""
    bond_miimon    = var.bond_miimon
    bond_lacp_rate = var.bond_lacp_rate
  })

  filename = "${path.module}/outputs/${var.bridge_name}.cfg"
}

# Apply network configuration
resource "null_resource" "apply_network" {
  count = var.bridge_type == "linux" ? 0 : 1

  provisioner "local-exec" {
    command = <<-EOT
      # Copy network config to Proxmox node
      scp ${local_file.network_config[0].filename} root@${var.node_name}:/tmp/network.cfg

      # Backup current config
      ssh root@${var.node_name} "cp /etc/network/interfaces /etc/network/interfaces.bak"

      # Apply new config
      ssh root@${var.node_name} "mv /tmp/network.cfg /etc/network/interfaces.d/${var.bridge_name}"

      # Reload network
      ssh root@${var.node_name} "ifreload -a"
    EOT
  }

  depends_on = [local_file.network_config]
}

# Firewall Configuration (if enabled)
resource "proxmox_firewall_options" "this" {
  count = var.firewall ? 1 : 0

  node      = var.node_name
  bridge    = var.bridge_name
  enable    = true
  log_level = "info"
  policy_in  = "ACCEPT"
  policy_out = "ACCEPT"
}
