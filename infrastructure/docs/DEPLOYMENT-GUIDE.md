# Infrastructure Deployment Guide

Complete guide for deploying AGL infrastructure using Terraform and Ansible.

## Prerequisites

### Required Software

- **Terraform** >= 1.5.0
  ```bash
  # Install Terraform
  wget https://releases.hashicorp.com/terraform/1.5.7/terraform_1.5.7_linux_amd64.zip
  unzip terraform_1.5.7_linux_amd64.zip -d /usr/local/bin/
  ```

- **Ansible** >= 2.15.0
  ```bash
  pip install ansible==2.15.0
  ```

- **AWS CLI** (for state backend)
  ```bash
  pip install awscli
  aws configure
  ```

### Required Access

- Proxmox VE API access
- AWS S3 access (for state storage)
- SSH access to Proxmox nodes
- DNS access (for hostname resolution)

## Environment Setup

### 1. Clone Repository

```bash
git clone https://github.com/agl-hostman/infrastructure.git
cd infrastructure
```

### 2. Configure Credentials

Create a `.envrc` file or export environment variables:

```bash
# Proxmox API
export PROXMOX_API_URL="https://192.168.0.245:8006/api2/json"
export PROXMOX_TOKEN_ID="root@pam!terraform"
export PROXMOX_TOKEN_SECRET="your-token-here"

# AWS (for Terraform state)
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

### 3. Create Proxmox API Token

1. Log in to Proxmox web UI
2. Navigate to: Datacenter > Permissions > API Tokens
3. Add API Token:
   - Token ID: `terraform`
   - Realm: `pam`
4. Save the returned token ID and secret

## Deployment Workflow

### Development Environment

```bash
# 1. Initialize Terraform
make init ENV=dev

# 2. Review plan
make plan ENV=dev

# 3. Apply changes
make apply ENV=dev

# 4. Update Ansible inventory
make ansible-init ENV=dev

# 5. Run configuration playbooks
make ansible-run-all
```

### Staging Environment

```bash
# Same steps, different environment
make init ENV=staging
make plan ENV=staging
make apply ENV=staging
make ansible-init ENV=staging
make ansible-run-all
```

### Production Environment

```bash
# Production requires approval
make init ENV=production

# Create GitHub PR for review
# After approval, merge to main branch

# Or apply manually (with caution)
make plan ENV=production
# Review plan output carefully
make apply ENV=production
make ansible-init ENV=production
make ansible-run-all
```

## Module Usage

### Creating a VM

```hcl
module "my_vm" {
  source = "../../modules/proxmox_vm"

  vm_name   = "my-vm"
  vm_id     = 300
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
    enabled   = true
    user      = "ubuntu"
    ssh_keys  = ["ssh-rsa AAAAB3..."]
  }
}
```

### Creating a Container

```hcl
module "my_container" {
  source = "../../modules/proxmox_lxc"

  container_name = "my-container"
  container_id   = 301
  node_name      = "AGLSRV1"

  cpu_cores = 2
  memory_mb = 4096

  template = {
    storage        = "local-lvm"
    template_file = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
  }

  features = {
    nesting = true
  }
}
```

## Troubleshooting

### Terraform Issues

**Error: Failed to query available provider packages**

```bash
# Solution: Update Terraform
terraform init -upgrade
```

**Error: State lock timeout**

```bash
# Check who holds the lock
terraform force-unlock <LOCK_ID>

# Or wait for automatic timeout (15 minutes)
```

**Error: Authentication failed**

```bash
# Verify credentials
echo $PROXMOX_TOKEN_ID
echo $PROXMOX_TOKEN_SECRET

# Test API access
curl -k \
  -H "Authorization: PVEAPIToken=$PROXMOX_TOKEN_ID=$PROXMOX_TOKEN_SECRET" \
  https://192.168.0.245:8006/api2/json/version
```

### Ansible Issues

**Error: SSH connection refused**

```bash
# Verify connectivity
ansible all -m ping

# Check SSH key
ansible-playbook --private-key ~/.ssh/id_rsa playbooks/common.yml
```

**Error: Python not found**

```bash
# Install Python on target
ansible all -m raw -a "apt-get install -y python3"
```

### Proxmox Issues

**Error: Container already exists**

```bash
# Import into Terraform state
terraform import \
  'module.my_container.proxmox_lxc.this' \
  'AGLSRV1:179'
```

**Error: VM ID conflict**

```bash
# Find next available ID
pvesh get /cluster/nextid

# Or specify a different ID in Terraform
vm_id = 301
```

## Rollback Procedure

### Terraform Rollback

```bash
# 1. Check previous state versions
aws s3 ls s3://agl-terraform-state/proxmox-production/

# 2. Download previous state
aws s3 cp \
  s3://agl-terraform-state/proxmox-production/terraform.tfstate.backup \
  infrastructure/terraform/environments/production/terraform.tfstate

# 3. Review and apply previous configuration
terraform plan
terraform apply
```

### Ansible Rollback

```bash
# Check Ansible logs
cat /var/log/agl/ansible.log

# Re-run previous playbook version
git checkout <previous-commit>
ansible-playbook playbooks/common.yml
```

## Monitoring

### Check Infrastructure Status

```bash
# Proxmox cluster status
pvecm status

# VM list
qm list

# Container list
pct list

# Storage status
pvesm status
```

### View Logs

```bash
# Terraform logs
tail -f infrastructure/terraform/environments/production/terraform.log

# Ansible logs
tail -f /var/log/agl/ansible.log

# Proxmox logs
tail -f /var/log/syslog | grep pve
```

## Backup and Recovery

### Backup Procedure

```bash
# 1. Backup Terraform state
make backup

# 2. Snapshot all VMs
for vm in $(qm list | awk '{print $1}' | tail -n +2); do
  qm snapshot $vm "backup-$(date +%Y%m%d)"
done

# 3. Snapshot all containers
for ct in $(pct list | awk '{print $1}' | tail -n +2); do
  pct snapshot $ct "backup-$(date +%Y%m%d)"
done
```

### Recovery Procedure

```bash
# 1. Restore Terraform state
aws s3 cp \
  s3://agl-terraform-state/proxmox-production/terraform.tfstate.backup \
  infrastructure/terraform/environments/production/terraform.tfstate

# 2. Restore VM from snapshot
qmrollback <vmid> <snapshot-name>

# 3. Restore container from snapshot
pct rollback <vmid> <snapshot-name>
```

## Security Checklist

- [ ] Rotate Proxmox API tokens monthly
- [ ] Enable Proxmox firewall on all VMs
- [ ] Use unprivileged containers when possible
- [ ] Enable audit logging
- [ ] Regular security updates
- [ ] Monitor for configuration drift
- [ ] Backup state before major changes
- [ ] Use secrets management for sensitive data
- [ ] Enable 2FA for Proxmox web UI
- [ ] Network segmentation

## Performance Tuning

### Terraform Performance

```bash
# Use parallel operations
export TF_PARALLELISM=10

# Enable detailed logging
TF_LOG=DEBUG terraform apply

# Use local cache
export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"
```

### Ansible Performance

```bash
# Enable pipelining
export ANSIBLE_PIPELINING=True

# Increase forks
export ANSIBLE_FORKS=20

# Use SSH multiplexing
export ANSIBLE_SSH_ARGS="-o ControlMaster=auto -o ControlPersist=60s"
```

## Additional Resources

- [Terraform Documentation](https://www.terraform.io/docs)
- [Ansible Documentation](https://docs.ansible.com)
- [Proxmox VE Documentation](https://pve.proxmox.com/wiki/Main_Page)
- [AGL Infrastructure Wiki](https://wiki.agl.local/infrastructure)

---

For questions or issues, contact the infrastructure team: infrastructure@agl.local
