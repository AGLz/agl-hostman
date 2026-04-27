# AGL Hostman Infrastructure as Code

Complete Infrastructure as Code (IaC) solution for AGL Hostman using Terraform and Ansible.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Terraform Modules](#terraform-modules)
- [Ansible Playbooks](#ansible-playbooks)
- [CI/CD Integration](#cicd-integration)
- [Drift Detection](#drift-detection)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Overview

This IaC implementation provides:

- **Terraform modules** for Proxmox VM, LXC container, network, and storage provisioning
- **Ansible playbooks** for system configuration, Docker setup, and monitoring deployment
- **CI/CD workflows** for automated testing and deployment
- **Drift detection** to identify and remedify configuration changes
- **Version control** for all infrastructure changes
- **Reproducible deployments** across environments

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Developer/Operator                      │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                    GitHub Repository                        │
│  ┌────────────┐  ┌──────────────┐  ┌────────────────────┐  │
│  │   Terraform│  │    Ansible   │  │   Workflows        │  │
│  │   Modules  │  │   Playbooks  │  │   (CI/CD)          │  │
│  └────────────┘  └──────────────┘  └────────────────────┘  │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                  Proxmox VE Cluster                          │
│  ┌────────────┐  ┌──────────────┐  ┌────────────────────┐  │
│  │  AGLSRV1   │  │   AGLSRV6    │  │  Storage (NFS/ZFS) │  │
│  │  (Primary) │  │  (Secondary) │  │                    │  │
│  └────────────┘  └──────────────┘  └────────────────────┘  │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              VMs & LXC Containers                    │   │
│  │  • Harbor Registry (CT182)                           │   │
│  │  • Dokploy Platform (CT180)                           │   │
│  │  • Application Servers (CT179, CT184, CT185)          │   │
│  │  • Monitoring Stack (CT108)                          │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Quick Start

### Prerequisites

- Terraform >= 1.5.0
- Ansible >= 2.15.0
- Proxmox VE >= 8.0
- Python >= 3.11
- AWS CLI (for state backend)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/agl-hostman/infrastructure.git
   cd infrastructure
   ```

2. **Configure Proxmox API credentials:**
   ```bash
   export PROXMOX_TOKEN_ID="root@pam!terraform"
   export PROXMOX_TOKEN_SECRET="your-token-here"
   ```

3. **Initialize Terraform:**
   ```bash
   make init ENV=dev
   ```

4. **Plan infrastructure changes:**
   ```bash
   make plan ENV=dev
   ```

5. **Apply changes:**
   ```bash
   make apply ENV=dev
   ```

### Using the Makefile

The Makefile provides convenient targets for common operations:

```bash
# Show all available commands
make help

# Terraform operations
make validate        # Validate Terraform configuration
make fmt            # Format Terraform files
make plan ENV=dev   # Generate execution plan
make apply ENV=dev  # Apply changes

# Ansible operations
make ansible-init      # Initialize Ansible inventory
make ansible-run-all   # Run all Ansible playbooks

# Drift detection
make drift-check   # Check for infrastructure drift
make drift-fix ENV=dev   # Fix detected drift
```

## Terraform Modules

### Proxmox VM Module (`modules/proxmox_vm`)

Creates QEMU virtual machines on Proxmox VE.

**Key Features:**
- Cloud-init support
- Multiple disk configurations
- Network interface management
- High availability setup
- Ansible integration

**Example Usage:**
```hcl
module "web_server" {
  source = "../../modules/proxmox_vm"

  vm_name   = "web-server"
  vm_id     = 100
  node_name = "AGLSRV1"

  cpu_cores = 2
  memory_gb = 4

  disks = [
    {
      type         = "scsi0"
      storage      = "local-lvm"
      size_gb      = 32
      interface    = "scsi"
    }
  ]

  cloud_init = {
    enabled     = true
    user        = "ubuntu"
    ssh_keys    = ["ssh-rsa AAAAB3..."]
    ipconfig0   = "ip=192.168.0.100/24,gw=192.168.0.1"
  }

  ansible_playbook = "../../ansible/playbooks/web-server.yml"
}
```

### Proxmox LXC Container Module (`modules/proxmox_lxc`)

Creates LXC containers for lightweight virtualization.

**Key Features:**
- Unprivileged containers (more secure)
- Nesting support (Docker-in-LXC)
- Mount point configuration
- Container templates

**Example Usage:**
```hcl
module "app_container" {
  source = "../../modules/proxmox_lxc"

  container_name = "app-server"
  container_id   = 179
  node_name      = "AGLSRV1"

  cpu_cores  = 4
  memory_mb  = 8192

  template = {
    storage        = "local-lvm"
    template_file = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
  }

  features = {
    nesting = true  # Enable Docker-in-LXC
    keyctl  = true
  }

  unprivileged = true
}
```

### Proxmox Network Module (`modules/proxmox_network`)

Configures network bridges and bonding.

**Example Usage:**
```hcl
module "vmbr0" {
  source = "../../modules/proxmox_network"

  network_name = "lan-network"
  bridge_name  = "vmbr0"
  node_name    = "AGLSRV1"

  bridge_address = "192.168.0.245"
  bridge_netmask = "24"
  bridge_gateway = "192.168.0.1"

  bridge_ports = ["eno1", "eno2"]
  bond_mode    = "802.3ad"  # LACP

  vlan_aware = true
}
```

### Proxmox Storage Module (`modules/proxmox_storage`)

Configures various storage backends (LVM, NFS, Ceph, ZFS, PBS).

**Example Usage:**
```hcl
module "nfs_storage" {
  source = "../../modules/proxmox_storage"

  storage_name = "nfs-storage"
  node_name    = "AGLSRV1"
  storage_type = "nfs"

  nfs_server  = "192.168.0.250"
  nfs_export  = "/mnt/agl-storage"
  content_types = ["images", "backup", "iso"]

  storage_shared = true
  max_files     = 14

  storage_prune = {
    keep_daily   = 7
    keep_weekly  = 4
    keep_monthly = 3
  }
}
```

## Ansible Playbooks

### Available Playbooks

| Playbook | Description |
|----------|-------------|
| `common.yml` | Base system configuration and security hardening |
| `docker-setup.yml` | Docker and Docker Compose installation |
| `monitoring-setup.yml` | Prometheus, Grafana, Alertmanager deployment |

### Running Playbooks

```bash
# Update inventory from Terraform outputs
make ansible-init ENV=production

# Run specific playbook
ansible-playbook -i inventory/hosts.ini playbooks/common.yml

# Run all playbooks
make ansible-run-all
```

### Inventory Structure

```ini
[proxmox_nodes]
aglsrv1 ansible_host=192.168.0.245
aglsrv6 ansible_host=192.168.0.246

[docker_hosts]
agldv03 ansible_host=10.6.0.11

[monitoring_servers]
agldv06 ansible_host=10.6.0.16
```

## CI/CD Integration

### GitHub Actions Workflows

#### Plan Workflow (`.github/workflows/infrastructure-plan.yml`)

Triggered on pull requests:
- Runs `terraform validate`
- Generates `terraform plan`
- Comments PR with plan output
- Runs Ansible syntax checks
- Scans for security issues

#### Apply Workflow (`.github/workflows/infrastructure-apply.yml`)

Triggered on push to `main`:
- Applies Terraform changes
- Updates Ansible inventory
- Runs configuration playbooks
- Generates deployment summary

#### Drift Detection (Scheduled)

Runs daily to detect configuration drift:
- Compares actual state vs Terraform state
- Creates GitHub issues on drift detection
- Optionally triggers auto-remediation

### Pull Request Process

1. Create feature branch
2. Make infrastructure changes
3. Create pull request
4. Review automated plan output
5. Merge to `main` after approval
6. Changes automatically applied to production

## Drift Detection

### What is Drift?

Drift occurs when actual infrastructure differs from Terraform state due to:
- Manual changes via Proxmox web UI
- Direct SSH access modifications
- External configuration management tools
- API-based changes

### Detection

Run drift detection manually:

```bash
# Check all environments
make drift-check

# Check specific environment
ENV=production make drift-check
```

### Remediation

```bash
# Review and fix drift interactively
make drift-fix ENV=production

# Auto-apply fixes
make drift-auto-fix ENV=production
```

### Alerts

Drift detection can send alerts via:
- Slack webhooks
- Email notifications
- GitHub issues
- PagerDuty integration

## Best Practices

### 1. Version Control

- **Never** manually modify Terraform state
- Always commit Terraform and Ansible changes together
- Use semantic versioning for infrastructure releases
- Tag releases for production deployments

### 2. State Management

- Use remote state backend (S3/Azure Storage)
- Enable state locking
- Backup state before major changes
- Use workspaces for environment isolation

### 3. Module Design

- Keep modules under 500 lines
- Use reusable components
- Document all variables and outputs
- Include examples in module README

### 4. Security

- Never commit secrets to version control
- Use environment variables for sensitive data
- Rotate API tokens regularly
- Enable Proxmox firewall on all VMs/containers
- Use unprivileged containers when possible

### 5. Testing

- Validate configuration before applying
- Test changes in dev environment first
- Use `terraform plan` to review changes
- Keep playbooks idempotent

### 6. Monitoring

- Enable metrics collection on all resources
- Set up alerting for critical services
- Monitor Terraform apply duration
- Track drift detection results

## Troubleshooting

### Common Issues

#### Terraform Init Fails

```bash
# Check backend configuration
cat infrastructure/terraform/environments/production/backend.tf

# Verify AWS credentials
aws s3 ls

# Reinitialize with debug output
TF_LOG=DEBUG terraform init
```

#### Plan Shows Unexpected Changes

```bash
# Refresh state to match actual infrastructure
terraform refresh

# Check for manual changes
terraform show

# Import manually created resources
terraform import module.vms.proxmox_vm_qemu.this 100
```

#### Apply Fails with Lock Error

```bash
# Force unlock (risky - ensure no one else is applying)
terraform force-unlock <LOCK_ID>

# Or wait for automatic timeout (usually 15 minutes)
```

#### Ansible Playbook Fails

```bash
# Check syntax
ansible-playbook --syntax-check playbooks/common.yml

# Run with verbose output
ansible-playbook -vvv playbooks/common.yml

# Check connectivity
ansible all -m ping

# Verify Python interpreter
ansible all -m setup | grep ansible_python
```

#### Drift Detection False Positives

Some resources are expected to change:
- Container dynamic IPs (use DHCP reservations)
- Auto-scaling group sizes
- Load balancer health statuses

Add these to `.terraformignore` or use `lifecycle` blocks:

```hcl
lifecycle {
  ignore_changes = [
    # Ignore dynamic IP changes
    network_interfaces[0].ip_address
  ]
}
```

### Getting Help

1. Check logs: `/var/log/agl/`
2. Review Terraform state: `terraform show`
3. Verify Proxmox API access: `curl -k https://proxmox:8006/api2/json/version`
4. Consult documentation: `docs/`
5. Create GitHub issue with detailed error message

## Additional Resources

- [Proxmox VE Documentation](https://pve.proxmox.com/wiki/Main_Page)
- [Terraform Provider Documentation](https://registry.terraform.io/providers/telmate/proxmox/latest/docs)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [AGL Infrastructure Standards](../docs/standards/infrastructure.md)

## License

MIT

## Contributing

1. Fork the repository
2. Create feature branch
3. Make changes with tests
4. Submit pull request

---

**Last Updated:** 2026-02-08
**Maintained By:** AGL Infrastructure Team
