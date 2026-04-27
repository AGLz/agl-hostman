# Proxmox LXC Container Module Variables

variable "container_name" {
  description = "Name of the LXC container"
  type        = string
}

variable "container_id" {
  description = "Container ID (auto-assigned if null)"
  type        = number
  default     = null
}

variable "node_name" {
  description = "Proxmox node name"
  type        = string
}

variable "description" {
  description = "Container description"
  type        = string
  default     = null
}

# Container Template
variable "template" {
  description = "Container template to use"
  type = object({
    storage    = string
    template_file = string # e.g., "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
  })
}

# CPU Configuration
variable "cpu_cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
  validation {
    condition     = var.cpu_cores > 0 && var.cpu_cores <= 128
    error_message = "CPU cores must be between 1 and 128."
  }
}

variable "cpu_units" {
  description = "CPU units for relative weighting (100-1000000)"
  type        = number
  default     = 1024
}

variable "cpu_limit" {
  description = "CPU limit (0 = no limit)"
  type        = number
  default     = 0
}

# Memory Configuration
variable "memory_mb" {
  description = "Memory in MB"
  type        = number
  default     = 2048
  validation {
    condition     = var.memory_mb >= 128
    error_message = "Memory must be at least 128 MB."
  }
}

variable "swap_mb" {
  description = "Swap space in MB"
  type        = number
  default     = 512
}

# Storage Configuration
variable "storage" {
  description = "Root filesystem storage configuration"
  type = object({
    storage    = string
    size_gb    = number
    type       = optional(string, "rootdir") # rootdir, subvolume
  })
  default = {
    storage = "local-lvm"
    size_gb = 32
    type    = "rootdir"
  }
}

variable "additional_mounts" {
  description = "Additional mount points"
  type = list(object({
    slot       = string # mp0, mp1, etc.
    storage    = string
    path       = string # Container path
    size       = optional(string)
    backup     = optional(bool, true)
    acl        = optional(bool, false)
    replicate  = optional(bool, false)
    shared     = optional(bool, false)
    ro         = optional(bool, false)
    quota      = optional(bool, true)
  }))
  default = []
}

# Network Configuration
variable "network_interfaces" {
  description = "List of network interfaces"
  type = list(object({
    name    = string # eth0, eth1, etc.
    bridge  = string
    vlan_tag = optional(number)
    firewall = optional(bool, false)
    ip       = optional(string, "dhcp")
    gateway  = optional(string)
    ip6      = optional(string)
    gateway6 = optional(string)
    mtu      = optional(number)
  }))
  default = [
    {
      name   = "eth0"
      bridge = "vmbr0"
      ip     = "dhcp"
    }
  ]
}

# Container Features
variable "features" {
  description = "Container features"
  type = object({
    nesting   = optional(bool, false) # Allow nested virtualization (Docker-in-LXC)
    keyctl    = optional(bool, false) # Allow keyctl() syscall
    fuse      = optional(bool, false) # Allow FUSE filesystems
    netns     = optional(bool, false) # Network namespace for unprivileged
  })
  default = {}
}

# Unprivileged Container
variable "unprivileged" {
  description = "Create unprivileged container (more secure)"
  type        = bool
  default     = true
}

# Container User
variable "username" {
  description = "Default username"
  type        = string
  default     = "root"
}

variable "password" {
  description = "Default password"
  type        = string
  default     = null
  sensitive   = true
}

variable "ssh_public_keys" {
  description = "SSH public keys to inject"
  type        = list(string)
  default     = []
}

# Container Hostname
variable "hostname" {
  description = "Container hostname"
  type        = string
  default     = null
}

# Nameserver
variable "nameserver" {
  description = "DNS server"
  type        = string
  default     = "8.8.8.8"
}

variable "search_domain" {
  description = "DNS search domain"
  type        = string
  default     = "agl.local"
}

# Startup and Boot
variable "onboot" {
  description = "Start container at boot"
  type        = bool
  default     = true
}

variable "startup_order" {
  description = "Startup order (1-100, higher starts first)"
  type        = number
  default     = null
}

# Tags and Labels
variable "tags" {
  description = "Tags for the container"
  type        = list(string)
  default     = []
}

variable "labels" {
  description = "Labels for the container"
  type        = map(string)
  default     = {}
}

# Protection
variable "protection" {
  description = "Set protection flag to prevent accidental removal"
  type        = bool
  default     = false
}

# Template Configuration
variable "is_template" {
  description = "Mark as template"
  type        = bool
  default     = false
}

# High Availability
variable "ha" {
  description = "High availability configuration"
  type = object({
    enabled = bool
    group   = optional(string)
    state   = optional(string, "started")
  })
  default = {
    enabled = false
  }
}

# Console
variable "console" {
  description = "Console type (tty, xterm, shell)"
  type        = string
  default     = "tty"
}

# TTY
variable "tty" {
  description = "Number of TTYs"
  type        = number
  default     = 2
}

# CGroup Configuration
variable "cgroup_mode" {
  description = "CGroup mode"
  type        = string
  default     = null # 1, 2, 3, or null (default)
}

# Ansible Integration
variable "ansible_playbook" {
  description = "Ansible playbook to run after container creation"
  type        = string
  default     = null
}

variable "ansible_extra_vars" {
  description = "Extra variables for Ansible playbook"
  type        = map(string)
  default     = {}
}

variable "ansible_wait_for_ssh" {
  description = "Wait for SSH to be available before running Ansible"
  type        = bool
  default     = true
}

variable "ansible_ssh_timeout" {
  description = "Timeout for SSH availability check"
  type        = number
  default     = 600
}

# Monitoring
variable "enable_metrics" {
  description = "Enable Prometheus metrics collection"
  type        = bool
  default     = true
}
