# Docker Service Module

Terraform module for managing individual Docker containers with advanced features.

## Usage

### Basic Example

```hcl
module "nginx" {
  source = "./modules/docker_service"

  service_name = "nginx"
  image        = "nginx"
  image_tag    = "alpine"

  ports = [
    {
      internal = 80
      external = 8080
      protocol = "tcp"
    }
  ]
}
```

### Advanced Example

```hcl
module "app" {
  source = "./modules/docker_service"

  service_name = "my-app"
  image        = "myregistry/my-app"
  image_tag    = "v1.0.0"

  restart_policy = "unless-stopped"

  ports = [
    {
      internal = 8080
      external = 80
      protocol = "tcp"
      ip       = "0.0.0.0"
    }
  ]

  volumes = [
    {
      host_path      = "/data/config"
      container_path = "/app/config"
      mode          = "ro"
    },
    {
      host_path      = "/data/logs"
      container_path = "/app/logs"
      mode          = "rw"
    }
  ]

  environment = {
    APP_ENV  = "production"
    LOG_LEVEL = "info"
  }

  deploy_resources = {
    limits = {
      cpus   = "2.0"
      memory = "4g"
    }
    reservations = {
      cpus   = "0.5"
      memory = "512m"
    }
  }

  healthcheck = {
    command     = ["CMD", "curl", "-f", "http://localhost:8080/health"]
    interval    = "30s"
    timeout     = "5s"
    retries     = 3
    start_period = "10s"
  }

  labels = {
    "com.aglhostman.tier"   = "backend"
    "com.aglhostman.version" = "1.0.0"
  }
}
```

### Privileged Container

```hcl
module "portainer" {
  source = "./modules/docker_service"

  service_name = "portainer"
  image        = "portainer/portainer-ce"

  ports = [
    {
      internal = 9000
      external = 9000
      protocol = "tcp"
    }
  ]

  volumes = [
    {
      host_path      = "/var/run/docker.sock"
      container_path = "/var/run/docker.sock"
    },
    {
      host_path      = "/data/portainer"
      container_path = "/data"
    }
  ]

  host_docker_socket = true
  privileged         = false
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| docker | >= 3.0.0 |

## Providers

| Name | Version |
|------|---------|
| docker | >= 3.0.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| service_name | Name of the Docker service | `string` | n/a | yes |
| container_name | Container name | `string` | `null` | no |
| image | Docker image to run | `string` | n/a | yes |
| image_tag | Docker image tag | `string` | `"latest"` | no |
| restart_policy | Container restart policy | `string` | `"unless-stopped"` | no |
| ports | Port mappings | `list(object)` | `[]` | no |
| volumes | Volume mounts | `list(object)` | `[]` | no |
| environment | Environment variables | `map(string)` | `{}` | no |
| networks | Networks to attach to | `list(string)` | `["bridge"]` | no |
| deploy_resources | Resource limits | `object` | `null` | no |
| healthcheck | Health check configuration | `object` | `null` | no |
| labels | Container labels | `map(string)` | `{}` | no |
| privileged | Run in privileged mode | `bool` | `false` | no |
| host_docker_socket | Mount Docker socket | `bool` | `false` | no |
| enable_swarm | Deploy as Swarm service | `bool` | `false` | no |
| swarm_replicas | Number of replicas | `number` | `1` | no |

## Outputs

| Name | Description |
|------|-------------|
| container_name | Container name |
| container_id | Container ID |
| ip_address | Container IP address |
| service_name | Service name |
| ports | Published ports |
| health_status | Container health status |

## Examples

### Web Application

```hcl
module "web" {
  source = "./modules/docker_service"

  service_name = "web-app"
  image        = "nginx"
  image_tag    = "alpine"

  ports = [
    { internal = 80, external = 80, protocol = "tcp" },
    { internal = 443, external = 443, protocol = "tcp" }
  ]

  volumes = [
    {
      host_path      = "/data/nginx/html"
      container_path = "/usr/share/nginx/html"
      mode          = "ro"
    }
  ]

  labels = {
    "com.aglhostman.tier" = "frontend"
  }
}
```

### Database Service

```hcl
module "postgres" {
  source = "./modules/docker_service"

  service_name = "postgres"
  image        = "postgres"
  image_tag    = "15"

  ports = [
    { internal = 5432, external = 5432, protocol = "tcp" }
  ]

  environment = {
    POSTGRES_DB       = "appdb"
    POSTGRES_USER     = "appuser"
    POSTGRES_PASSWORD = "changeme"
  }

  volumes = [
    {
      host_path      = "/data/postgres"
      container_path = "/var/lib/postgresql/data"
    }
  ]

  deploy_resources = {
    limits = {
      cpus   = "2.0"
      memory = "4g"
    }
  }
}
```

### Redis with Persistence

```hcl
module "redis" {
  source = "./modules/docker_service"

  service_name = "redis"
  image        = "redis"
  image_tag    = "alpine"

  ports = [
    { internal = 6379, external = 6379, protocol = "tcp" }
  ]

  volumes = [
    {
      host_path      = "/data/redis"
      container_path = "/data"
    }
  ]

  command = ["redis-server", "--appendonly", "yes"]

  labels = {
    "com.aglhostman.tier" = "data"
  }
}
```

## Development

### Pre-commit

```bash
terraform fmt
terraform validate
```

### Testing

```bash
terraform init
terraform plan
```

## License

MIT
