# Terraform Infrastructure - AGL Hostman

Complete Infrastructure as Code (IaC) solution for AGL Hostman using Terraform and Proxmox VE.

## Overview

This Terraform configuration manages:
- Proxmox VMs and LXC containers
- Docker services and registries
- High availability infrastructure (HAProxy, MySQL, Redis)
- Network configuration and storage
- State management (S3, AzureRM)

## Quick Start

```bash
# Initialize Terraform
terraform init

# Plan infrastructure changes
terraform plan -out=tfplan

# Apply changes
terraform apply tfplan

# Destroy infrastructure
terraform destroy
```

## Module Structure

```
infrastructure/terraform/
├── backends/              # State backend configurations
│   ├── s3.tf             # AWS S3 backend
│   ├── azurerm.tf         # Azure Storage backend
│   └── variables.tf       # Backend variables
├── environments/          # Environment-specific configs
│   ├── development/
│   ├── staging/
│   └── production/
├── examples/              # Usage examples
│   ├── simple-vm.tf
│   ├── docker-container.tf
│   └── monitoring-stack.tf
└── modules/               # Reusable modules
    ├── proxmox_vm/        # QEMU virtual machines
    ├── proxmox_lxc/       # LXC containers
    ├── proxmox_network/   # Network configuration
    ├── proxmox_storage/   # Storage backends
    ├── docker_service/     # Single Docker containers
    ├── docker_compose/     # Docker Compose stacks
    ├── docker_registry/    # Container registries
    ├── ha_load_balancer/  # HAProxy services
    └── ha_database/       # MySQL replication
```

## Modules

### Proxmox VM Module

Creates and manages QEMU virtual machines.

```hcl
module "web_server" {
  source = "./modules/proxmox_vm"

  vm_name    = "web-server"
  vm_id      = 100
  node_name  = "AGLSRV1"

  cpu_cores = 2
  memory_gb = 4

  disks = [
    {
      type    = "scsi0"
      storage = "local-lvm"
      size_gb = 50
    }
  ]

  network_interfaces = [
    {
      model  = "virtio"
      bridge = "vmbr0"
    }
  ]
}
```

### Proxmox LXC Module

Creates and manages LXC containers.

```hcl
module "app_container" {
  source = "./modules/proxmox_lxc"

  container_name = "app-server"
  container_id   = 101
  node_name      = "AGLSRV1"

  cpu_cores  = 2
  memory_mb = 2048

  features = {
    nesting = true  # Enable Docker-in-LXC
  }
}
```

### Docker Service Module

Manages individual Docker containers.

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

### Docker Compose Module

Manages multi-container applications with Docker Compose.

```hcl
module "monitoring" {
  source = "./modules/docker_compose"

  project_name = "monitoring"
  compose_file = "${path.module}/docker-compose.monitoring.yml"
}
```

### Docker Registry Module

Deploys container registry (simple or Harbor).

```hcl
module "registry" {
  source = "./modules/docker_registry"

  registry_name     = "agl-registry"
  registry_port     = 5000
  registry_ui_port  = 8080
  registry_ui_enabled = true
}
```

## State Backends

### S3 Backend (AWS)

```hcl
terraform {
  backend "s3" {
    bucket         = "agl-terraform-state"
    key            = "infrastructure/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

### AzureRM Backend

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "agl-infrastructure"
    storage_account_name = "aglterraformstate"
    container_name       = "terraform-state"
    key                  = "infrastructure/terraform.tfstate"
  }
}
```

## Configuration

### Environment Variables

Create a `terraform.tfvars` file:

```hcl
environment = "production"
project_name = "agl-hostman"

# Proxmox Configuration
proxmox_api_url        = "https://proxmox.example.com:8006/api2/json"
proxmox_api_token_id   = "terraform@pve"
proxmox_api_token_secret = "your-token-here"

# Network Configuration
network_config = {
  bridge         = "vmbr0"
  gateway        = "192.168.0.1"
  dns_servers    = ["192.168.0.1", "8.8.8.8"]
  search_domains = ["agl.local"]
}

# Storage Configuration
storage_config = {
  local-lvm = {
    type    = "lvm"
    storage = "local-lvm"
    content = ["images", "rootdir"]
  }
}
```

### Secrets Management

Store sensitive values in environment variables or secret managers:

```bash
export PM_API_URL="https://proxmox.example.com:8006/api2/json"
export PM_API_TOKEN_ID="terraform@pve"
export PM_API_TOKEN_SECRET="your-secret-token"
```

## Workspaces

Use Terraform workspaces for multiple environments:

```bash
# Create workspace
terraform workspace new production

# List workspaces
terraform workspace list

# Switch workspace
terraform workspace select staging
```

## CI/CD Integration

See `.github/workflows/` for CI/CD examples.

### GitHub Actions

```yaml
name: Terraform Apply

on:
  push:
    branches: [main]

jobs:
  apply:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: hashicorp/setup-terraform@v2
      - run: terraform init
      - run: terraform plan -out=tfplan
      - run: terraform apply tfplan
```

## Outputs

After deployment, view important outputs:

```bash
terraform output
```

Common outputs:
- `vm_ips`: IP addresses of created VMs
- `container_ips`: IP addresses of LXC containers
- `service_urls`: URLs for deployed services

## State Management

### Backing Up State

```bash
# Backup current state
terraform output -state=terraform.tfstate.backup > state-backup.json

# Copy to backup location
cp terraform.tfstate /backup/location/
```

### State Drift Detection

```bash
# Refresh state
terraform refresh

# Check for drift
terraform plan -detailed-exitcode
```

### Importing Existing Resources

```bash
# Import existing VM
terraform import proxmox_vm_qemu.this 100

# Import existing container
terraform import proxmox_lxc.this 101
```

## Troubleshooting

### Common Issues

1. **API Authentication Error**
   ```bash
   # Verify token
   echo $PM_API_TOKEN_ID
   echo $PM_API_TOKEN_SECRET
   ```

2. **State Lock Error**
   ```bash
   # Force unlock (caution!)
   terraform force-unlock <LOCK_ID>
   ```

3. **Module Not Found**
   ```bash
   # Run from correct directory
   cd infrastructure/terraform
   terraform init
   ```

### Debug Mode

```bash
# Enable detailed logging
export TF_LOG=DEBUG
export TF_LOG_PATH=./terraform.log

# Run Terraform
terraform plan
```

## Best Practices

1. **Always review plans before applying**
   ```bash
   terraform plan -out=tfplan
   terraform show -json tfplan | jq .
   ```

2. **Use separate workspaces for environments**
   - `development`
   - `staging`
   - `production`

3. **Tag resources appropriately**
   ```hcl
   tags = ["terraform-managed", "production", "web"]
   ```

4. **Lock provider versions**
   ```hcl
   terraform {
     required_providers {
       proxmox = {
         source  = "telmate/proxmox"
         version = ">= 3.0.1-rc4"
       }
     }
   }
   ```

5. **Enable state encryption**
   ```hcl
   backend "s3" {
     encrypt = true
   }
   ```

## Contributing

1. Create feature branch
2. Make changes
3. Run `terraform fmt`
4. Run `terraform validate`
5. Submit pull request

## License

MIT License - see LICENSE file for details

## Support

- Documentation: `/docs/infrastructure/`
- Issues: GitHub Issues
- Slack: #agl-infrastructure
