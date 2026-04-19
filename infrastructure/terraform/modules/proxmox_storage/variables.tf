# Proxmox Storage Module Variables

variable "storage_name" {
  description = "Name/ID of the storage"
  type        = string
}

variable "node_name" {
  description = "Proxmox node to configure storage"
  type        = string
}

variable "storage_type" {
  description = "Storage backend type"
  type        = string
  validation {
    condition     = contains(["dir", "lvm", "nfs", "cifs", "glusterfs", "cephfs", "rbd", "btrfs", "zfs", "zfspool", "pbs"], var.storage_type)
    error_message = "Storage type must be a valid Proxmox storage type."
  }
}

variable "storage_path" {
  description = "Filesystem path (for dir, btrfs, cifs, nfs)"
  type        = string
  default     = null
}

variable "content_types" {
  description = "Content types to store"
  type        = list(string)
  validation {
    condition = alltrue([
      for ct in var.content_types : contains(["images", "rootdir", "vztmpl", "backup", "iso", "snippets"], ct)
    ])
    error_message = "Content types must be valid Proxmox content types."
  }
  default = ["images", "rootdir"]
}

variable "storage_shared" {
  description = "Storage is shared across cluster nodes"
  type        = bool
  default     = false
}

variable "storage_backup_pool" {
  description = "Use as backup storage pool"
  type        = bool
  default     = false
}

variable "max_files" {
  description = "Maximum number of backup files (for backup content)"
  type        = number
  default     = null
}

# LVM-specific
variable "vg_name" {
  description = "LVM volume group name"
  type        = string
  default     = null
}

variable "thin_pool" {
  description = "LVM thin pool name"
  type        = string
  default     = null
}

# NFS-specific
variable "nfs_server" {
  description = "NFS server address"
  type        = string
  default     = null
}

variable "nfs_export" {
  description = "NFS export path"
  type        = string
  default     = null
}

variable "nfs_version" {
  description = "NFS version"
  type        = string
  default     = null
  validation {
    condition     = var.nfs_version == null || contains(["3", "4", "4.1", "4.2"], var.nfs_version)
    error_message = "NFS version must be 3, 4, 4.1, or 4.2"
  }
}

variable "nfs_options" {
  description = "NFS mount options"
  type        = string
  default     = null
}

# CIFS/SMB-specific
variable "cifs_domain" {
  description = "CIFS domain"
  type        = string
  default     = null
}

variable "cifs_username" {
  description = "CIFS username"
  type        = string
  default     = null
  sensitive   = true
}

variable "cifs_password" {
  description = "CIFS password"
  type        = string
  default     = null
  sensitive   = true
}

# Ceph RBD-specific
variable "ceph_pool" {
  description = "Ceph pool name"
  type        = string
  default     = null
}

variable "ceph_mon_host" {
  description = "Ceph monitor hosts (comma-separated)"
  type        = string
  default     = null
}

variable "ceph_user" {
  description = "Ceph RBD user"
  type        = string
  default     = "admin"
}

variable "ceph_keyring" {
  description = "Ceph keyring content"
  type        = string
  default     = null
  sensitive   = true
}

# ZFS-specific
variable "zfs_pool" {
  description = "ZFS pool name"
  type        = string
  default     = null
}

variable "zfs_compression" {
  description = "ZFS compression algorithm"
  type        = string
  default     = null
  validation {
    condition     = var.zfs_compression == null || contains(["lz4", "lzjb", "zle", "gzip", "zstd", "off"], var.zfs_compression)
    error_message = "ZFS compression must be a valid algorithm."
  }
}

variable "zfs_blocksize" {
  description = "ZFS block size"
  type        = string
  default     = null
}

# Proxmox Backup Server-specific
variable "pbs_server" {
  description = "Proxmox Backup Server address"
  type        = string
  default     = null
}

variable "pbs_username" {
  description = "Proxmox Backup Server username"
  type        = string
  default     = null
}

variable "pbs_password" {
  description = "Proxmox Backup Server password"
  type        = string
  default     = null
  sensitive   = true
}

variable "pbs_datastore" {
  description = "Proxmox Backup Server datastore"
  type        = string
  default     = null
}

variable "pbs_fingerprint" {
  description = "Proxmox Backup Server fingerprint"
  type        = string
  default     = null
}

variable "pbs_encryption_key" {
  description = "Proxmox Backup Server encryption key"
  type        = string
  default     = null
  sensitive   = true
}

# General Options
variable "storage_preallocation" {
  description = "Preallocation type (metadata, full, standard)"
  type        = string
  default     = null
  validation {
    condition     = var.storage_preallocation == null || contains(["metadata", "full", "standard"], var.storage_preallocation)
    error_message = "Preallocation must be metadata, full, or standard."
  }
}

variable "storage_nodes" {
  description = "Nodes that can access this storage"
  type        = list(string)
  default     = null
}

variable "storage_disable" {
  description = "Disable storage"
  type        = bool
  default     = false
}

variable "storage_migrate" {
  description = "Migration type (secure, insecure)"
  type        = string
  default     = null
}

variable "storage_bwlimit" {
  description = "Bandwidth limit for migration/backup"
  type        = number
  default     = null
}

variable "storage_format" {
  description = "Default image format (raw, qcow2, vmdk)"
  type        = string
  default     = null
  validation {
    condition     = var.storage_format == null || contains(["raw", "qcow2", "vmdk"], var.storage_format)
    error_message = "Format must be raw, qcow2, or vmdk."
  }
}

variable "storage_ratio" {
  description = "Content ratio for thin provisioning"
  type        = number
  default     = null
}

variable "storage_garbage_collection" {
  description = "Enable garbage collection (for PBS)"
  type        = string
  default     = null
  validation {
    condition     = var.storage_garbage_collection == null || contains(["always", "never"], var.storage_garbage_collection)
    error_message = "Garbage collection must be always or never."
  }
}
