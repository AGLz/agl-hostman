# Proxmox Storage Module - Main Configuration
# This module configures various storage backends on Proxmox VE

# Directory Storage
resource "proxmox_storage_dir" "dir" {
  count = var.storage_type == "dir" ? 1 : 0

  storage  = var.storage_name
  path     = var.storage_path
  content  = join(",", var.content_types)
  shared   = var.storage_shared
  nodes    = var.storage_nodes != null ? join(",", var.storage_nodes) : null
  disable  = var.storage_disable
  maxfiles = var.max_files

  # Directory-specific options
  preallocation = var.storage_preallocation
  format        = var.storage_format
  is_mountpoint = true
}

# LVM Storage
resource "proxmox_storage_lvm" "lvm" {
  count = var.storage_type == "lvm" ? 1 : 0

  storage         = var.storage_name
  vg_name         = var.vg_name
  content         = join(",", var.content_types)
  shared          = var.storage_shared
  nodes           = var.storage_nodes != null ? join(",", var.storage_nodes) : null
  disable         = var.storage_disable
  base_volume     = var.thin_pool != null ? null : var.base_volume_name
  thin_pool       = var.thin_pool
  full            = var.storage_preallocation == "full" ? true : false
  saferemove      = var.storage_saferemove
  saferemove_when = var.storage_saferemove_when
  bwlimit         = var.storage_bwlimit
}

# NFS Storage
resource "proxmox_storage_nfs" "nfs" {
  count = var.storage_type == "nfs" ? 1 : 0

  storage = var.storage_name
  server  = var.nfs_server
  export  = var.nfs_export
  content = join(",", var.content_types)
  shared  = true # NFS is always shared
  nodes   = var.storage_nodes != null ? join(",", var.storage_nodes) : null
  disable = var.storage_disable
  maxfiles = var.max_files

  # NFS options
  options  = var.nfs_options
  version  = var.nfs_version
  mkdir    = true # Create mount point if not exists
}

# CIFS/SMB Storage
resource "proxmox_storage_cifs" "cifs" {
  count = var.storage_type == "cifs" ? 1 : 0

  storage = var.storage_name
  server  = var.nfs_server # Reuse as server address
  share   = var.nfs_export  # Reuse as share path
  content = join(",", var.content_types)
  shared  = true
  nodes   = var.storage_nodes != null ? join(",", var.storage_nodes) : null
  disable = var.storage_disable
  maxfiles = var.max_files

  # CIFS options
  domain   = var.cifs_domain
  username = var.cifs_username
  password = var.cifs_password
  options  = var.nfs_options
}

# ZFS Storage
resource "proxmox_storage_zfs" "zfs" {
  count = var.storage_type == "zfs" || var.storage_type == "zfspool" ? 1 : 0

  storage        = var.storage_name
  pool           = var.zfs_pool
  content        = join(",", var.content_types)
  shared         = var.storage_shared
  sparse         = var.storage_preallocation != "full"
  nodes          = var.storage_nodes != null ? join(",", var.storage_nodes) : null
  disable        = var.storage_disable
  blocksize      = var.zfs_blocksize
  compression    = var.zfs_compression
  is_mountpoint  = var.storage_type == "zfs"
}

# Ceph RBD Storage
resource "proxmox_storage_rbd" "rbd" {
  count = var.storage_type == "rbd" ? 1 : 0

  storage     = var.storage_name
  pool        = var.ceph_pool
  content     = join(",", var.content_types)
  shared      = true
  nodes       = var.storage_nodes != null ? join(",", var.storage_nodes) : null
  disable     = var.storage_disable
  monhost     = var.ceph_mon_host
  username    = var.ceph_user
  krbd        = true
  bwlimit     = var.storage_bwlimit

  # Keyring (must be configured on Proxmox nodes separately)
}

# GlusterFS Storage
resource "proxmox_storage_glusterfs" "glusterfs" {
  count = var.storage_type == "glusterfs" ? 1 : 0

  storage = var.storage_name
  server  = var.nfs_server      # Reuse as server address
  volume  = var.nfs_export      # Reuse as volume name
  content = join(",", var.content_types)
  shared  = true
  nodes   = var.storage_nodes != null ? join(",", var.storage_nodes) : null
  disable = var.storage_disable
  options = var.nfs_options
}

# Proxmox Backup Server Storage
resource "proxmox_storage_pbs" "pbs" {
  count = var.storage_type == "pbs" ? 1 : 0

  storage        = var.storage_name
  server         = var.pbs_server
  username       = var.pbs_username
  password       = var.pbs_password
  datastore      = var.pbs_datastore
  fingerprint    = var.pbs_fingerprint
  encryption_key = var.pbs_encryption_key
  content        = join(",", var.content_types)
  shared         = true
  nodes          = var.storage_nodes != null ? join(",", var.storage_nodes) : null
  disable        = var.storage_disable
  gc             = var.storage_garbage_collection
  bwlimit        = var.storage_bwlimit
  maxfiles       = var.max_files
  prune          = var.storage_prune != null ? {
    keep_daily    = var.storage_prune.keep_daily
    keep_weekly   = var.storage_prune.keep_weekly
    keep_monthly  = var.storage_prune.keep_monthly
    keep_yearly   = var.storage_prune.keep_yearly
    keep_last     = var.storage_prune.keep_last
  } : null
}

# Configure retention policy
variable "storage_prune" {
  description = "Retention policy for backups"
  type = object({
    keep_daily   = optional(number, 7)
    keep_weekly  = optional(number, 4)
    keep_monthly = optional(number, 3)
    keep_yearly  = optional(number, 1)
    keep_last    = optional(number, 3)
  })
  default = null
}

variable "storage_saferemove" {
  description = "Enable saferemove for LVM"
  type        = bool
  default     = false
}

variable "storage_saferemove_when" {
  description = "When to run saferemove"
  type        = string
  default     = "never"
  validation {
    condition     = contains(["never", "outdated", "immediate"], var.storage_saferemove_when)
    error_message = "Saferemove when must be never, outdated, or immediate."
  }
}

variable "base_volume_name" {
  description = "Base volume name for LVM"
  type        = string
  default     = "base"
}
