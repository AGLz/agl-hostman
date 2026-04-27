# =============================================================================
# Docker Service Module - Main Configuration
# AGL Hostman - Infrastructure as Code
# =============================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 3.0.0"
    }
  }
}

locals {
  container_name = coalesce(var.container_name, var.service_name)
  full_image    = "${var.image}:${var.image_tag}"
  default_labels = merge({
    "com.aglhostman.managed-by" = "terraform"
    "com.aglhostman.service"   = var.service_name
    "com.docker.compose.project" = "agl-hostman"
  }, var.labels)
}

# =============================================================================
# Docker Network (if creating custom network)
# =============================================================================
resource "docker_network" "this" {
  count = var.networks[0] != "bridge" && !contains(["network_attaching"], var.networks) ? 1 : 0

  name   = var.networks[0]
  driver = "bridge"

  ipam_config {
    subnet = var.subnet
  }

  labels = local.default_labels
}

# =============================================================================
# Docker Volume (for data persistence)
# =============================================================================
resource "docker_volume" "data" {
  count = length(var.volumes) > 0 ? 1 : 0

  name = "${var.service_name}-data"
  driver = "local"

  labels = local.default_labels
}

# =============================================================================
# Docker Container
# =============================================================================
resource "docker_container" "this" {
  count = var.enable_swarm ? 0 : 1

  name        = local.container_name
  image       = local.full_image
  hostname    = local.container_name
  restart     = var.restart_policy

  # Command and Entrypoint
  command    = var.command
  entrypoint = var.entrypoint
  user       = var.user

  # Ports
  dynamic "ports" {
    for_each = var.ports
    content {
      internal = ports.value.internal
      external = ports.value.external
      protocol = ports.value.protocol
      ip       = ports.value.ip
    }
  }

  # Volumes
  dynamic "volumes" {
    for_each = var.volumes
    content {
      host_path       = volumes.value.host_path
      container_path = volumes.value.container_path
      read_only      = can(regex("^ro$", volumes.value.mode))
    }
  }

  # Docker Socket Mount
  dynamic "volumes" {
    for_each = var.host_docker_socket ? [1] : []
    content {
      host_path       = "/var/run/docker.sock"
      container_path = "/var/run/docker.sock"
      read_only      = false
    }
  }

  # Environment Variables
  dynamic "env" {
    for_each = var.environment
    content {
      value = "${env.key}=${env.value}"
    }
  }

  # Environment Files
  dynamic "env_file" {
    for_each = var.environment_files
    content {
      path = env_file.value
    }
  }

  # Networks
  dynamic "networks_advanced" {
    for_each = var.networks
    content {
      name = networks_advanced.value
    }
  }

  # Labels
  labels = local.default_labels

  # Logging Configuration
  log_driver   = var.log_config.driver
  dynamic "log_opts" {
    for_each = var.log_config.options
    content {
      name  = log_opts.key
      value = log_opts.value
    }
  }

  # Health Check
  dynamic "healthcheck" {
    for_each = var.healthcheck != null ? [1] : []
    content {
      command     = var.healthcheck.command
      interval    = var.healthcheck.interval
      timeout     = var.healthcheck.timeout
      retries     = var.healthcheck.retries
      start_period = var.healthcheck.start_period
    }
  }

  # Resource Limits
  dynamic "deploy" {
    for_each = var.deploy_resources != null ? [1] : []
    content {
      dynamic "resources" {
        content {
          limits = {
            cpus    = var.deploy_resources.limits.cpus
            memory  = var.deploy_resources.limits.memory
          }
          reservations = var.deploy_resources.reservations
        }
      }
    }
  }

  # Privileged Mode
  privileged = var.privileged

  # DNS Configuration
  dns         = var.dns_servers
  dns_search  = var.dns_search_domains

  # Extra Hosts
  dynamic "hosts" {
    for_each = var.extra_hosts
    content {
      ip   = hosts.value
      host = hosts.key
    }
  }

  # Sysctls
  dynamic "sysctls" {
    for_each = var.sysctls
    content {
      name  = sysctls.key
      value = sysctls.value
    }
  }

  # Read-only Root
  read_only = var.read_only

  # Tmpfs Mounts
  dynamic "tmpfs" {
    for_each = var.tmpfs
    content {
      target = tmpfs.value.target
      size   = tmpfs.value.size
    }
  }

  # Capabilities
  dynamic "cap_add" {
    for_each = var.cap_add
    content {
      value = cap_add.value
    }
  }

  dynamic "cap_drop" {
    for_each = var.cap_drop
    content {
      value = cap_drop.value
    }
  }

  # Security Options
  dynamic "security_opt" {
    for_each = var.security_opt
    content {
      name = security_opt.value
    }
  }

  # Dependencies (using wait for other containers)
  depends_on = [
    docker_network.this,
    docker_volume.data
  ]

  lifecycle {
    ignore_changes = [
      image,
      image_busybox
    ]
  }
}

# =============================================================================
# Docker Swarm Service (alternative to container)
# =============================================================================
resource "docker_service" "this" {
  count = var.enable_swarm ? 1 : 0

  name        = local.container_name
  image       = local.full_image

  # Replicas and Mode
  mode {
    replicated {
      replicas = var.swarm_mode == "replicated" ? var.swarm_replicas : 0
    }
    global {
      # When mode is global, replicated block is ignored
    }
  }

  # Command and Entrypoint
  command    = var.command
  args       = var.command
  entrypoint = var.entrypoint
  user       = var.user

  # Ports
  dynamic "endpoint_spec" {
    for_each = length(var.ports) > 0 ? [1] : []
    content {
      mode = "vip"

      dynamic "ports" {
        for_each = var.ports
        content {
          name        = "${var.service_name}-port-${ports.value.internal}"
          protocol    = ports.value.protocol
          target_port = ports.value.internal
          published_port = ports.value.external
          publish_mode = "ingress"
        }
      }
    }
  }

  # Environment Variables
  env = [
    for k, v in var.environment : "${k}=${v}"
  ]

  # Labels
  labels = local.default_labels

  # Container Labels
  dynamic "container_labels" {
    for_each = var.labels
    content {
      name  = container_labels.key
      value = container_labels.value
    }
  }

  # Networks
  dynamic "networks" {
    for_each = var.networks
    content {
      name = networks.value
    }
  }

  # Update Configuration
  dynamic "update_config" {
    for_each = var.update_config != null ? [1] : []
    content {
      parallelism     = var.update_config.parallelism
      delay          = var.update_config.delay
      failure_action = var.update_config.failure_action
      monitor        = var.update_config.monitor
      max_failure_ratio = var.update_config.max_failure_ratio
    }
  }

  # Rollback Configuration
  dynamic "rollback_config" {
    for_each = var.rollback_config != null ? [1] : []
    content {
      parallelism     = var.rollback_config.parallelism
      delay          = var.rollback_config.delay
      failure_action = var.rollback_config.failure_action
      monitor        = var.rollback_config.monitor
      max_failure_ratio = var.rollback_config.max_failure_ratio
    }
  }

  # Placement Constraints
  dynamic "placement" {
    for_each = length(var.placement_constraints) > 0 ? [1] : []
    content {
      constraints = var.placement_constraints
    }
  }

  # Resources
  dynamic "resources" {
    for_each = var.deploy_resources != null ? [1] : []
    content {
      limits = {
        cpus    = var.deploy_resources.limits.cpus
        memory  = var.deploy_resources.limits.memory
      }
      reservations = var.deploy_resources.reservations
    }
  }

  # Restart Condition
  restart_policy {
    condition = var.restart_policy == "unless-stopped" ? "any" : var.restart_policy
  }

  # Health Check
  dynamic "healthcheck" {
    for_each = var.healthcheck != null ? [1] : []
    content {
      command     = var.healthcheck.command
      interval    = var.healthcheck.interval
      timeout     = var.healthcheck.timeout
      retries     = var.healthcheck.retries
      start_period = var.healthcheck.start_period
    }
  }
}

# =============================================================================
# Container IP Address Output (for service discovery)
# =============================================================================
data "docker_network" "network_info" {
  count = var.enable_swarm || var.networks[0] == "bridge" ? 0 : 1

  name = var.networks[0]
}
