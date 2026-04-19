# Infrastructure Makefile
# AGL Hostman Infrastructure as Code

.PHONY: help init validate fmt plan apply destroy output lint test clean docs

# Default target
.DEFAULT_GOAL := help

# Variables
ENV ?= dev
TF_DIR := infrastructure/terraform
ANSIBLE_DIR := infrastructure/ansible
ENV_DIR := $(TF_DIR)/environments/$(ENV)

# Colors
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m

##@ General

help: ## Display this help
	@echo "$(BLUE)AGL Hostman Infrastructure Makefile$(NC)"
	@echo ""
	@echo "$(GREEN)Usage:$(NC) make [target]"
	@echo ""
	@echo "$(GREEN)Targets:$(NC)"
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(GREEN)Environment:$(NC) $(ENV) (set with ENV=dev|staging|production)"
	@echo ""

##@ Terraform

init: ## Initialize Terraform configuration
	@echo "$(BLUE)Initializing Terraform for $(ENV) environment...$(NC)"
	cd $(ENV_DIR) && \
	terraform init \
		-backend-config="bucket=agl-terraform-state" \
		-backend-config="key=proxmox-$(ENV)/terraform.tfstate" \
		-backend-config="region=us-east-1"

validate: ## Validate Terraform configuration
	@echo "$(BLUE)Validating Terraform configuration...$(NC)"
	cd $(TF_DIR) && \
	terraform fmt -check -recursive
	cd $(ENV_DIR) && \
	terraform validate

fmt: ## Format Terraform files
	@echo "$(BLUE)Formatting Terraform files...$(NC)"
	cd $(TF_DIR) && \
	terraform fmt -recursive

plan: ## Show Terraform execution plan
	@echo "$(BLUE)Generating Terraform plan for $(ENV)...$(NC)"
	cd $(ENV_DIR) && \
	terraform plan \
		-var="proxmox_api_token_id=$${PROXMOX_TOKEN_ID}" \
		-var="proxmox_api_token_secret=$${PROXMOX_TOKEN_SECRET}"

plan-out: ## Generate Terraform plan and save to file
	@echo "$(BLUE)Generating Terraform plan for $(ENV)...$(NC)"
	cd $(ENV_DIR) && \
	terraform plan \
		-var="proxmox_api_token_id=$${PROXMOX_TOKEN_ID}" \
		-var="proxmox_api_token_secret=$${PROXMOX_TOKEN_SECRET}" \
		-out=tfplan

apply: plan-out ## Apply Terraform changes
	@echo "$(YELLOW)Applying Terraform changes to $(ENV)...$(NC)"
	cd $(ENV_DIR) && \
	terraform apply tfplan

apply-auto: plan-out ## Apply Terraform changes without confirmation
	@echo "$(YELLOW)Applying Terraform changes to $(ENV) (auto-approve)...$(NC)"
	cd $(ENV_DIR) && \
	terraform apply -auto-approve tfplan

destroy: ## Destroy Terraform-managed infrastructure
	@echo "$(RED)Destroying infrastructure in $(ENV)...$(NC)"
	cd $(ENV_DIR) && \
	terraform destroy \
		-var="proxmox_api_token_id=$${PROXMOX_TOKEN_ID}" \
		-var="proxmox_api_token_secret=$${PROXMOX_TOKEN_SECRET}"

destroy-auto: ## Destroy infrastructure without confirmation
	@echo "$(RED)Destroying infrastructure in $(ENV) (auto-approve)...$(NC)"
	cd $(ENV_DIR) && \
	terraform destroy -auto-approve \
		-var="proxmox_api_token_id=$${PROXMOX_TOKEN_ID}" \
		-var="proxmox_api_token_secret=$${PROXMOX_TOKEN_SECRET}"

output: ## Show Terraform outputs
	@echo "$(BLUE)Terraform outputs for $(ENV):$(NC)"
	cd $(ENV_DIR) && \
	terraform output

refresh: ## Refresh Terraform state
	@echo "$(BLUE)Refreshing Terraform state for $(ENV)...$(NC)"
	cd $(ENV_DIR) && \
	terraform refresh \
		-var="proxmox_api_token_id=$${PROXMOX_TOKEN_ID}" \
		-var="proxmox_api_token_secret=$${PROXMOX_TOKEN_SECRET}"

import: ## Import existing infrastructure (usage: make import ADDR=... ID=...)
	@if [ -z "$(ADDR)" ] || [ -z "$(ID)" ]; then \
		echo "$(RED)Error: ADDR and ID are required$(NC)"; \
		echo "Usage: make import ADDR=module.foo.aws_instance.bar ID=i-1234567890"; \
		exit 1; \
	fi
	cd $(ENV_DIR) && \
	terraform import \
		-var="proxmox_api_token_id=$${PROXMOX_TOKEN_ID}" \
		-var="proxmox_api_token_secret=$${PROXMOX_TOKEN_SECRET}" \
		$(ADDR) $(ID)

state-list: ## List all resources in state
	@echo "$(BLUE)Resources in Terraform state for $(ENV):$(NC)"
	cd $(ENV_DIR) && \
	terraform state list

state-rm: ## Remove resource from state (usage: make state-rm ADDR=...)
	@if [ -z "$(ADDR)" ]; then \
		echo "$(RED)Error: ADDR is required$(NC)"; \
		echo "Usage: make state-rm ADDR=module.foo.aws_instance.bar"; \
		exit 1; \
	fi
	cd $(ENV_DIR) && \
	terraform state rm $(ADDR)

taint: ## Mark resource as tainted (usage: make taint ADDR=...)
	@if [ -z "$(ADDR)" ]; then \
		echo "$(RED)Error: ADDR is required$(NC)"; \
		echo "Usage: make taint ADDR=module.foo.aws_instance.bar"; \
		exit 1; \
	fi
	cd $(ENV_DIR) && \
	terraform taint $(ADDR)

untaint: ## Remove tainted status from resource (usage: make untaint ADDR=...)
	@if [ -z "$(ADDR)" ]; then \
		echo "$(RED)Error: ADDR is required$(NC)"; \
		echo "Usage: make untaint ADDR=module.foo.aws_instance.bar"; \
		exit 1; \
	fi
	cd $(ENV_DIR) && \
	terraform untaint $(ADDR)

##@ Ansible

ansible-init: ## Initialize Ansible inventory
	@echo "$(BLUE)Initializing Ansible inventory...$(NC)"
	cd $(ANSIBLE_DIR) && \
	./scripts/update-inventory.sh $(ENV_DIR)/outputs.json

ansible-check: ## Check Ansible playbooks syntax
	@echo "$(BLUE)Checking Ansible playbooks...$(NC)"
	cd $(ANSIBLE_DIR) && \
	for playbook in playbooks/*.yml; do \
		echo "Checking $$playbook"; \
		ansible-playbook --syntax-check "$$playbook"; \
	done

ansible-lint: ## Lint Ansible playbooks
	@echo "$(BLUE)Linting Ansible playbooks...$(NC)"
	cd $(ANSIBLE_DIR) && \
	ansible-lint playbooks/*.yml

ansible-run-common: ## Run common configuration playbook
	@echo "$(BLUE)Running common configuration...$(NC)"
	cd $(ANSIBLE_DIR) && \
	ansible-playbook -i inventory/hosts.ini playbooks/common.yml

ansible-run-docker: ## Run Docker setup playbook
	@echo "$(BLUE)Running Docker setup...$(NC)"
	cd $(ANSIBLE_DIR) && \
	ansible-playbook -i inventory/hosts.ini playbooks/docker-setup.yml

ansible-run-monitoring: ## Run monitoring setup playbook
	@echo "$(BLUE)Running monitoring setup...$(NC)"
	cd $(ANSIBLE_DIR) && \
	ansible-playbook -i inventory/hosts.ini playbooks/monitoring-setup.yml

ansible-run-all: ansible-run-common ansible-run-docker ansible-run-monitoring ## Run all Ansible playbooks

##@ Drift Detection

drift-check: ## Check for infrastructure drift
	@echo "$(BLUE)Checking for infrastructure drift in $(ENV)...$(NC)"
	./infrastructure/scripts/drift-detection.sh

drift-fix: ## Fix detected drift (usage: make drift-fix ENV=production)
	@echo "$(BLUE)Fixing infrastructure drift in $(ENV)...$(NC)"
	./infrastructure/scripts/drift-remediation.sh $(ENV)

drift-auto-fix: ## Fix drift with auto-apply
	@echo "$(BLUE)Auto-fixing infrastructure drift in $(ENV)...$(NC)"
	AUTO_APPLY=true ./infrastructure/scripts/drift-remediation.sh $(ENV)

##@ Testing

test: ## Run all tests
	@echo "$(BLUE)Running infrastructure tests...$(NC)"
	$(MAKE) test-terraform
	$(MAKE) test-ansible

test-terraform: ## Run Terraform tests
	@echo "$(BLUE)Running Terraform tests...$(NC)"
	cd $(TF_DIR) && \
	terraform test

test-ansible: ## Run Ansible tests
	@echo "$(BLUE)Running Ansible tests...$(NC)"
	cd $(ANSIBLE_DIR) && \
	ansible-playbook playbooks/test/*.yml

lint: ## Run all linters
	@echo "$(BLUE)Running linters...$(NC)"
	$(MAKE) fmt
	$(MAKE) validate
	$(MAKE) ansible-check
	$(MAKE) ansible-lint

##@ Documentation

docs: ## Generate infrastructure documentation
	@echo "$(BLUE)Generating infrastructure documentation...$(NC)"
	cd $(TF_DIR) && \
	terraform-docs markdown table --output-file README.md --output-mode inject .

docs-ansible: ## Generate Ansible role documentation
	@echo "$(BLUE)Generating Ansible documentation...$(NC)"
	cd $(ANSIBLE_DIR) && \
	for role in roles/*; do \
		if [ -d "$$role" ]; then \
			echo "Documenting $$role"; \
			ansible-doc -t role "$$role" > "$$role/README.md"; \
		fi \
	done

graph: ## Generate Terraform dependency graph
	@echo "$(BLUE)Generating Terraform graph...$(NC)"
	cd $(ENV_DIR) && \
	terraform graph | dot -Tpng > infrastructure.png
	@echo "$(GREEN)Graph saved to infrastructure.png$(NC)"

##@ Utilities

clean: ## Clean temporary files
	@echo "$(BLUE)Cleaning temporary files...$(NC)"
	find . -name "*.tfstate.backup" -delete
	find . -name ".terraform.lock.hcl" -delete
	find . -name "tfplan" -delete
	find . -name "*.retry" -delete
	find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	@echo "$(GREEN)Clean completed$(NC)"

backup: ## Backup Terraform state
	@echo "$(BLUE)Backing up Terraform state...$(NC)"
	@for env in dev staging production; do \
		if [ -f "$(TF_DIR)/environments/$$env/terraform.tfstate" ]; then \
			cp $(TF_DIR)/environments/$$env/terraform.tfstate \
				$(TF_DIR)/environments/$$env/terraform.tfstate.backup.$$(date +%Y%m%d-%H%M%S); \
		fi; \
	done
	@echo "$(GREEN)Backup completed$(NC)"

version: ## Show Terraform version
	@terraform version

##@ CI/CD

ci: ## Run CI checks locally
	@echo "$(BLUE)Running CI checks...$(NC)"
	$(MAKE) fmt
	$(MAKE) validate
	$(MAKE) ansible-check
	$(MAKE) drift-check

cd-plan: ## Run CD plan workflow
	@echo "$(BLUE)Running CD plan for $(ENV)...$(NC)"
	$(MAKE) plan

cd-apply: ## Run CD apply workflow
	@echo "$(BLUE)Running CD apply for $(ENV)...$(NC)"
	$(MAKE) apply
	$(MAKE) ansible-init
	$(MAKE) ansible-run-all

##@ Quick Commands

dev-plan: ## Plan changes for dev environment
	ENV=dev $(MAKE) plan

dev-apply: ## Apply changes to dev environment
	ENV=dev $(MAKE) apply

prod-plan: ## Plan changes for production environment
	ENV=production $(MAKE) plan

prod-apply: ## Apply changes to production environment
	ENV=production $(MAKE) apply

status: ## Show infrastructure status
	@echo "$(BLUE)Infrastructure status for $(ENV):$(NC)"
	@echo ""
	@echo "$(GREEN)Proxmox Nodes:$(NC)"
	@echo "  - AGLSRV1 (192.168.0.245)"
	@echo "  - AGLSRV6 (192.168.0.246)"
	@echo ""
	@echo "$(GREEN)Running Containers:$(NC)"
	@ssh root@192.168.0.245 "pct list" | tail -n +2 || true
	@echo ""
	@echo "$(GREEN)Running VMs:$(NC)"
	@ssh root@192.168.0.245 "qm list" | tail -n +2 || true
