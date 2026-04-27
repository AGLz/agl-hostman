# =============================================================================
# Docker Compose Module - Outputs
# AGL Hostman - Infrastructure as Code
# =============================================================================

output "project_name" {
  description = "Compose project name"
  value       = var.project_name
}

output "compose_file" {
  description = "Path to compose file"
  value       = local.has_service_map ? local_file.compose[0].filename : var.compose_file
}

output "services" {
  description = "List of service names"
  value       = keys(var.services)
}

output "networks" {
  description = "Created networks"
  value       = { for k, v in docker_network.this : k => v.name }
}

output "volumes" {
  description = "Created volumes"
  value       = { for k, v in docker_volume.this : k => v.name }
}

output "containers" {
  description = "Container information"
  value = {
    for k, v in docker_container.from_services : k => {
      id       = v.id
      name     = v.name
      image    = v.image
      ip_address = try(v.ip_data[0].ip, null)
      status   = v.status
    }
  }
}

output "service_info" {
  description = "Service connection information"
  value = {
    for k, v in docker_container.from_services : k => {
      name     = v.name
      image    = v.image
      ports    = try(var.services[k].ports, [])
      networks = try(var.services[k].networks, [])
      ip       = try(v.ip_data[0].ip, null)
    }
  }
}
