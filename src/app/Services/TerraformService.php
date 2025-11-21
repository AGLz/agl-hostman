<?php

namespace App\Services;

use Illuminate\Support\Facades\Process;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Log;

class TerraformService
{
    protected string $workspacePath;
    protected string $terraformPath;
    protected array $providers;
    
    public function __construct()
    {
        $this->workspacePath = storage_path('terraform');
        $this->terraformPath = config('terraform.binary_path', '/usr/local/bin/terraform');
        
        $this->providers = [
            'proxmox' => [
                'source' => 'telmate/proxmox',
                'version' => '2.9.11',
            ],
            'docker' => [
                'source' => 'kreuzwerker/docker',
                'version' => '3.0.2',
            ],
            'aws' => [
                'source' => 'hashicorp/aws',
                'version' => '~> 5.0',
            ],
        ];
        
        $this->ensureWorkspace();
    }

    /**
     * Ensure Terraform workspace exists
     */
    protected function ensureWorkspace(): void
    {
        if (!is_dir($this->workspacePath)) {
            mkdir($this->workspacePath, 0755, true);
        }
    }

    /**
     * Initialize Terraform workspace
     */
    public function init(string $environment = 'production'): array
    {
        $envPath = "{$this->workspacePath}/{$environment}";
        
        if (!is_dir($envPath)) {
            mkdir($envPath, 0755, true);
        }
        
        // Generate main.tf
        $this->generateMainConfig($environment);
        
        // Run terraform init
        $result = Process::path($envPath)
            ->run("{$this->terraformPath} init -backend=true");
        
        return [
            'success' => $result->successful(),
            'output' => $result->output(),
            'error' => $result->errorOutput(),
        ];
    }

    /**
     * Plan infrastructure changes
     */
    public function plan(string $environment = 'production', array $variables = []): array
    {
        $envPath = "{$this->workspacePath}/{$environment}";
        
        // Generate variable file
        $this->generateVariables($environment, $variables);
        
        // Run terraform plan
        $result = Process::path($envPath)
            ->timeout(300)
            ->run("{$this->terraformPath} plan -var-file=variables.tfvars -out=tfplan");
        
        if ($result->successful()) {
            // Parse plan output
            $plan = $this->parsePlanOutput($result->output());
            
            return [
                'success' => true,
                'plan' => $plan,
                'output' => $result->output(),
            ];
        }
        
        return [
            'success' => false,
            'error' => $result->errorOutput(),
        ];
    }

    /**
     * Apply infrastructure changes
     */
    public function apply(string $environment = 'production', bool $autoApprove = false): array
    {
        $envPath = "{$this->workspacePath}/{$environment}";
        
        $command = "{$this->terraformPath} apply";
        
        if ($autoApprove) {
            $command .= " -auto-approve";
        }
        
        if (file_exists("{$envPath}/tfplan")) {
            $command .= " tfplan";
        }
        
        $result = Process::path($envPath)
            ->timeout(600)
            ->run($command);
        
        if ($result->successful()) {
            // Get outputs
            $outputs = $this->getOutputs($environment);
            
            // Store state backup
            $this->backupState($environment);
            
            return [
                'success' => true,
                'outputs' => $outputs,
                'output' => $result->output(),
            ];
        }
        
        return [
            'success' => false,
            'error' => $result->errorOutput(),
        ];
    }

    /**
     * Destroy infrastructure
     */
    public function destroy(string $environment = 'production', bool $force = false): array
    {
        $envPath = "{$this->workspacePath}/{$environment}";
        
        $command = "{$this->terraformPath} destroy";
        
        if ($force) {
            $command .= " -auto-approve";
        }
        
        $result = Process::path($envPath)
            ->timeout(600)
            ->run($command);
        
        return [
            'success' => $result->successful(),
            'output' => $result->output(),
            'error' => $result->errorOutput(),
        ];
    }

    /**
     * Get Terraform outputs
     */
    public function getOutputs(string $environment = 'production'): array
    {
        $envPath = "{$this->workspacePath}/{$environment}";
        
        $result = Process::path($envPath)
            ->run("{$this->terraformPath} output -json");
        
        if ($result->successful()) {
            return json_decode($result->output(), true);
        }
        
        return [];
    }

    /**
     * Get current state
     */
    public function getState(string $environment = 'production'): array
    {
        $envPath = "{$this->workspacePath}/{$environment}";
        
        $result = Process::path($envPath)
            ->run("{$this->terraformPath} show -json");
        
        if ($result->successful()) {
            return json_decode($result->output(), true);
        }
        
        return [];
    }

    /**
     * Import existing resource
     */
    public function import(string $environment, string $resource, string $id): array
    {
        $envPath = "{$this->workspacePath}/{$environment}";
        
        $result = Process::path($envPath)
            ->run("{$this->terraformPath} import {$resource} {$id}");
        
        return [
            'success' => $result->successful(),
            'output' => $result->output(),
            'error' => $result->errorOutput(),
        ];
    }

    /**
     * Generate Proxmox VM configuration
     */
    public function generateProxmoxVM(array $config): string
    {
        $template = <<<'TERRAFORM'
resource "proxmox_vm_qemu" "{{name}}" {
  name        = "{{name}}"
  target_node = "{{node}}"
  vmid        = {{vmid}}
  clone       = "{{template}}"
  full_clone  = true

  cores   = {{cores}}
  memory  = {{memory}}
  balloon = {{balloon}}

  disk {
    size    = "{{disk_size}}"
    type    = "scsi"
    storage = "{{storage}}"
  }

  network {
    model  = "virtio"
    bridge = "{{bridge}}"
    {{#vlan}}
    tag    = {{vlan}}
    {{/vlan}}
  }

  ipconfig0 = "ip={{ip}}/{{cidr}},gw={{gateway}}"

  sshkeys = <<SSHKEYS
{{ssh_keys}}
SSHKEYS

  lifecycle {
    ignore_changes = [
      disk,
      network,
    ]
  }
}
TERRAFORM;
        
        // Replace placeholders
        foreach ($config as $key => $value) {
            if (is_bool($value)) {
                $value = $value ? 'true' : 'false';
            }
            $template = str_replace("{{$key}}", $value, $template);
        }
        
        // Clean up optional blocks
        $template = preg_replace('/{{#.*?}}.*?{{\/.*?}}/s', '', $template);
        
        return $template;
    }

    /**
     * Generate Docker container configuration
     */
    public function generateDockerContainer(array $config): string
    {
        $template = <<<'EOF'
resource "docker_container" "{{name}}" {
  name  = "{{name}}"
  image = docker_image.{{name}}.latest
  
  {{#ports}}
  ports {
    internal = {{internal}}
    external = {{external}}
  }
  {{/ports}}
  
  {{#env}}
  env = [
    {{#env_vars}}
    "{{key}}={{value}}",
    {{/env_vars}}
  ]
  {{/env}}
  
  {{#volumes}}
  volumes {
    host_path      = "{{host}}"
    container_path = "{{container}}"
  }
  {{/volumes}}
  
  restart = "{{restart}}"
  
  {{#networks}}
  networks_advanced {
    name = "{{network}}"
  }
  {{/networks}}
}

resource "docker_image" "{{name}}" {
  name         = "{{image}}"
  keep_locally = false
}
EOF;
        
        return $this->renderTemplate($template, $config);
    }

    /**
     * Generate main Terraform configuration
     */
    protected function generateMainConfig(string $environment): void
    {
        $config = <<<'EOF'
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "2.9.11"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
  }
  
  backend "local" {
    path = "terraform.tfstate"
  }
}

# Proxmox Provider
provider "proxmox" {
  pm_api_url      = var.proxmox_api_url
  pm_user         = var.proxmox_user
  pm_password     = var.proxmox_password
  pm_tls_insecure = var.proxmox_tls_insecure
}

# Docker Provider
provider "docker" {
  host = var.docker_host
}
EOF;
        
        file_put_contents("{$this->workspacePath}/{$environment}/main.tf", $config);
    }

    /**
     * Generate variables file
     */
    protected function generateVariables(string $environment, array $variables): void
    {
        $content = '';
        
        foreach ($variables as $key => $value) {
            if (is_array($value)) {
                $value = json_encode($value);
            } elseif (is_bool($value)) {
                $value = $value ? 'true' : 'false';
            } else {
                $value = '"' . addslashes($value) . '"';
            }
            
            $content .= "{$key} = {$value}\n";
        }
        
        file_put_contents("{$this->workspacePath}/{$environment}/variables.tfvars", $content);
    }

    /**
     * Parse plan output
     */
    protected function parsePlanOutput(string $output): array
    {
        $plan = [
            'add' => 0,
            'change' => 0,
            'destroy' => 0,
            'resources' => [],
        ];
        
        // Parse the output for resource changes
        if (preg_match('/Plan: (\d+) to add, (\d+) to change, (\d+) to destroy/', $output, $matches)) {
            $plan['add'] = (int) $matches[1];
            $plan['change'] = (int) $matches[2];
            $plan['destroy'] = (int) $matches[3];
        }
        
        // Extract resource details
        if (preg_match_all('/# (.*?) will be (.*)/', $output, $matches)) {
            foreach ($matches[1] as $index => $resource) {
                $plan['resources'][] = [
                    'resource' => $resource,
                    'action' => $matches[2][$index],
                ];
            }
        }
        
        return $plan;
    }

    /**
     * Backup Terraform state
     */
    protected function backupState(string $environment): void
    {
        $statePath = "{$this->workspacePath}/{$environment}/terraform.tfstate";
        
        if (file_exists($statePath)) {
            $backupPath = "{$this->workspacePath}/{$environment}/backups";
            
            if (!is_dir($backupPath)) {
                mkdir($backupPath, 0755, true);
            }
            
            $timestamp = now()->format('Y-m-d_H-i-s');
            copy($statePath, "{$backupPath}/terraform_{$timestamp}.tfstate");
            
            // Keep only last 10 backups
            $this->cleanOldBackups($backupPath, 10);
        }
    }

    /**
     * Clean old state backups
     */
    protected function cleanOldBackups(string $path, int $keep = 10): void
    {
        $files = glob("{$path}/*.tfstate");
        
        if (count($files) > $keep) {
            usort($files, function($a, $b) {
                return filemtime($b) - filemtime($a);
            });
            
            $toDelete = array_slice($files, $keep);
            
            foreach ($toDelete as $file) {
                unlink($file);
            }
        }
    }

    /**
     * Render template with data
     */
    protected function renderTemplate(string $template, array $data): string
    {
        // Simple template rendering
        foreach ($data as $key => $value) {
            if (is_array($value)) {
                // Handle array blocks
                $pattern = "/{{#{$key}}}(.*?){{\\/{$key}}}/s";
                
                if (preg_match($pattern, $template, $matches)) {
                    $blockTemplate = $matches[1];
                    $rendered = '';
                    
                    foreach ($value as $item) {
                        $block = $blockTemplate;
                        foreach ($item as $k => $v) {
                            $block = str_replace("{{$k}}", $v, $block);
                        }
                        $rendered .= $block;
                    }
                    
                    $template = preg_replace($pattern, $rendered, $template);
                }
            } else {
                $template = str_replace("{{$key}}", $value, $template);
            }
        }
        
        // Remove unused placeholders
        $template = preg_replace('/{{.*?}}/', '', $template);
        
        return $template;
    }

    /**
     * Validate Terraform configuration
     */
    public function validate(string $environment = 'production'): array
    {
        $envPath = "{$this->workspacePath}/{$environment}";
        
        $result = Process::path($envPath)
            ->run("{$this->terraformPath} validate");
        
        return [
            'success' => $result->successful(),
            'output' => $result->output(),
            'error' => $result->errorOutput(),
        ];
    }

    /**
     * Format Terraform configuration
     */
    public function format(string $environment = 'production'): array
    {
        $envPath = "{$this->workspacePath}/{$environment}";
        
        $result = Process::path($envPath)
            ->run("{$this->terraformPath} fmt -recursive");
        
        return [
            'success' => $result->successful(),
            'output' => $result->output(),
            'error' => $result->errorOutput(),
        ];
    }
}