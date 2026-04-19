# Proxmox Storage Module Outputs

output "storage_id" {
  description = "Storage ID/Name"
  value       = var.storage_name
}

output "storage_type" {
  description = "Storage backend type"
  value       = var.storage_type
}

output "storage_path" {
  description = "Storage path or mount point"
  value = one(compact([
    var.storage_path,
    var.nfs_export,
    var.zfs_pool,
    var.ceph_pool,
    var.pbs_datastore,
  ]))
}

output "content_types" {
  description = "Content types supported"
  value       = var.content_types
}

output "shared" {
  description = "Storage is shared"
  value       = var.storage_shared
}

output "is_backup_pool" {
  description = "Storage is used for backups"
  value       = var.storage_backup_pool
}

output "capacity" {
  description = "Storage capacity information (requires pvesh)"
  value = {
    # Note: These would need to be populated via external data source
    total = "unknown"
    used  = "unknown"
    available = "unknown"
  }
}

output "mount_command" {
  description = "Command to mount storage (for NFS/CIFS)"
  value = one(compact([
    var.storage_type == "nfs" ? "mount -t nfs ${var.nfs_server}:${var.nfs_export} /mnt/${var.storage_name}" : null,
    var.storage_type == "cifs" ? "mount -t cifs //${var.nfs_server}/${var.nfs_export} /mnt/${var.storage_name}" : null,
  ]))
}
