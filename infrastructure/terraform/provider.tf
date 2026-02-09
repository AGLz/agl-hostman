# Terraform Provider Configuration for Proxmox and Ansible
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = ">= 3.0.1-rc4"
    }
    ansible = {
      source  = "nbering/ansible"
      version = ">= 1.1.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.1"
    }
    template = {
      source  = "hashicorp/template"
      version = ">= 2.2.0"
    }
  }

  # Remote state backend (Azure Storage, S3, or Terraform Cloud)
  backend "azurerm" {
    resource_group_name  = "agl-infrastructure"
    storage_account_name = "aglterraformstate"
    container_name       = "terraform-state"
    key                  = "proxmox-infrastructure.tfstate"
    use_azuread_auth     = true
  }

  # Alternative backend options (commented out)
  # backend "s3" {
  #   bucket         = "agl-terraform-state"
  #   key            = "proxmox-infrastructure.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }

  # backend "remote" {
  #   organization = "agl-hostman"
  #   workspaces {
  #     name = "proxmox-infrastructure"
  #   }
  # }
}

provider "proxmox" {
  pm_api_url          = var.proxmox_api_url
  pm_api_token_id     = var.proxmox_api_token_id
  pm_api_token_secret = var.proxmox_api_token_secret
  pm_tls_insecure     = var.proxmox_tls_insecure
  pm_timeout          = var.proxmox_timeout
  pm_debug            = var.proxmox_debug
  pm_log_enable       = var.proxmox_log_enable
  pm_log_file         = var.proxmox_log_file
}

provider "ansible" {
  # Ansible provider configuration
  # Used for triggering playbook runs from Terraform
}
