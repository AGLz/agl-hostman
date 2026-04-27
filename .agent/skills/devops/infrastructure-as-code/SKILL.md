---
name: infrastructure-as-code
description: "Infrastructure as Code using Terraform and Ansible for version-controlled, reproducible infrastructure provisioning with drift detection and state management. Use when automating infrastructure, ensuring consistency, or implementing GitOps."
category: devops
priority: P2
tags: [terraform, ansible, iac, gitops, automation]
---

# Infrastructure as Code (IaC) Skill

## Overview

Infrastructure as Code (IaC) treats infrastructure configuration as software, enabling version control, reproducibility, and automation of infrastructure provisioning and management.

**Core Principles:**
- **Declarative**: Define desired state, not imperative steps
- **Idempotent**: Same operations produce same results
- **Immutable**: Replace rather than modify in-place
- **Versioned**: All changes tracked in git
- **Testable**: Validate before production

**When to Use This Skill:**
- Automating cloud resource provisioning
- Ensuring environment consistency
- Implementing GitOps workflows
- Managing configuration drift
- Scaling infrastructure rapidly

## Terraform

### Core Concepts

**Configuration Files:**
```hcl
# main.tf - Provider configuration
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "tf-state-prod"
    key            = "infra/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "tf-locks-prod"
  }
}

provider "aws" {
  region = var.aws_region
}

# variables.tf - Input parameters
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

# outputs.tf - Output values
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "subnet_ids" {
  description = "Subnet IDs"
  value       = aws_subnet.public[*].id
}
```

**Resource Management:**
```hcl
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.environment}-public-${count.index + 1}"
  }
}
```

**Data Sources:**
```hcl
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "tf-state-prod"
    key    = "network/terraform.tfstate"
    region = "us-east-1"
  }
}
```

## Ansible

### Core Concepts

**Playbook Structure:**
```yaml
---
# site.yml - Main playbook
- name: Configure application servers
  hosts: webservers
  become: true

  vars:
    app_version: "1.0.0"
    app_port: 8080
    deploy_user: "appuser"

  vars_files:
    - vars/secrets.yml
    - vars/{{ environment }}.yml

  pre_tasks:
    - name: Verify system requirements
      assert:
        that:
          - ansible_distribution_version is version('20.04', '>=')
        fail_msg: "Ubuntu 20.04+ required"

  roles:
    - role: geerlingguy.docker
      tags: docker
    - role: geerlingguy.nginx
      tags: nginx
    - role: custom.application
      tags: app

  post_tasks:
    - name: Verify deployment
      uri:
        url: "http://localhost:{{ app_port }}/health"
        status_code: 200
```

**Role Structure:**
```
roles/
└── application/
    ├── defaults/
    │   └── main.yml
    ├── files/
    │   └── app.sh
    ├── handlers/
    │   └── main.yml
    ├── meta/
    │   └── main.yml
    ├── tasks/
    │   └── main.yml
    ├── templates/
    │   └── config.j2
    └── vars/
        └── main.yml
```

**Task Examples:**
```yaml
---
# tasks/main.yml
- name: Create application user
  user:
    name: "{{ deploy_user }}"
    system: true
    shell: /bin/bash
    home: /opt/{{ app_name }}

- name: Install application dependencies
  apt:
    name:
      - python3-pip
      - python3-venv
      - git
    state: present
    update_cache: true

- name: Create application directory
  file:
    path: "{{ app_install_dir }}"
    state: directory
    owner: "{{ deploy_user }}"
    mode: '0755'

- name: Template configuration
  template:
    src: config.j2
    dest: /etc/{{ app_name }}/config.yml
    owner: "{{ deploy_user }}"
    mode: '0640'
  notify: Restart application

- name: Deploy application
  git:
    repo: "{{ app_repository }}"
    dest: "{{ app_install_dir }}"
    version: "{{ app_version }}"
    force: true
  notify:
    - Run migrations
    - Restart application

# handlers/main.yml
- name: Run migrations
  command: python3 manage.py migrate
  args:
    chdir: "{{ app_install_dir }}"
  become_user: "{{ deploy_user }}"

- name: Restart application
  systemd:
    name: "{{ app_name }}"
    state: restarted
    enabled: true
```

**Inventory Management:**
```yaml
# inventory/hosts.yml
all:
  children:
    production:
      hosts:
        prod-web-1:
          ansible_host: 10.0.1.10
          ansible_user: ubuntu
        prod-web-2:
          ansible_host: 10.0.1.11
          ansible_user: ubuntu
      vars:
        environment: production
        app_port: 8080

    staging:
      hosts:
        staging-web-1:
          ansible_host: 10.0.2.10
          ansible_user: ubuntu
      vars:
        environment: staging
        app_port: 8081

# Dynamic inventory with Terraform
plugin: aws_ec2
regions:
  - us-east-1
filters:
  tag:Environment: production
  instance-state-name: running
 keyed_groups:
  - key: tags.Environment
    prefix: env
  - key: tags.Role
    prefix: role
```

## State Management

### Remote State

**Terraform Cloud:**
```hcl
terraform {
  cloud {
    organization = "myorg"
    hostname     = "app.terraform.io"
    workspaces {
      name = "production-infra"
    }
  }
}
```

**S3 Backend:**
```hcl
terraform {
  backend "s3" {
    bucket         = "tf-state-prod"
    key            = "infra/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    kms_key_id     = "arn:aws:kms:...:key/..."
    dynamodb_table = "tf-locks-prod"
  }
}
```

**Azure Storage:**
```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "tf-state-rg"
    storage_account_name = "tfstateprod"
    container_name       = "tfstate"
    key                  = "infra/terraform.tfstate"
  }
}
```

### State Locking

**DynamoDB (AWS):**
```hcl
resource "aws_dynamodb_table" "terraform_locks" {
  name           = "tf-locks-prod"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
```

**Azure Storage Account:**
```bash
# Enable blob versioning and soft delete
az storage account blob-service-properties update \
  --account-name tfstateprod \
  --enable-versioning true
```

### State Management Best Practices

1. **Separate State Files:**
   ```bash
   # One state per component
   network/terraform.tfstate
   compute/terraform.tfstate
   database/terraform.tfstate
   ```

2. **State Migration:**
   ```bash
   # Move state between backends
   terraform init \
     -backend-config="bucket=new-tf-state" \
     -backend-config="key=infra/terraform.tfstate" \
     -backend-config="region=us-east-1" \
     -migrate-state
   ```

3. **State Inspection:**
   ```bash
   # List resources in state
   terraform state list

   # Show resource details
   terraform state show aws_vpc.main

   # Remove resource from state
   terraform state rm aws_instance.old

   # Move resource in state
   terraform state mv aws_instance.old aws_instance.new
   ```

## Module Design

### Module Structure

```
modules/
└── vpc/
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    ├── versions.tf
    └── README.md
```

### Reusable Module

```hcl
# modules/vpc/main.tf
resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(
    {
      Name = var.name
    },
    var.tags
  )
}

resource "aws_subnet" "public" {
  count                   = var.num_public_subnets
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.cidr, 8, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    {
      Name = "${var.name}-public-${count.index}"
    },
    var.tags
  )
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    {
      Name = var.name
    },
    var.tags
  )
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(
    {
      Name = "${var.name}-public"
    },
    var.tags
  )
}

resource "aws_route_table_association" "public" {
  count          = var.num_public_subnets
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# modules/vpc/variables.tf
variable "name" {
  description = "Name of VPC"
  type        = string
}

variable "cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "num_public_subnets" {
  description = "Number of public subnets"
  type        = number
  default     = 2
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}

# modules/vpc/outputs.tf
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.this.id
}
```

### Module Usage

```hcl
# main.tf
module "vpc" {
  source = "../modules/vpc"

  name  = "${var.environment}-vpc"
  cidr  = var.vpc_cidr

  availability_zones = var.availability_zones
  num_public_subnets = length(var.availability_zones)

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id     = module.vpc.public_subnet_ids[0]

  tags = {
    Name = "${var.environment}-web-1"
  }
}
```

## Drift Detection

### Terraform Drift

**Manual Drift Detection:**
```bash
# Refresh state without making changes
terraform refresh

# Plan against current state
terraform plan -refresh-only

# Show drift in output
terraform show -json > current.tfstate
```

**Automated Drift Detection:**
```bash
#!/bin/bash
# Check for infrastructure drift

terraform init -backend-config="bucket=tf-state-prod"

# Refresh state
terraform refresh -lock-timeout=5m

# Plan with refresh-only
terraform plan -refresh-only -out=tfplan

# Parse for changes
if terraform show -json tfplan | jq '.resource_changes[] | select(.change.actions[] != "no-op")' | grep -q .; then
  echo "DRIFT DETECTED!"
  terraform show tfplan
  exit 1
else
  echo "No drift detected"
  exit 0
fi
```

**Scheduled Drift Checks:**
```yaml
# GitHub Actions workflow
name: Infrastructure Drift Check

on:
  schedule:
    - cron: '0 */6 * * *'  # Every 6 hours
  workflow_dispatch:

jobs:
  drift-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.5.0

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Terraform Init
        run: terraform init

      - name: Check Drift
        run: |
          terraform plan -refresh-only -out=tfplan
          terraform show -json tfplan > plan.json

      - name: Parse Drift
        id: drift
        run: |
          DRIFT=$(jq -r '.resource_changes | map(select(.change.actions != ["no-op"])) | length' plan.json)
          echo "drift_count=$DRIFT" >> $GITHUB_OUTPUT

          if [ "$DRIFT" -gt 0 ]; then
            echo "::warning::Infrastructure drift detected: $DRIFT changes"
            jq -r '.resource_changes[] | select(.change.actions != ["no-op"]) | "\(.address): \(.change.actions)"' plan.json
            exit 1
          fi

      - name: Create Issue if Drift
        if: failure()
        uses: actions/github-script@v6
        with:
          script: |
            github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: 'Infrastructure Drift Detected',
              body: `Drift count: ${{ steps.drift.outputs.drift_count }}

              Please review and remediate.`,
              labels: ['drift', 'infrastructure']
            })
```

### Ansible Idempotency

**Check Mode:**
```bash
# Preview changes without making them
ansible-playbook site.yml --check

# Diff mode to show changes
ansible-playbook site.yml --diff

# Verbose output
ansible-playbook site.yml -vv
```

**Idempotent Tasks:**
```yaml
# Always use module-specific idempotency
- name: Install package
  apt:
    name: nginx
    state: present
  # Only runs if nginx not installed

- name: Configure file
  template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
  # Only overwrites if content changed

- name: Start service
  systemd:
    name: nginx
    state: started
    enabled: true
  # Idempotent - no effect if already running
```

## GitOps Workflow

### PR-Based Deployment

**Directory Structure:**
```
infrastructure/
├── environments/
│   ├── dev/
│   │   ├── backend.tfvars
│   │   └── frontend.tfvars
│   ├── staging/
│   │   ├── backend.tfvars
│   │   └── frontend.tfvars
│   └── prod/
│       ├── backend.tfvars
│       └── frontend.tfvars
├── modules/
│   ├── vpc/
│   ├── compute/
│   └── database/
└── scripts/
    └── validate.sh
```

**Workflow:**

1. **Feature Branch:**
   ```bash
   git checkout -b feature/add-database
   ```

2. **Make Changes:**
   ```bash
   # Edit modules/database/main.tf
   # Update environments/prod/backend.tfvars
   ```

3. **Validate:**
   ```bash
   ./scripts/validate.sh
   ```

4. **Commit & PR:**
   ```bash
   git add .
   git commit -m "feat: add RDS database module"
   git push origin feature/add-database
   gh pr create --title "Add RDS database" --body "Implements database requirement"
   ```

5. **Automated Checks:**
   - Terraform format validation
   - Security scanning (tfsec, checkov)
   - Cost estimation (infracost)
   - Policy checks (OPA)

6. **Approval:**
   - Peer review required
   - Automatic plan approval for dev
   - Manual approval for prod

7. **Merge & Deploy:**
   - CI/CD pipeline runs `terraform apply`
   - State updated in remote backend
   - Notification sent on completion

### Branch Protection

```yaml
# .github/branch-protection.yml
rules:
  - name: Production Infrastructure
    pattern: main
    protection:
      required_reviews: 2
      required_status_checks:
        - terraform-format
        - security-scan
        - cost-estimate
      enforce_admins: true
      allow_force_pushes: false
      allow_deletions: false
```

### Environment Promotion

```bash
# Dev → Staging → Prod
terraform apply -target=dev
# Verify dev environment
# Test application functionality

terraform apply -target=staging
# Verify staging environment
# Run integration tests

# Manual approval gate
terraform apply -target=prod
# Production deployed
```

## Testing

### Terraform Testing

**terraform-test:**
```hcl
# tests/unit_test.tftest.hcl
run "vpc_test" {
  command = plan

  module {
    source = "../modules/vpc"
  }

  variables {
    name  = "test-vpc"
    cidr  = "10.0.0.0/16"
    availability_zones = ["us-east-1a", "us-east-1b"]
  }

  assert {
    condition     = aws_vpc.this.enable_dns_hostnames == true
    error_message = "DNS hostnames must be enabled"
  }

  assert {
    condition     = length(aws_subnet.public) == 2
    error_message = "Must create 2 public subnets"
  }
}
```

**terratest:**
```go
package test

import (
  "testing"
  "github.com/gruntwork-io/terratest/modules/terraform"
  "github.com/stretchr/testify/assert"
)

func TestVPCModule(t *testing.T) {
  terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
    TerraformDir: "../modules/vpc",
    Vars: map[string]interface{}{
      "name":  "test-vpc",
      "cidr":  "10.0.0.0/16",
      "availability_zones": []string{"us-east-1a", "us-east-1b"},
    },
  })

  defer terraform.Destroy(t, terraformOptions)

  terraform.InitAndApply(t, terraformOptions)

  vpcID := terraform.Output(t, terraformOptions, "vpc_id")
  assert.NotEmpty(t, vpcID)

  publicSubnets := terraform.OutputList(t, terraformOptions, "public_subnet_ids")
  assert.Equal(t, 2, len(publicSubnets))
}
```

**Integration Testing:**
```bash
#!/bin/bash
# scripts/integration-test.sh

set -e

# Deploy test infrastructure
terraform apply \
  -var="environment=test" \
  -var-file="test.tfvars" \
  -auto-approve

# Wait for resources
sleep 60

# Run tests
pytest tests/integration/test_infrastructure.py

# Cleanup
terraform destroy -auto-approve
```

### Ansible Testing

**Molecule:**
```yaml
# molecule/default/molecule.yml
dependency:
  name: galaxy
driver:
  name: docker
platforms:
  - name: instance
    image: ubuntu:22.04
    pre_build_image: true
provisioner:
  name: ansible
verifier:
  name: ansible
```

```yaml
# molecule/default/verify.yml
---
- name: Verify application deployment
  hosts: all
  tasks:
    - name: Check if app user exists
      user:
        name: appuser
      check_mode: true
      register: app_user
      failed_when: not app_user.changed

    - name: Check if application is running
      systemd:
        name: application
      check_mode: true
      register: app_service
      failed_when: not app_service.changed

    - name: Verify HTTP endpoint
      uri:
        url: http://localhost:8080/health
      register: health
      failed_when: health.status != 200
```

## Security

### Secrets Management

**Terraform Variables:**
```bash
# Never commit secrets
# .gitignore
*.tfvars
!example.tfvars

# Use environment variables
export TF_VAR_db_password=$(pass show db/password)
terraform apply

# Or use variable files from secure locations
terraform apply -var-file="s3://tf-vars-prod/secret.tfvars"
```

**Vault Integration:**
```hcl
# terraform-vault provider
data "vault_generic_secret" "db_creds" {
  path = "secret/database/prod"
}

resource "aws_db_instance" "main" {
  username = data.vault_generic_secret.db_creds.data["username"]
  password = data.vault_generic_secret.db_creds.data["password"]
}
```

**Ansible Vault:**
```bash
# Encrypt secrets file
ansible-vault encrypt group_vars/production/vault.yml

# Edit secrets
ansible-vault edit group_vars/production/vault.yml

# Provide password at runtime
ansible-playbook site.yml --ask-vault-pass

# Or use password file
ansible-playbook site.yml --vault-password-file ~/.vault_pass
```

### Security Scanning

**tfsec:**
```bash
# Scan for security issues
tfsec .

# Exit on errors
tfsec . --no-colour --compact

# Specific checks
tfsec . --check AWS001,AWS002
```

**checkov:**
```bash
# Scan infrastructure
checkov -d . --framework terraform

# SARIF output for GitHub
checkov -d . -o sarif --output-file results.sarif

# Skip checks
checkov -d . --skip-check CKV_AWS_1
```

**OPA Policies:**
```rego
# policies/terraform.rego
package terraform

import rego.v1

deny[msg] {
  resource := input.planned_values.root_module.resources[_]
  resource.type == "aws_s3_bucket"

  not resource.values.versioning[0].enabled
  msg := sprintf("%s: S3 bucket versioning must be enabled", [resource.name])
}

deny[msg] {
  resource := input.planned_values.root_module.resources[_]
  resource.type == "aws_security_group_rule"

  resource.values.cidr_blocks[0] == "0.0.0.0/0"
  msg := sprintf("%s: Open security group rule to 0.0.0.0/0", [resource.name])
}
```

```bash
# Run OPA checks
opa eval -d policies/ -f pretty terraform.plan
```

### Cost Management

**infracost:**
```bash
# Estimate costs
infracost breakdown --path .

# Compare diff
infracost diff --path . --terraform-plan tfplan

# GitHub integration
infracost comment github --path . --repo owner/repo --pull-request 123
```

**Budget Alarms:**
```hcl
resource "aws_budgets_budget" "monthly" {
  name              = "monthly-infra-budget"
  budget_type       = "COST"
  limit_amount      = "1000"
  limit_unit        = "USD"
  time_period_start = "2024-01-01_00:00"

  notification {
    comparison_operator = "GREATER_THAN"
    threshold           = 80
    threshold_type      = "PERCENTAGE"
    notification_type   = "EMAIL"
    subscriber_email_addresses = ["ops@example.com"]
  }
}
```

## Quick Reference

### Essential Commands

**Terraform:**
```bash
# Initialize
terraform init

# Format
terraform fmt

# Validate
terraform validate

# Plan
terraform plan
terraform plan -out=tfplan
terraform plan -var-file="prod.tfvars"

# Apply
terraform apply
terraform apply tfplan
terraform apply -auto-approve

# Destroy
terraform destroy
terraform destroy -target=aws_instance.web

# State
terraform state list
terraform state show aws_vpc.main
terraform state import aws_vpc.main vpc-12345

# Output
terraform output vpc_id
terraform output -json
```

**Ansible:**
```bash
# Run playbook
ansible-playbook site.yml

# With inventory
ansible-playbook site.yml -i inventory/hosts.yml

# Check mode
ansible-playbook site.yml --check --diff

# Limit hosts
ansible-playbook site.yml --limit webservers

# Tags
ansible-playbook site.yml --tags docker,nginx
ansible-playbook site.yml --skip-tags database

# Vault
ansible-vault encrypt secret.yml
ansible-vault decrypt secret.yml
ansible-vault rekey secret.yml
ansible-vault view secret.yml

# Galaxy
ansible-galaxy install geerlingguy.docker
ansible-galaxy init custom_role
```

## Best Practices Summary

1. **Modular Design** - Create reusable, composable modules
2. **Remote State** - Use S3/Azure Storage with DynamoDB/locks
3. **Version Constraints** - Lock provider and Terraform versions
4. **State Isolation** - Separate state files per environment/component
5. **Immutable Resources** - Replace rather than modify in-place
6. **Idempotent Operations** - Ensure safe re-run capability
7. **Secrets Management** - Never commit sensitive data
8. **Security Scanning** - Run tfsec, checkov, OPA in CI/CD
9. **Drift Detection** - Monitor for configuration changes
10. **Cost Awareness** - Estimate and track infrastructure costs
11. **GitOps Workflow** - PR-based deployments with approval gates
12. **Comprehensive Testing** - Unit, integration, and end-to-end tests

## Integration with Other Skills

This skill integrates with:
- **CI/CD Pipeline** - Automated infrastructure validation and deployment
- **Docker** - Container orchestration with Terraform
- **Kubernetes** - Cluster provisioning and management
- **Monitoring** - Infrastructure observability setup
- **Security** - Vulnerability scanning and compliance

## See Also

- [Terraform Documentation](https://developer.hashicorp.com/terraform)
- [Ansible Documentation](https://docs.ansible.com)
- [GitOps Patterns](https://www.weave.works/technologies/gitops/)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
