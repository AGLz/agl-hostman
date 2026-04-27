# =============================================================================
# Docker Service Module - Variables
# AGL Hostman - Infrastructure as Code
# =============================================================================

variable "service_name" {
  description = "Name of the Docker service"
  type        = string
}

variable "container_name" {
  description = "Container name (defaults to service_name)"
  type        = string
  default     = null
}

variable "image" {
  description = "Docker image to run"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag (defaults to latest)"
  type        = string
  default     = "latest"
}

variable "restart_policy" {
  description = "Container restart policy"
  type        = string
  default     = "unless-stopped"

  validation {
    condition     = contains(["no", "on-failure", "always", "unless-stopped"], var.restart_policy)
    error_message = "Restart policy must be no, on-failure, always, or unless-stopped."
  }
}

variable "ports" {
  description = "Port mappings (container:host)"
  type = list(object({
    internal = number
    external = number
    protocol = string
    ip       = string
  }))
  default = []
}

variable "volumes" {
  description = "Volume mounts"
  type = list(object({
    host_path      = string
    container_path = string
    mode          = string
  }))
  default = []
}

variable "environment" {
  description = "Environment variables"
  type = map(string)
  default = {}
}

variable "environment_files" {
  description = "Environment files to load"
  type = list(string)
  default = []
}

variable "networks" {
  description = "Networks to attach the container to"
  type = list(string)
  default = ["bridge"]
}

variable "command" {
  description = "Command to run in container"
  type        = list(string)
  default     = null
}

variable "entrypoint" {
  description = "Container entrypoint"
  type        = list(string)
  default     = null
}

variable "user" {
  description = "User to run container as"
  type        = string
  default     = null
}

variable "labels" {
  description = "Container labels"
  type        = map(string)
  default     = {}
}

variable "log_config" {
  description = "Logging configuration"
  type = object({
    driver   = string
    options  = map(string)
  })
  default = {
    driver = "json-file"
    options = {
      "max-size" = "10m"
      "max-file" = "3"
    }
  }
}

variable "healthcheck" {
  description = "Container health check configuration"
  type = object({
    command     = list(string)
    interval    = string
    timeout     = string
    retries     = number
    start_period = string
  })
  default = null
}

variable "deploy_resources" {
  description = "Resource limits for container"
  type = object({
    limits = object({
      cpus    = string
      memory  = string
    })
    reservations = object({
      cpus    = string
      memory  = string
    })
  })
  default = null
}

variable "dependencies" {
  description = "Service dependencies (for ordering)"
  type = list(string)
  default = []
}

variable "privileged" {
  description = "Run container in privileged mode"
  type        = bool
  default     = false
}

variable "dns_servers" {
  description = "Custom DNS servers for the container"
  type = list(string)
  default = []
}

variable "extra_hosts" {
  description = "Extra hosts entries"
  type = map(string)
  default = {}
}

variable "sysctls" {
  description = "Sysctl options"
  type = map(string)
  default = {}
}

variable "read_only" {
  description = "Mount container root filesystem as read-only"
  type        = bool
  default     = false
}

variable "tmpfs" {
  description = "Tmpfs mounts"
  type = list(object({
    target    = string
    size      = string
    mode      = string
  }))
  default = []
}

variable "cap_add" {
  description = "Linux capabilities to add"
  type = list(string)
  default = []
}

variable "cap_drop" {
  description = "Linux capabilities to drop"
  type = list(string)
  default = ["ALL"]
}

variable "security_opt" {
  description = "Security options"
  type = list(string)
  default = ["no-new-privileges:true"]
}

variable "host_docker_socket" {
  description = "Whether to mount Docker socket (Docker-in-Docker)"
  type        = bool
  default     = false
}

variable "enable_swarm" {
  description = "Deploy as Docker Swarm service instead of container"
  type        = bool
  default     = false
}

variable "swarm_mode" {
  description = "Swarm service mode"
  type        = string
  default     = "replicated"

  validation {
    condition     = contains(["replicated", "global"], var.swarm_mode)
    error_message = "Swarm mode must be replicated or global."
  }
}

variable "swarm_replicas" {
  description = "Number of replicas for replicated mode"
  type        = number
  default     = 1
}

variable "update_config" {
  description = "Update configuration for swarm services"
  type = object({
    parallelism     = number
    delay          = string
    failure_action = string
    monitor        = string
    max_failure_ratio = number
  })
  default = null
}

variable "rollback_config" {
  description = "Rollback configuration for swarm services"
  type = object({
    parallelism     = number
    delay          = string
    failure_action = string
    monitor        = string
    max_failure_ratio = number
  })
  default = null
}

variable "placement_constraints" {
  description = "Placement constraints for swarm services"
  type = list(string)
  default = []
}

variable "proxmox_vm_id" {
  description = "Proxmox VM ID where Docker runs (for dependency tracking)"
  type        = number
  default     = null
}

variable "ansible_playbook" {
  description = "Path to Ansible playbook for service setup"
  type        = string
  default     = null
}
