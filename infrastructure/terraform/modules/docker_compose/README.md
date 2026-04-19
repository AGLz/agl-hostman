# Docker Compose Module

Terraform module for managing Docker Compose stacks.

## Usage

### From Compose File

```hcl
module "monitoring" {
  source = "./modules/docker_compose"

  project_name = "monitoring"
  compose_file = "${path.module}/docker-compose.yml"

  environment_files = [
    "${path.module}/.env"
  ]
}
```

### Inline Service Definition

```hcl
module "app_stack" {
  source = "./modules/docker_compose"

  project_name = "my-app"
  networks = {
    app_network = {
      driver = "bridge"
    }
  }
  volumes = {
    app_data = {
      driver = "local"
    }
  }
  services = {
    web = {
      image = "nginx:alpine"
      ports = [
        { internal = 80, external = 80, protocol = "tcp" }
      ]
      networks = ["app_network"]
    }
    app = {
      image = "myapp:latest"
      environment = {
        NODE_ENV = "production"
      }
      networks = ["app_network"]
      depends_on = ["web"]
    }
  }
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
| compose_file | Path to docker-compose.yml | `string` | `null` | no |
| compose_definition | Inline compose YAML | `string` | `null` | no |
| project_name | Project name | `string` | n/a | yes |
| services | Service definitions | `map(object)` | `{}` | no |
| networks | Network definitions | `map(object)` | `{}` | no |
| volumes | Volume definitions | `map(object)` | `{}` | no |
| environment_files | Environment files | `list(string)` | `[]` | no |
| pull_images_first | Pull images before starting | `bool` | `true` | no |
| remove_orphans | Remove orphaned containers | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| project_name | Compose project name |
| services | List of service names |
| networks | Created networks |
| volumes | Created volumes |
| containers | Container information |

## Examples

### Monitoring Stack

```hcl
module "monitoring" {
  source = "./modules/docker_compose"

  project_name = "monitoring"
  compose_file = "${path.module}/docker-compose.monitoring.yml"

  environment_files = [
    "${path.module}/.env.monitoring"
  ]

  pull_images_first = true
}
```

With `docker-compose.monitoring.yml`:

```yaml
version: "3.8"

services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin

volumes:
  prometheus_data:
  grafana_data:
```

### Full Stack Application

```hcl
module "full_stack" {
  source = "./modules/docker_compose"

  project_name = "full-stack"

  networks = {
    frontend = { driver = "bridge" }
    backend  = { driver = "bridge" }
  }

  volumes = {
    db_data    = { driver = "local" }
    app_logs   = { driver = "local" }
  }

  services = {
    nginx = {
      image = "nginx:alpine"
      ports = [{ internal = 80, external = 80, protocol = "tcp" }]
      networks = ["frontend"]
      depends_on = ["app"]
    }

    app = {
      image = "myapp:latest"
      environment = {
        DB_HOST = "postgres"
        REDIS_HOST = "redis"
      }
      networks = ["frontend", "backend"]
    }

    postgres = {
      image = "postgres:15"
      environment = {
        POSTGRES_DB = "appdb"
        POSTGRES_PASSWORD = "secret"
      }
      volumes = [{
        host_path = "/data/postgres"
        container_path = "/var/lib/postgresql/data"
      }]
      networks = ["backend"]
    }

    redis = {
      image = "redis:alpine"
      networks = ["backend"]
    }
  }
}
```

## License

MIT
