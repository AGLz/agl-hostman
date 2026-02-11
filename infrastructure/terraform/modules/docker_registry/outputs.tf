# =============================================================================
# Docker Registry Module - Outputs
# AGL Hostman - Infrastructure as Code
# =============================================================================

output "registry_url" {
  description = "Registry URL"
  value       = "${var.harbor_enabled ? "harbor-core" : var.registry_name}:${var.registry_port}"
}

output "registry_host" {
  description = "Registry hostname"
  value       = var.harbor_enabled ? "harbor-core" : var.registry_name
}

output "registry_port" {
  description = "Registry port"
  value       = var.registry_port
}

output "ui_url" {
  description = "Registry UI URL"
  value       = var.registry_ui_enabled ? "http://${var.registry_name}-ui:${var.registry_ui_port}" : null
}

output "ui_port" {
  description = "Registry UI port"
  value       = var.registry_ui_enabled ? var.registry_ui_port : null
}

output "data_volume" {
  description = "Registry data volume name"
  value       = docker_volume.registry_data.name
}

output "network_name" {
  description = "Docker network name"
  value       = docker_network.registry.name
}

output "registry_container_id" {
  description = "Registry container ID"
  value       = var.harbor_enabled ? null : try(docker_container.registry[0].id, null)
}

output "ui_container_id" {
  description = "UI container ID"
  value       = var.harbor_enabled ? null : try(docker_container.registry_ui[0].id, null)
}

output "is_harbor" {
  description = "Using Harbor instead of simple registry"
  value       = var.harbor_enabled
}

output "connection_info" {
  description = "Connection information"
  value = {
    registry = {
      host = var.harbor_enabled ? "harbor-core" : var.registry_name
      port = var.registry_port
      url  = "${var.harbor_enabled ? "harbor-core" : var.registry_name}:${var.registry_port}"
    }
    ui = var.registry_ui_enabled ? {
      host = "${var.registry_name}-ui"
      port = var.registry_ui_port
      url  = "http://${var.registry_name}-ui:${var.registry_ui_port}"
    } : null
    network = docker_network.registry.name
  }
}
