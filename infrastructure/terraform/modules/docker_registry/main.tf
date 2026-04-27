# =============================================================================
# Docker Registry Module - Main Configuration
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
  registry_labels = merge({
    "com.aglhostman.managed-by" = "terraform"
    "com.aglhostman.component" = "docker-registry"
  }, var.labels)
}

# =============================================================================
# Docker Network
# =============================================================================
resource "docker_network" "registry" {
  name   = var.network_name
  driver = "bridge"

  labels = local.registry_labels
}

# =============================================================================
# Registry Volume
# =============================================================================
resource "docker_volume" "registry_data" {
  name   = "${var.registry_name}-data"
  driver = "local"

  labels = local.registry_labels
}

# =============================================================================
# Registry Configuration
# =============================================================================
data "template_file" "registry_config" {
  template = <<-YAML
    version: 0.1
    log:
      level: {{ var.registry_log_level }}
      fields:
        service: registry
    storage:
      cache:
        blobdescriptor: inmemory
      {{ var.registry_storage_driver == "filesystem" }}
      filesystem:
        rootdirectory: /var/lib/registry
      {{ else if var.registry_storage_driver == "s3" }}
      s3:
        accesskey: {{ var.registry_s3_config.accesskey }}
        secretkey: {{ var.registry_s3_config.secretkey }}
        region: {{ var.registry_s3_config.region }}
        bucket: {{ var.registry_s3_config.bucket }}
        regionendpoint: {{ lookup(var.registry_s3_config, "regionendpoint", "") }}
        encrypt: {{ var.registry_s3_config.encrypt }}
        secure: {{ var.registry_s3_config.secure }}
        v4auth: {{ var.registry_s3_config.v4auth }}
        rootdirectory: {{ lookup(var.registry_s3_config, "rootpath", "/") }}
      {{ end }}
      delete:
        enabled: {{ var.registry_delete_enabled }}
    http:
      addr: :5000
      headers:
        X-Content-Type-Options: [nosniff]
        Access-Control-Allow-Origin: ['*']
        Access-Control-Allow-Methods: ['HEAD', 'GET', 'OPTIONS', 'DELETE']
        Access-Control-Allow-Headers: ['Authorization', 'Accept']
        Access-Control-Max-Age: [1728000]
        Access-Control-Allow-Credentials: [true]
        Access-Control-Expose-Headers: ['Docker-Content-Digest']
    {{ var.registry_auth_enabled }}
    auth:
      htpasswd:
        realm: basic-realm
        path: /auth/htpasswd
    {{ end }}
    {{ var.registry_tls_enabled }}
    tls:
      certificate: /certs/tls.crt
      key: /certs/tls.key
    {{ end }}
    {{ var.registry_proxy_enabled }}
    proxy:
      remoteurl: {{ var.registry_proxy_url }}
    {{ end }}
    {{ var.registry_readonly }}
    readonly:
      enabled: true
    {{ end }}
    health:
      storagedriver:
        enabled: true
        interval: 10s
        threshold: 3
  YAML
}

# =============================================================================
# Registry Container
# =============================================================================
resource "docker_container" "registry" {
  count = var.harbor_enabled ? 0 : 1

  name  = var.registry_name
  image = "registry:2"

  restart = "unless-stopped"

  ports {
    internal = 5000
    external = var.registry_port
    protocol = "tcp"
  }

  volumes {
    host_path       = var.registry_data_dir
    container_path = "/var/lib/registry"
  }

  # Auth volume
  dynamic "volumes" {
    for_each = var.registry_auth_enabled ? [1] : []
    content {
      host_path       = dirname(var.registry_auth_htpasswd)
      container_path = "/auth"
    }
  }

  # TLS volumes
  dynamic "volumes" {
    for_each = var.registry_tls_enabled ? [1] : []
    content {
      host_path       = dirname(var.registry_tls_cert_path)
      container_path = "/certs"
    }
  }

  env = [
    "REGISTRY_CONFIG_PATH=/etc/docker/registry/config.yml"
  ]

  networks_advanced {
    name = docker_network.registry.name
  }

  labels = local.registry_labels

  # Upload config
  provisioner "remote-exec" {
    inline = [
      "mkdir -p /etc/docker/registry",
      "cat > /etc/docker/registry/config.yml <<EOF\n${data.template_file.registry_config.rendered}\nEOF"
    ]
  }
}

# =============================================================================
# Registry UI Container
# =============================================================================
resource "docker_container" "registry_ui" {
  count = var.harbor_enabled ? 0 : (var.registry_ui_enabled ? 1 : 0)

  name  = "${var.registry_name}-ui"
  image = "joxit/docker-registry-ui:latest"

  restart = "unless-stopped"

  ports {
    internal = 80
    external = var.registry_ui_port
    protocol = "tcp"
  }

  env = [
    "REGISTRY_TITLE=AGL Docker Registry",
    "REGISTRY_URL=http://${var.registry_name}:5000",
    "DELETE_IMAGES=${var.registry_delete_enabled}",
    "SHOW_CONTENT_DIGEST=true",
    "NO_SSL_VERIFY=${var.registry_tls_enabled ? "false" : "true"}",
  ]

  networks_advanced {
    name = docker_network.registry.name
  }

  labels = merge(local.registry_labels, {
    "com.aglhostman.component" = "docker-registry-ui"
  })

  depends_on = [
    docker_container.registry
  ]
}

# =============================================================================
# Harbor Registry (alternative)
# =============================================================================
resource "docker_container" "harbor_core" {
  count = var.harbor_enabled ? 1 : 0

  name  = "harbor-core"
  image = "goharbor/harbor-core:${var.harbor_version}"

  restart = "unless-stopped"

  ports {
    internal = 80
    external = 80
    protocol = "tcp"
  }

  ports {
    internal = 443
    external = 443
    protocol = "tcp"
  }

  env = [
    "CORE_URL=http://127.0.0.1:8080",
    "DATABASE_HOST=harbor-db",
    "DATABASE_PASSWORD=${var.harbor_database_password}",
    "REGISTRY_URL=http://harbor-registry:5000",
    "HARBOR_ADMIN_PASSWORD=${var.harbor_admin_password}",
  ]

  networks_advanced {
    name = docker_network.registry.name
  }

  labels = merge(local.registry_labels, {
    "com.aglhostman.component" = "harbor-registry"
  })
}

# =============================================================================
# Nginx Reverse Proxy (optional)
# =============================================================================
resource "docker_container" "nginx_proxy" {
  count = var.harbor_enabled && var.harbor_enabled ? 1 : 0

  name  = "${var.registry_name}-proxy"
  image = "nginx:alpine"

  restart = "unless-stopped"

  ports {
    internal = 443
    external = 443
    protocol = "tcp"
  }

  ports {
    internal = 80
    external = 80
    protocol = "tcp"
  }

  volumes {
    host_path       = "${path.module}/nginx.conf"
    container_path = "/etc/nginx/nginx.conf"
    read_only      = true
  }

  networks_advanced {
    name = docker_network.registry.name
  }

  labels = merge(local.registry_labels, {
    "com.aglhostman.component" = "nginx-proxy"
  })
}
