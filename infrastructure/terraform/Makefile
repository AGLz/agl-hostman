# =============================================================================
# AGL Hostman - Terraform Makefile
# =============================================================================
# Convenience targets for common Terraform operations
# =============================================================================

.PHONY: all init plan apply destroy refresh fmt validate fmt-check \
        clean docs help init-backend migrate-state show-output graph \
        import-existing drift-detect state-list state-pull state-push \
        pre-commit pre-push validate-modules generate-docs test-modules

# Default target
all: fmt validate plan

# Configuration
TERRAFORM        ?= terraform
TERRAFORM_DIR     ?= .
ENVIRONMENT      ?= development
WORKSPACE        ?= $(ENVIRONMENT)
STATE_BACKEND    ?= s3
PLAN_FILE        ?= tfplan
PLAN_JSON        ?= tfplan.json
VAR_FILE         ?= environments/$(ENVIRONMENT)/terraform.tfvars
OUT_FILE        ?= outputs/$(ENVIRONMENT).txt

# Colors for output
COLOR_RESET      = \033[0m
COLOR_INFO       = \033[36m
COLOR_SUCCESS    = \033[32m
COLOR_WARNING    = \033[33m
COLOR_ERROR      = \033[31m

# =============================================================================
# Help
# =============================================================================
help:
    @echo "$(COLOR_INFO)AGL Hostman - Terraform Operations$(COLOR_RESET)"
    @echo ""
    @echo "$(COLOR_SUCCESS)Setup:$(COLOR_RESET)"
    @echo "  make init           Initialize Terraform configuration"
    @echo "  make init-backend   Initialize state backend"
    @echo "  make validate       Validate configuration"
    @echo "  make fmt            Format files"
    @echo "  make fmt-check      Check formatting"
    @echo ""
    @echo "$(COLOR_SUCCESS)Operations:$(COLOR_RESET)"
    @echo "  make plan           Show execution plan"
    @echo "  make apply          Apply changes"
    @echo "  make destroy        Destroy infrastructure"
    @echo "  make refresh        Refresh state"
    @echo "  make show-output     Show outputs"
    @echo ""
    @echo "$(COLOR_SUCCESS)Workspaces:$(COLOR_RESET)"
    @echo "  make workspace-new NAME=env      Create new workspace"
    @echo "  make workspace-select NAME=env    Switch workspace"
    @echo "  make workspace-list               List workspaces"
    @echo ""
    @echo "$(COLOR_SUCCESS)State:$(COLOR_RESET)"
    @echo "  make state-list     List state resources"
    @echo "  make state-pull     Pull state from remote"
    @echo "  make state-push     Push state to remote"
    @echo "  make migrate-state  Migrate state to backend"
    @echo ""
    @echo "$(COLOR_SUCCESS)Advanced:$(COLOR_RESET)"
    @echo "  make graph          Generate dependency graph"
    @echo "  make drift-detect   Detect configuration drift"
    @echo "  make import-existing Import existing resources"
    @echo "  make generate-docs  Generate module documentation"
    @echo ""
    @echo "$(COLOR_SUCCESS)Testing:$(COLOR_RESET)"
    @echo "  make test-modules   Test all modules"
    @echo "  make validate-modules Validate all modules"

# =============================================================================
# Setup Targets
# =============================================================================
init:
    @echo "$(COLOR_INFO)Initializing Terraform...$(COLOR_RESET)"
    $(TERRAFORM) init -upgrade
    @echo "$(COLOR_SUCCESS)Initialization complete$(COLOR_RESET)"

init-backend:
    @echo "$(COLOR_INFO)Initializing backend: $(STATE_BACKEND)$(COLOR_RESET)"
    $(TERRAFORM) init \
        -backend-config=$(STATE_BACKEND).tfvars \
        -reconfigure
    @echo "$(COLOR_SUCCESS)Backend initialized$(COLOR_RESET)"

validate:
    @echo "$(COLOR_INFO)Validating configuration...$(COLOR_RESET)"
    $(TERRAFORM) validate
    @echo "$(COLOR_SUCCESS)Validation passed$(COLOR_RESET)"

validate-modules:
    @echo "$(COLOR_INFO)Validating all modules...$(COLOR_RESET)"
    @for dir in modules/*/; do \
        echo "Validating $$dir..."; \
        cd "$$dir" && $(TERRAFORM) init -backend=false && $(TERRAFORM) validate; \
        cd - > /dev/null; \
    done
    @echo "$(COLOR_SUCCESS)All modules validated$(COLOR_RESET)"

fmt:
    @echo "$(COLOR_INFO)Formatting files...$(COLOR_RESET)"
    $(TERRAFORM) fmt -recursive
    @echo "$(COLOR_SUCCESS)Formatting complete$(COLOR_RESET)"

fmt-check:
    @echo "$(COLOR_INFO)Checking formatting...$(COLOR_RESET)"
    $(TERRAFORM) fmt -check -recursive
    @echo "$(COLOR_SUCCESS)Formatting check passed$(COLOR_RESET)"

# =============================================================================
# Operation Targets
# =============================================================================
plan: init fmt
    @echo "$(COLOR_INFO)Creating execution plan...$(COLOR_RESET)"
    $(TERRAFORM) plan \
        -var-file=$(VAR_FILE) \
        -out=$(PLAN_FILE)
    @echo "$(COLOR_SUCCESS)Plan created: $(PLAN_FILE)$(COLOR_RESET)"

plan-json: plan
    @echo "$(COLOR_INFO)Converting plan to JSON...$(COLOR_RESET)"
    $(TERRAFORM) show -json $(PLAN_FILE) > $(PLAN_JSON)
    @echo "$(COLOR_SUCCESS)Plan JSON created: $(PLAN_JSON)$(COLOR_RESET)"

apply: init
    @echo "$(COLOR_WARNING)Applying changes...$(COLOR_RESET)"
    $(TERRAFORM) apply \
        -var-file=$(VAR_FILE) \
        $(PLAN_FILE)
    @echo "$(COLOR_SUCCESS)Apply complete$(COLOR_RESET)"

apply-auto: init
    @echo "$(COLOR_WARNING)Auto-applying changes (no plan review)...$(COLOR_RESET)"
    $(TERRAFORM) apply \
        -auto-approve \
        -var-file=$(VAR_FILE)

destroy: init
    @echo "$(COLOR_ERROR)Destroying infrastructure...$(COLOR_RESET)"
    $(TERRAFORM) destroy \
        -var-file=$(VAR_FILE) \
        -auto-approve

refresh: init
    @echo "$(COLOR_INFO)Refreshing state...$(COLOR_RESET)"
    $(TERRAFORM) refresh \
        -var-file=$(VAR_FILE)

show-output:
    @echo "$(COLOR_INFO)Terraform Outputs:$(COLOR_RESET)"
    @$(TERRAFORM) output -json

# =============================================================================
# Workspace Targets
# =============================================================================
workspace-new:
    @echo "$(COLOR_INFO)Creating workspace: $(NAME)$(COLOR_RESET)"
    $(TERRAFORM) workspace new $(NAME)
    $(MAKE) init

workspace-select:
    @echo "$(COLOR_INFO)Selecting workspace: $(NAME)$(COLOR_RESET)"
    $(TERRAFORM) workspace select $(NAME)

workspace-list:
    @echo "$(COLOR_INFO)Available workspaces:$(COLOR_RESET)"
    @$(TERRAFORM) workspace list

# =============================================================================
# State Targets
# =============================================================================
state-list:
    @echo "$(COLOR_INFO)State resources:$(COLOR_RESET)"
    $(TERRAFORM) state list

state-pull:
    @echo "$(COLOR_INFO)Pulling state from remote...$(COLOR_RESET)"
    $(TERRAFORM) state pull > terraform.tfstate

state-push:
    @echo "$(COLOR_INFO)Pushing state to remote...$(COLOR_RESET)"
    $(TERRAFORM) state push terraform.tfstate

migrate-state:
    @echo "$(COLOR_INFO)Migrating state to backend...$(COLOR_RESET)"
    $(TERRAFORM) init \
        -migrate-state \
        -backend-config=$(STATE_BACKEND).tfvars

state-backup:
    @echo "$(COLOR_INFO)Backing up state...$(COLOR_RESET)"
    @BACKUP_DIR="backups/$$(date +%Y%m%d_%H%M%S)"; \
    mkdir -p $$BACKUP_DIR; \
    cp terraform.tfstate $$BACKUP_DIR/; \
    cp terraform.tfstate.backup $$BACKUP_DIR/; \
    echo "$(COLOR_SUCCESS)State backed up to: $$BACKUP_DIR$(COLOR_RESET)"

# =============================================================================
# Advanced Targets
# =============================================================================
graph:
    @echo "$(COLOR_INFO)Generating dependency graph...$(COLOR_RESET)"
    $(TERRAFORM) graph -type=cycle | dot -Tpng > graph.png
    @echo "$(COLOR_SUCCESS)Graph saved to graph.png$(COLOR_RESET)"

drift-detect: refresh
    @echo "$(COLOR_INFO)Detecting drift...$(COLOR_RESET)"
    $(TERRAFORM) plan -detailed-exitcode \
        -var-file=$(VAR_FILE) \
        -out=drift.tfplan

import-existing:
    @echo "$(COLOR_INFO)Importing resources...$(COLOR_RESET)"
    @echo "Usage: make import-existing ADDR=module.name.resource.name ID"
    @echo "Example: make import-existing ADDR=proxmox_vm_qemu.this 100"
    $(TERRAFORM) import $(ADDR) $(ID)

# =============================================================================
# Documentation Targets
# =============================================================================
generate-docs:
    @echo "$(COLOR_INFO)Generating documentation...$(COLOR_RESET)"
    @for dir in modules/*/; do \
        echo "Generating docs for $$dir..."; \
        terraform-docs markdown "$$dir" > "$$dir/README.md"; \
    done
    @echo "$(COLOR_SUCCESS)Documentation generated$(COLOR_RESET)"

docs:
    @echo "$(COLOR_INFO)Creating diagrams...$(COLOR_RESET)"
    @$(TERRAFORM) graph | graphviz -Tpng > architecture.png
    @echo "$(COLOR_SUCCESS)Architecture diagram saved$(COLOR_RESET)"

# =============================================================================
# Testing Targets
# =============================================================================
test-modules:
    @echo "$(COLOR_INFO)Testing modules...$(COLOR_RESET)"
    @for module in modules/*/; do \
        echo "Testing $$module..."; \
        cd "$$module" && \
        $(TERRAFORM) init -backend=false && \
        $(TERRAFORM) validate && \
        $(TERRAFORM) fmt -check && \
        cd - > /dev/null; \
    done
    @echo "$(COLOR_SUCCESS)All tests passed$(COLOR_RESET)"

test-integration:
    @echo "$(COLOR_INFO)Running integration tests...$(COLOR_RESET)"
    cd tests/integration && go test -v

# =============================================================================
# Utility Targets
# =============================================================================
clean:
    @echo "$(COLOR_INFO)Cleaning temporary files...$(COLOR_RESET)"
    rm -rf .terraform
    rm -rf .terraform.lock.hcl
    rm -f *.tfstate
    rm -f *.tfstate.*
    rm -f tfplan
    rm -f tfplan.json
    rm -f graph.png
    rm -rf outputs/
    @echo "$(COLOR_SUCCESS)Clean complete$(COLOR_RESET)"

pre-commit: fmt-check validate
    @echo "$(COLOR_SUCCESS)Pre-commit checks passed$(COLOR_RESET)"

pre-push: validate-modules test-modules
    @echo "$(COLOR_SUCCESS)Pre-push checks passed$(COLOR_RESET)"

# =============================================================================
# CI/CD Integration
# =============================================================================
ci-plan: fmt-check validate
    @echo "$(COLOR_INFO)CI: Creating plan...$(COLOR_RESET)"
    $(TERRAFORM) plan \
        -var-file=$(VAR_FILE) \
        -out=$(PLAN_FILE)

ci-apply: ci-plan
    @echo "$(COLOR_INFO)CI: Applying changes...$(COLOR_RESET)"
    $(TERRAFORM) apply \
        -auto-approve \
        $(PLAN_FILE)

ci-validate: fmt-check validate-modules
    @echo "$(COLOR_SUCCESS)CI validation passed$(COLOR_RESET)

# =============================================================================
# Environment-Specific Targets
# =============================================================================
plan-dev:
    $(MAKE) plan ENVIRONMENT=development

plan-staging:
    $(MAKE) plan ENVIRONMENT=staging

plan-prod:
    $(MAKE) plan ENVIRONMENT=production

apply-dev:
    $(MAKE) apply ENVIRONMENT=development

apply-staging:
    $(MAKE) apply ENVIRONMENT=staging

apply-prod:
    $(MAKE) apply ENVIRONMENT=production

# =============================================================================
# Dependency Graph Targets
# =============================================================================
plan-svg:
    @$(TERRAFORM) graph -type=plan | dot -Tsvg > plan.svg
    @echo "$(COLOR_SUCCESS)Plan saved to plan.svg$(COLOR_RESET)"

plan-human:
    @$(TERRAFORM) graph -type=plan | dot -Tpng > plan-human.png
    @echo "$(COLOR_SUCCESS)Human-readable plan saved$(COLOR_RESET)"

# =============================================================================
# Output Formatting
# =============================================================================
output-json:
    @mkdir -p outputs
    @$(TERRAFORM) output -json > outputs/outputs.json

output-text:
    @mkdir -p outputs
    @$(TERRAFORM) output > outputs/outputs.txt
