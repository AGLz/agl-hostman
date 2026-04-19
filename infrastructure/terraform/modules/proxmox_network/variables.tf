# Proxmox Network Module Variables

variable "network_name" {
  description = "Name of the network bridge"
  type        = string
}

variable "bridge_name" {
  description = "Bridge device name (vmbr0, vmbr1, etc.)"
  type        = string
}

variable "node_name" {
  description = "Proxmox node to apply network config"
  type        = string
}

variable "bridge_type" {
  description = "Type of bridge (linux, ovn)"
  type        = string
  default     = "linux"
}

variable "bridge_address" {
  description = "IP address for the bridge interface"
  type        = string
  default     = null
}

variable "bridge_netmask" {
  description = "Netmask or CIDR notation"
  type        = string
  default     = null
}

variable "bridge_gateway" {
  description = "Gateway address"
  type        = string
  default     = null
}

variable "bridge_ports" {
  description = "Physical ports to add to bridge"
  type        = list(string)
  default     = []
}

variable "vlan_aware" {
  description = "Enable VLAN-aware bridge"
  type        = bool
  default     = false
}

variable "vlan_tag" {
  description = "Default VLAN tag for bridge"
  type        = number
  default     = null
}

variable "bridge_stp" {
  description = "Enable Spanning Tree Protocol"
  type        = bool
  default     = false
}

variable "bridge_fd" {
  description = "Bridge forward delay"
  type        = number
  default     = 0
}

variable "bridge_priority" {
  description = "Bridge priority (for STP)"
  type        = number
  default     = 32768
}

variable "bond_primary" {
  description = "Primary bond interface"
  type        = string
  default     = null
}

variable "bond_mode" {
  description = "Bonding mode"
  type        = string
  default     = null
  validation {
    condition     = var.bond_mode == null || contains(["balance-rr", "active-backup", "balance-xor", "broadcast", "802.3ad", "balance-tlb", "balance-alb"], var.bond_mode)
    error_message = "Bond mode must be a valid Linux bonding mode."
  }
}

variable "bond_miimon" {
  description = "Bond link monitoring interval (ms)"
  type        = number
  default     = 100
}

variable "bond_slaves" {
  description = "Slave interfaces for bond"
  type        = list(string)
  default     = []
}

variable "bond_lacp_rate" {
  description = "LACP rate (slow, fast)"
  type        = string
  default     = null
}

variable "bond_xmit_hash_policy" {
  description = "Transmit hash policy for bonding"
  type        = string
  default     = null
}

variable "bridge_hello_time" {
  description = "STP hello time"
  type        = number
  default     = 2
}

variable "bridge_max_age" {
  description = "STP maximum age"
  type        = number
  default     = 20
}

variable "autostart" {
  description = "Start network at boot"
  type        = bool
  default     = true
}

variable "mtu" {
  description = "Maximum Transmission Unit"
  type        = number
  default     = 1500
}

variable "firewall" {
  description = "Enable Proxmox firewall on bridge"
  type        = bool
  default     = false
}

variable "comment" {
  description = "Description/comment for the bridge"
  type        = string
  default     = null
}
