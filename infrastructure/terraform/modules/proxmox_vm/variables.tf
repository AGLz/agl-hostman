# Proxmox VM Module Variables

variable "vm_name" {
  description = "Name of the VM"
  type        = string
}

variable "vm_id" {
  description = "VM ID (auto-assigned if null)"
  type        = number
  default     = null
}

variable "node_name" {
  description = "Proxmox node name"
  type        = string
}

variable "description" {
  description = "VM description"
  type        = string
  default     = null
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

variable "cpu_sockets" {
  description = "Number of CPU sockets"
  type        = number
  default     = 1
}

variable "cpu_type" {
  description = "CPU type (host, kvm64, qemu64, etc.)"
  type        = string
  default     = "host"
}

variable "cpu_units" {
  description = "CPU units for relative weighting (100-1000000)"
  type        = number
  default     = 1024
  validation {
    condition     = var.cpu_units >= 100 && var.cpu_units <= 1000000
    error_message = "CPU units must be between 100 and 1000000."
  }
}

variable "vcpu_percentage" {
  description = "Percentage of CPU resources to allocate (0-200)"
  type        = number
  default     = null
  validation {
    condition     = var.vcpu_percentage == null || (var.vcpu_percentage >= 0 && var.vcpu_percentage <= 200)
    error_message = "VCPU percentage must be between 0 and 200."
  }
}

# Memory Configuration
variable "memory_gb" {
  description = "Memory in GB"
  type        = number
  default     = 4
  validation {
    condition     = var.memory_gb >= 1
    error_message = "Memory must be at least 1 GB."
  }
}

variable "memory_minimum" {
  description = "Minimum memory in MB for ballooning"
  type        = number
  default     = null
}

variable "ballooning" {
  description = "Enable memory ballooning"
  type        = bool
  default     = false
}

# Disk Configuration
variable "disks" {
  description = "List of disks to attach"
  type = list(object({
    type         = string
    storage      = string
    storage_type = optional(string, "lvm") # lvm, directory, zfs, btrfs
    size_gb      = number
    interface    = string # scsi, sata, virtio, ide
    ssd          = optional(bool, true)
    discard      = optional(bool, true)
    iothread     = optional(bool, false)
    cache        = optional(string, "none") # none, writeback, writethrough, unsafe, directsync
    backup       = optional(bool, true)
  }))
  default = [
    {
      type         = "scsi0"
      storage      = "local-lvm"
      storage_type = "lvm"
      size_gb      = 32
      interface    = "scsi"
      ssd          = true
      discard      = true
      iothread     = false
      cache        = "none"
      backup       = true
    }
  ]
}

variable "scsi_hardware" {
  description = "SCSI controller type"
  type        = string
  default     = "virtio-scsi-pci"
}

# Network Configuration
variable "network_interfaces" {
  description = "List of network interfaces"
  type = list(object({
    model      = string # virtio, e1000, rtl8139, vmxnet3
    bridge     = string
    vlan_tag   = optional(number)
    firewall   = optional(bool, false)
    link_down  = optional(bool, false)
    mac_address = optional(string)
    ip_address = optional(string)
    gateway    = optional(string)
  }))
  default = [
    {
      model    = "virtio"
      bridge   = "vmbr0"
      firewall = false
    }
  ]
}

# Cloud-Init Configuration
variable "cloud_init" {
  description = "Cloud-init configuration"
  type = object({
    enabled          = bool
    storage          = optional(string, "local-lvm")
    user             = optional(string)
    password         = optional(string)
    ssh_keys         = optional(list(string))
    ip_config        = optional(map(string))
    nameserver       = optional(string)
    searchdomain     = optional(string)
    ciuser           = optional(string)
    citype           = optional(string, "configdrive2") # configdrive2, nocloud
    ipconfig0        = optional(string) # ip=dhcp or ip=cidr,gw=gateway
    nameserver0      = optional(string)
    searchdomain0    = optional(string)
  })
  default = {
    enabled = false
  }
}

variable "cloud_init_image_url" {
  description = "URL to cloud-init image to import"
  type        = string
  default     = null
}

variable "cloud_init_storage" {
  description = "Storage pool for cloud-init disk"
  type        = string
  default     = "local-lvm"
}

# Operating System Configuration
variable "os_type" {
  description = "Operating system type"
  type        = string
  default     = "l26" # Linux 2.6+ kernel
  validation {
    condition     = contains(["l24", "l26", "win10", "win11", "w2k", "w2k3", "w2k8", "w2k12", "w2k16", "w2k19", "wxp", "wvista", "win7", "win8", "other"], var.os_type)
    error_message = "OS type must be a valid Proxmox OS type."
  }
}

variable "bios" {
  description = "BIOS type (SeaBIOS or OVMF/UEFI)"
  type        = string
  default     = "ovmf"
  validation {
    condition     = contains(["seabios", "ovmf"], var.bios)
    error_message = "BIOS must be seabios or ovmf."
  }
}

variable "efi_disk" {
  description = "EFI disk configuration"
  type = object({
    enabled    = bool
    storage    = optional(string, "local-lvm")
    size       = optional(string, "1M") # 1M, 2M, 4M
    pre_enrolled_keys = optional(bool, true)
  })
  default = {
    enabled = true
    storage = "local-lvm"
    size    = "1M"
    pre_enrolled_keys = true
  }
}

# VM Agent Configuration
variable "qemu_agent" {
  description = "Enable QEMU guest agent"
  type        = bool
  default     = true
}

variable "qemu_agent_timeout" {
  description = "QEMU agent timeout in seconds"
  type        = number
  default     = 60
}

# Boot Configuration
variable "boot_order" {
  description = "Boot device order"
  type        = string
  default     = "order=scsi0;ide2;net0"
}

# VGA/Display Configuration
variable "vga_type" {
  description = "VGA device type"
  type        = string
  default     = "serial0"
}

variable "serial_device" {
  description = "Serial device configuration"
  type        = string
  default     = "socket"
}

# CD-ROM Configuration
variable "iso_storage" {
  description = "Storage pool for ISO images"
  type        = string
  default     = "local"
}

variable "iso_file" {
  description = "ISO file to mount"
  type        = string
  default     = null
}

# High Availability Configuration
variable "ha" {
  description = "High availability configuration"
  type = object({
    enabled    = bool
    group      = optional(string)
    state      = optional(string, "started")
    max_relocate = optional(number, 3)
    max_restart = optional(number, 3)
  })
  default = {
    enabled = false
  }
}

# Automatic Start
variable "onboot" {
  description = "Start VM at boot"
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
  description = "Tags for the VM"
  type        = list(string)
  default     = []
}

variable "labels" {
  description = "Labels for the VM"
  type        = map(string)
  default     = {}
}

# Resource Limits
variable "cpu_limit" {
  description = "CPU limit (cpulimit)"
  type        = number
  default     = null
}

variable "outbound_bandwidth" {
  description = "Outbound bandwidth limit in MB/s"
  type        = number
  default     = null
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

# Ansible Integration
variable "ansible_playbook" {
  description = "Ansible playbook to run after VM creation"
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

# Monitoring and Metrics
variable "enable_metrics" {
  description = "Enable Prometheus metrics collection"
  type        = bool
  default     = true
}
