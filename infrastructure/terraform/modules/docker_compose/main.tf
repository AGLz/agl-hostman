# =============================================================================
# Docker Compose Module - Main Configuration
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
  project_name = var.project_name
  has_compose_file = var.compose_file != null
  has_inline_compose = var.compose_definition != null
  has_service_map = length(var.services) > 0
}

# =============================================================================
# Create Networks
# =============================================================================
resource "docker_network" "this" {
  for_each = var.networks

  name   = "${var.project_name}_${each.key}"
  driver = each.value.driver

  dynamic "ipam_config" {
    for_each = each.value.subnet != null ? [1] : []
    content {
      subnet = each.value.subnet
    }
  }

  labels = merge({
    "com.docker.compose.project" = var.project_name
    "com.aglhostman.managed-by" = "terraform"
  }, try(each.value.labels, {}))
}

# =============================================================================
# Create Volumes
# =============================================================================
resource "docker_volume" "this" {
  for_each = var.volumes

  name   = "${var.project_name}_${each.key}"
  driver = each.value.driver

  dynamic "driver_opts" {
    for_each = length(try(each.value.driver_opts, {})) > 0 ? [1] : []
    content {
      for_each = each.value.driver_opts
      content {
        name  = driver_opts.key
        value = driver_opts.value
      }
    }
  }

  labels = merge({
    "com.docker.compose.project" = var.project_name
    "com.aglhostman.managed-by" = "terraform"
  }, try(each.value.labels, {}))
}

# =============================================================================
# Generate Compose File (if using service map)
# =============================================================================
data "template_file" "compose_inline" {
  count   = local.has_service_map ? 1 : 0

  template = <<-YAML
    version: "3.8"

    {% if length(var.networks) > 0 %}
    networks:
    {% for network_name, network_config in var.networks %}
      {{ network_name }}:
        driver: {{ network_config.driver }}
        {% if network_config.subnet %}
        ipam:
          config:
            - subnet: {{ network_config.subnet }}
        {% endif %}
    {% endfor %}
    {% endif %}

    {% if length(var.volumes) > 0 %}
    volumes:
    {% for volume_name, volume_config in var.volumes %}
      {{ volume_name }}:
        driver: {{ volume_config.driver }}
    {% endfor %}
    {% endif %}

    services:
    {% for service_name, service_config in var.services %}
      {{ service_name }}:
        image: {{ service_config.image }}
        {% if service_config.command %}
        command:
        {% for cmd in service_config.command %}
          - {{ cmd }}
        {% endfor %}
        {% endif %}
        {% if service_config.entrypoint %}
        entrypoint:
        {% for entry in service_config.entrypoint %}
          - {{ entry }}
        {% endfor %}
        {% endif %}
        {% if service_config.environment %}
        environment:
        {% for key, value in service_config.environment %}
          {{ key }}: {{ value }}
        {% endfor %}
        {% endif %}
        {% if service_config.ports %}
        ports:
        {% for port in service_config.ports %}
          - "{{ port.ip }}:{{ port.external }}:{{ port.internal }}/{{ port.protocol }}"
        {% endfor %}
        {% endif %}
        {% if service_config.volumes %}
        volumes:
        {% for volume in service_config.volumes %}
          - {{ volume.host_path }}:{{ volume.container_path }}:{{ volume.mode }}
        {% endfor %}
        {% endif %}
        {% if service_config.networks %}
        networks:
        {% for network in service_config.networks %}
          - {{ network }}
        {% endfor %}
        {% endif %}
        {% if service_config.restart %}
        restart: {{ service_config.restart }}
        {% endif %}
        {% if service_config.depends_on %}
        depends_on:
        {% for dep in service_config.depends_on %}
          - {{ dep }}
        {% endfor %}
        {% endif %}
        {% if service_config.deploy %}
        deploy:
          {{ service_config.deploy | tojson }}
        {% endif %}
        {% if service_config.healthcheck %}
        healthcheck:
          {{ service_config.healthcheck | tojson }}
        {% endif %}
        {% if service_config.labels %}
        labels:
          {% for key, value in service_config.labels %}
          {{ key }}: {{ value }}
          {% endfor %}
        {% endif %}
    {% endfor %}
  YAML

  vars = {
    networks = var.networks
    volumes  = var.volumes
    services = var.services
  }
}

# =============================================================================
# Write Compose File
# =============================================================================
resource "local_file" "compose" {
  count = local.has_service_map ? 1 : 0

  content  = data.template_file.compose_inline[0].rendered
  filename = "${path.module}/docker-compose.yml"
}

# =============================================================================
# Docker Container Resources (from service map)
# =============================================================================
resource "docker_container" "from_services" {
  for_each = local.has_service_map ? var.services : {}

  name        = "${var.project_name}_${each.key}"
  image       = each.value.image
  hostname    = each.key

  restart     = try(each.value.restart, "unless-stopped")

  # Command
  dynamic "command" {
    for_each = try(each.value.command, null) != null ? [1] : []
    content {
      command = join(" ", each.value.command)
    }
  }

  # Entrypoint
  entrypoint = try(each.value.entrypoint, null)

  # Ports
  dynamic "ports" {
    for_each = try(each.value.ports, [])
    content {
      internal = ports.value.internal
      external = ports.value.external
      protocol = try(ports.value.protocol, "tcp")
      ip       = try(ports.value.ip, "0.0.0.0")
    }
  }

  # Volumes
  dynamic "volumes" {
    for_each = try(each.value.volumes, [])
    content {
      host_path       = volumes.value.host_path
      container_path = volumes.value.container_path
      read_only      = can(regex("^ro$", volumes.value.mode))
    }
  }

  # Networks
  dynamic "networks_advanced" {
    for_each = try(each.value.networks, ["bridge"])
    content {
      name = contains(keys(var.networks), networks_advanced.value) ? "${var.project_name}_${networks_advanced.value}" : networks_advanced.value
    }
  }

  # Environment
  dynamic "env" {
    for_each = try(each.value.environment, {})
    content {
      value = "${env.key}=${env.value}"
    }
  }

  # Labels
  labels = merge({
    "com.docker.compose.project"    = var.project_name
    "com.docker.compose.service"   = each.key
    "com.aglhostman.managed-by"   = "terraform"
  }, try(each.value.labels, {}))

  depends_on = [
    docker_network.this,
    docker_volume.this
  ]
}

# =============================================================================
# Docker Compose Execution (for external compose file)
# =============================================================================
resource "null_resource" "compose_up" {
  count = local.has_compose_file || local.has_inline_compose ? 1 : 0

  triggers = {
    compose_file      = local.has_compose_file ? filesha256(var.compose_file) : ""
    compose_definition = local.has_inline_compose ? sha256(var.compose_definition) : ""
    services_hash     = local.has_service_map ? sha256(jsonencode(var.services)) : ""
  }

  provisioner "local-exec" {
    command = <<-EOT
      {% if local.has_compose_file %}
      COMPOSE_FILE="${var.compose_file}"
      {% elif local.has_inline_compose %}
      COMPOSE_FILE="${path.module}/inline-compose.yml"
      echo '${var.compose_definition}' > "$COMPOSE_FILE"
      {% else %}
      COMPOSE_FILE="${local_file.compose[0].filename}"
      {% endif %}

      WORKING_DIR="${var.working_dir:-$(dirname "$COMPOSE_FILE")}"

      cd "$WORKING_DIR"

      {% if var.pull_images_first %}
      docker-compose -f "$COMPOSE_FILE" -p "${var.project_name}" pull
      {% endif %}

      docker-compose -f "$COMPOSE_FILE" -p "${var.project_name}" up -d

      {% if var.remove_orphans %}
      docker-compose -f "$COMPOSE_FILE" -p "${var.project_name}" --remove-orphans up -d
      {% endif %}
    EOT

    interpreter = ["/bin/bash", "-c"]
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      {% if local.has_compose_file %}
      COMPOSE_FILE="${var.compose_file}"
      {% elif local.has_inline_compose %}
      COMPOSE_FILE="${path.module}/inline-compose.yml"
      {% else %}
      COMPOSE_FILE="${local_file.compose[0].filename}"
      {% endif %}

      WORKING_DIR="${var.working_dir:-$(dirname "$COMPOSE_FILE")}"

      cd "$WORKING_DIR"

      docker-compose -f "$COMPOSE_FILE" -p "${var.project_name}" --timeout {{ var.timeout }} down

      {% if var.remove_volumes %}
      docker-compose -f "$COMPOSE_FILE" -p "${var.project_name}" --volumes down
      {% endif %}
    EOT

    interpreter = ["/bin/bash", "-c"]
  }
}

# =============================================================================
# Ansible Provisioner (if playbook specified)
# =============================================================================
resource "null_resource" "ansible_provisioner" {
  count = var.ansible_playbook != null ? 1 : 0

  triggers = {
    compose_hash = local.has_compose_file ? filesha256(var.compose_file) : sha256(jsonencode(var.services))
    playbook     = var.ansible_playbook
  }

  provisioner "local-exec" {
    command = <<-EOT
      ansible-playbook \
        -i "${var.ansible_inventory_path}" \
        "${var.ansible_playbook}" \
        --extra-vars "compose_project=${var.project_name}"
    EOT
  }

  depends_on = [
    null_resource.compose_up,
    docker_container.from_services
  ]
}
