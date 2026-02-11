# =============================================================================
# Docker Compose Module - Variables
# AGL Hostman - Infrastructure as Code
# =============================================================================

variable "compose_file" {
  description = "Path to docker-compose.yml file"
  type        = string
}

variable "compose_definition" {
  description = "Inline compose definition (YAML string)"
  type        = string
  default     = null
}

variable "project_name" {
  description = "Project name for compose"
  type        = string
  default     = "agl-hostman"
}

variable "services" {
  description = "Service definitions (alternative to compose_file)"
  type = map(object({
    image          = string
    command        = optional(list(string))
    entrypoint     = optional(list(string))
    environment    = optional(map(string))
    ports          = optional(list(object({
      internal = number
      external = number
      protocol = optional(string, "tcp")
      ip       = optional(string, "0.0.0.0")
    })), [])
    volumes        = optional(list(object({
      host_path      = string
      container_path = string
      mode          = optional(string, "rw")
    })), [])
    networks       = optional(list(string), ["bridge"])
    restart        = optional(string, "unless-stopped")
    depends_on     = optional(list(string), [])
    deploy         = optional(map(any))
    healthcheck    = optional(map(string))
    labels         = optional(map(string), {})
  }))
  default = {}
}

variable "networks" {
  description = "Network definitions"
  type = map(object({
    driver = optional(string, "bridge")
    subnet = optional(string)
    ipam   = optional(map(string))
  }))
  default = {}
}

variable "volumes" {
  description = "Volume definitions"
  type = map(object({
    driver = optional(string, "local")
    driver_opts = optional(map(string))
    labels = optional(map(string), {})
  }))
  default = {}
}

variable "environment_files" {
  description = "Environment files to load"
  type = list(string)
  default = []
}

variable "working_dir" {
  description = "Working directory for compose"
  type        = string
  default     = null
}

variable "env_files" {
  description = "Environment files to load"
  type = list(string)
  default = []
}

variable "ansible_playbook" {
  description = "Path to Ansible playbook for compose setup"
  type        = string
  default     = null
}

variable "pull_images_first" {
  description = "Pull images before starting services"
  type        = bool
  default     = true
}

variable "remove_orphans" {
  description = "Remove containers for services not in compose"
  type        = bool
  default     = true
}

variable "remove_volumes" {
  description = "Remove volumes when destroying"
  type        = bool
  default     = false
}

variable "timeout" {
  description = "Timeout for operations in seconds"
  type        = number
  default     = 300
}
