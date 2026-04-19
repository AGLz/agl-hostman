# =============================================================================
# Docker Service Module - Outputs
# AGL Hostman - Infrastructure as Code
# =============================================================================

output "container_name" {
  description = "Container name"
  value       = local.container_name
}

output "container_id" {
  description = "Container ID"
  value       = var.enable_swarm ? null : try(docker_container.this[0].id, null)
}

output "service_id" {
  description = "Docker Swarm Service ID"
  value       = var.enable_swarm ? try(docker_service.this[0].id, null) : null
}

output "image" {
  description = "Docker image with tag"
  value       = local.full_image
}

output "ip_address" {
  description = "Container IP address (when using custom network)"
  value       = var.enable_swarm || var.networks[0] == "bridge" ? null : try(docker_container.this[0].ip_data[0].ip, null)
}

output "network_name" {
  description = "Network name"
  value       = var.networks[0]
}

output "ports" {
  description = "Published ports"
  value       = var.ports
}

output "health_status" {
  description = "Container health status"
  value       = var.enable_swarm ? null : try(docker_container.this[0].health_status, null)
}

output "volume_name" {
  description = "Data volume name"
  value       = length(var.volumes) > 0 ? docker_volume.data[0].name : null
}

output "service_name" {
  description = "Service name"
  value       = var.service_name
}

output "is_swarm" {
  description = "Whether deployed as Swarm service"
  value       = var.enable_swarm
}

output "replicas" {
  description = "Number of replicas (Swarm mode)"
  value       = var.enable_swarm ? var.swarm_replicas : 1
}

output "connection_info" {
  description = "Connection information for service"
  value = {
    name     = local.container_name
    image    = local.full_image
    ports    = var.ports
    networks = var.networks
    ip       = var.enable_swarm || var.networks[0] == "bridge" ? null : try(docker_container.this[0].ip_data[0].ip, null)
  }
}
