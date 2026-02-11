# Docker Registry Module

Terraform module for deploying Docker registry (simple or Harbor).

## Usage

### Simple Registry

```hcl
module "registry" {
  source = "./modules/docker_registry"

  registry_name    = "agl-registry"
  registry_port    = 5000
  registry_ui_port = 8080
  registry_ui_enabled = true
}
```

### Harbor Registry

```hcl
module "harbor" {
  source = "./modules/docker_registry"

  harbor_enabled = true
  harbor_version = "v2.10.0"
  harbor_admin_password = "changeme"
}
```

### S3 Storage Backend

```hcl
module "registry" {
  source = "./modules/docker_registry"

  registry_name = "agl-registry"
  registry_port = 5000

  registry_storage_driver = "s3"
  registry_s3_config = {
    bucket    = "my-docker-registry"
    region    = "us-east-1"
    accesskey = "AKIAIOSFODNN7EXAMPLE"
    secretkey = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| docker | >= 3.0.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| registry_name | Registry name | `string` | `"docker-registry"` | no |
| registry_port | Registry API port | `number` | `5000` | no |
| registry_ui_port | UI port | `number` | `8080` | no |
| registry_ui_enabled | Deploy UI | `bool` | `true` | no |
| registry_auth_enabled | Enable auth | `bool` | `false` | no |
| registry_tls_enabled | Enable TLS | `bool` | `false` | no |
| registry_storage_driver | Storage backend | `string` | `"filesystem"` | no |
| registry_s3_config | S3 configuration | `object` | `null` | no |
| harbor_enabled | Use Harbor | `bool` | `false` | no |
| harbor_version | Harbor version | `string` | `"v2.10.0"` | no |
| harbor_admin_password | Harbor admin password | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| registry_url | Registry URL |
| registry_host | Registry hostname |
| registry_port | Registry port |
| ui_url | Registry UI URL |
| data_volume | Data volume name |
| network_name | Network name |

## Examples

### Production Registry

```hcl
module "production_registry" {
  source = "./modules/docker_registry"

  registry_name     = "agl-registry"
  registry_port     = 5000
  registry_ui_port  = 8080
  registry_ui_enabled = true

  registry_auth_enabled = true
  registry_auth_htpasswd = "/auth/htpasswd"

  registry_tls_enabled = true
  registry_tls_cert_path = "/certs/tls.crt"
  registry_tls_key_path = "/certs/tls.key"

  registry_storage_driver = "filesystem"
  registry_data_dir = "/var/lib/registry"

  registry_delete_enabled = true
  registry_log_level = "info"
}
```

### Harbor Registry

```hcl
module "harbor" {
  source = "./modules/docker_registry"

  harbor_enabled = true
  harbor_version = "v2.10.0"

  harbor_admin_password = var.harbor_password
  harbor_database_password = var.harbor_db_password
}
```

## License

MIT
