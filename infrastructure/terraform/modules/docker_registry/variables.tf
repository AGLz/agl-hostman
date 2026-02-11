# =============================================================================
# Docker Registry Module - Variables
# AGL Hostman - Infrastructure as Code
# =============================================================================

variable "registry_name" {
  description = "Name of the registry service"
  type        = string
  default     = "docker-registry"
}

variable "registry_port" {
  description = "Port for registry API"
  type        = number
  default     = 5000
}

variable "registry_ui_port" {
  description = "Port for registry UI"
  type        = number
  default     = 8080
}

variable "registry_ui_enabled" {
  description = "Deploy registry UI"
  type        = bool
  default     = true
}

variable "registry_data_dir" {
  description = "Host path for registry data storage"
  type        = string
  default     = "/var/lib/registry"
}

variable "registry_ui_data_dir" {
  description = "Host path for UI data storage"
  type        = string
  default     = "/var/lib/registry-ui"
}

variable "registry_auth_enabled" {
  description = "Enable authentication"
  type        = bool
  default     = false
}

variable "registry_auth_htpasswd" {
  description = "Path to htpasswd file for auth"
  type        = string
  default     = null
}

variable "registry_tls_enabled" {
  description = "Enable TLS"
  type        = bool
  default     = false
}

variable "registry_tls_cert_path" {
  description = "Path to TLS certificate"
  type        = string
  default     = null
}

variable "registry_tls_key_path" {
  description = "Path to TLS private key"
  type        = string
  default     = null
}

variable "registry_storage_driver" {
  description = "Storage driver for registry"
  type        = string
  default     = "filesystem"

  validation {
    condition     = contains(["filesystem", "s3", "azure", "gcs", "swift"], var.registry_storage_driver)
    error_message = "Storage driver must be filesystem, s3, azure, gcs, or swift."
  }
}

variable "registry_s3_config" {
  description = "S3 storage configuration"
  type = object({
    bucket       = string
    region       = string
    accesskey    = string
    secretkey    = string
    regionendpoint = optional(string)
    encrypt      = optional(bool, false)
    secure       = optional(bool, true)
    v4auth      = optional(bool, true)
    rootpath     = optional(string, "/")
  })
  default = null
}

variable "registry_delete_enabled" {
  description = "Enable manifest deletion"
  type        = bool
  default     = true
}

variable "registry_log_level" {
  description = "Registry log level"
  type        = string
  default     = "info"

  validation {
    condition     = contains(["debug", "info", "warn", "error", "fatal"], var.registry_log_level)
    error_message = "Log level must be debug, info, warn, error, or fatal."
  }
}

variable "registry_proxy_enabled" {
  description = "Enable proxy to remote registry"
  type        = bool
  default     = false
}

variable "registry_proxy_url" {
  description = "Remote registry URL to proxy"
  type        = string
  default     = "https://registry-1.docker.io"
}

variable "registry_readonly" {
  description = "Run registry in read-only mode"
  type        = bool
  default     = false
}

variable "harbor_enabled" {
  description = "Deploy Harbor instead of simple registry"
  type        = bool
  default     = false
}

variable "harbor_version" {
  description = "Harbor version"
  type        = string
  default     = "v2.10.0"
}

variable "harbor_admin_password" {
  description = "Harbor admin password"
  type        = string
  sensitive   = true
  default     = null
}

variable "harbor_database_password" {
  description = "Harbor database password"
  type        = string
  sensitive   = true
  default     = null
}

variable "network_name" {
  description = "Docker network name"
  type        = string
  default     = "registry-network"
}

variable "labels" {
  description = "Additional labels for containers"
  type        = map(string)
  default     = {}
}
