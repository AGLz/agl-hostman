<?php

namespace App\Http\Requests\Container;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class ContainerCloneRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     */
    public function authorize(): bool
    {
        return true;
    }

    /**
     * Get the validation rules that apply to the request.
     */
    public function rules(): array
    {
        return [
            'source_vmid' => ['required', 'integer', 'min:100', 'max:999999999', 'exists:lxc_containers,vmid'],
            'target_vmid' => ['required', 'integer', 'min:100', 'max:999999999', 'unique:lxc_containers,vmid'],
            'node' => ['required', 'string', 'max:255'],
            'clone_mode' => ['required', 'string', 'in:full,linked'],
            'target_hostname' => ['nullable', 'string', 'max:63', 'regex:/^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$/'],
            'target_disk' => ['nullable', 'string', 'max:255'],
            'target_storage' => ['nullable', 'string', 'max:255'],
            'compression' => ['nullable', 'string', 'in:zstd,lzo,gzip,none'],
            'template' => ['nullable', 'string', 'max:255'],
            'clone_description' => ['nullable', 'string', 'max:500'],
            'preserve_network' => ['required', 'boolean'],
            'preserve_disk' => ['required', 'boolean'],
            'preserve_config' => ['required', 'boolean'],
            'root_password' => ['nullable', 'string', 'min:8', 'max:255'],
            'ssh_key' => ['nullable', 'string', 'min:100', 'max:4000'],
            'start_after_clone' => ['required', 'boolean'],
            'cleanup_after_clone' => ['required', 'boolean'],
            'cleanup_timeout_minutes' => ['nullable', 'integer', 'min:1', 'max:1440'],
            'tags' => ['nullable', 'array'],
            'tags.*' => ['string', 'max:50'],
            'cost_center' => ['nullable', 'string', 'max:50'],
            'owner_email' => ['nullable', 'email', 'max:255'],
            'auto_backup_enabled' => ['required', 'boolean'],
            'backup_schedule' => ['nullable', 'string', 'in:daily,weekly,monthly'],
            'monitoring_enabled' => ['required', 'boolean'],
            'notifications_enabled' => ['required', 'boolean'],
        ];
    }

    /**
     * Get custom messages for validator errors.
     */
    public function messages(): array
    {
        return [
            'source_vmid.required' => 'O VMID de origem é obrigatório.',
            'source_vmid.exists' => 'O container de origem não existe ou não está acessível.',
            'target_vmid.required' => 'O VMID de destino é obrigatório.',
            'target_vmid.unique' => 'Este VMID de destino já está em uso.',
            'clone_mode.required' => 'O modo de clone é obrigatório.',
            'clone_mode.in' => 'O modo de clone deve ser: full ou linked.',
            'target_hostname.regex' => 'O hostname de destino deve seguir o formato RFC 1123.',
            'ssh_key.min' => 'A chave SSH deve ter no mínimo 100 caracteres.',
            'ssh_key.max' => 'A chave SSH deve ter no máximo 4000 caracteres.',
            'compression.in' => 'O algoritmo de compressão deve ser: zstd, lzo, gzip ou none.',
            'cleanup_timeout_minutes.min' => 'O timeout de limpeza deve ser no mínimo 1 minuto.',
            'cleanup_timeout_minutes.max' => 'O timeout de limpeza deve ser no máximo 1440 minutos (24 horas).',
            'backup_schedule.in' => 'O agendamento de backup deve ser: daily, weekly ou monthly.',
        ];
    }

    /**
     * Get custom attributes for validator errors.
     */
    public function attributes(): array
    {
        return [
            'source_vmid' => 'VMID de origem',
            'target_vmid' => 'VMID de destino',
            'node' => 'Nó do Proxmox',
            'clone_mode' => 'Modo de clone',
            'target_hostname' => 'Hostname de destino',
            'target_disk' => 'Disco de destino',
            'target_storage' => 'Armazenamento de destino',
            'compression' => 'Compressão',
            'template' => 'Template',
            'clone_description' => 'Descrição do clone',
            'preserve_network' => 'Manter rede',
            'preserve_disk' => 'Manter disco',
            'preserve_config' => 'Manter configuração',
            'root_password' => 'Senha root',
            'ssh_key' => 'Chave SSH',
            'start_after_clone' => 'Iniciar após clone',
            'cleanup_after_clone' => 'Limpar após clone',
            'cleanup_timeout_minutes' => 'Timeout de limpeza',
            'tags' => 'Tags',
            'cost_center' => 'Centro de custo',
            'owner_email' => 'Email do proprietário',
            'auto_backup_enabled' => 'Backup automático',
            'backup_schedule' => 'Agendamento de backup',
            'monitoring_enabled' => 'Monitoramento',
            'notifications_enabled' => 'Notificações',
        ];
    }

    /**
     * Configure the validator instance.
     */
    public function withValidator($validator)
    {
        $validator->after(function ($validator) {
            // Validação de VMIDs válidos
            $this->validateVmids($validator);

            // Validação de recursos disponíveis
            $this->validateAvailableResources($validator);

            // Validação de integridade do clone
            $this->validateCloneIntegrity($validator);

            // Validação de configuração de rede
            $this->validateNetworkConfig($validator);

            // Validação de configuração de backup
            $this->validateBackupConfig($validator);
        });
    }

    /**
     * Validar VMIDs de origem e destino
     */
    protected function validateVmids($validator): void
    {
        $sourceVmid = $this->input('source_vmid');
        $targetVmid = $this->input('target_vmid');

        // Verificar se os VMIDs são diferentes
        if ($sourceVmid === $targetVmid) {
            $validator->errors()->add('target_vmid', 'O VMID de destino deve ser diferente do VMID de origem.');
        }

        // Verificar se o VMID de destino está no mesmo range do de origem
        $sourceRange = $this->getVmIdRange($sourceVmid);
        if (!$this->isInVmIdRange($targetVmid, $sourceRange)) {
            $validator->errors()->add('target_vmid', 'O VMID de destino deve estar no mesmo range do VMID de origem.');
        }
    }

    /**
     * Validar recursos disponíveis no nó
     */
    protected function validateAvailableResources($validator): void
    {
        $node = $this->input('node');
        $cloneMode = $this->input('clone_mode');

        // Aqui você poderia consultar o Proxmox API para verificar recursos disponíveis
        // Por enquanto, apenas uma validação básica
        if ($cloneMode === 'full') {
            // Clone completo requer mais recursos
            $validator->errors()->add('clone_mode', 'Clone completo requer mais espaço em disco. Verifique a disponibilidade.');
        }
    }

    /**
     * Validar integridade do clone
     */
    protected function validateCloneIntegrity($validator): void
    {
        $sourceVmid = $this->input('source_vmid');
        $preserveConfig = $this->input('preserve_config');
        $rootPassword = $this->input('root_password');
        $sshKey = $this->input('ssh_key');

        // Se preservar configuração, deve fornecer ou senha SSH ou chave SSH
        if ($preserveConfig && !$rootPassword && !$sshKey) {
            $validator->errors()->add('credentials', 'Deve fornecer senha root ou chave SSH para o clone.');
        }

        // Validação de chave SSH
        if ($sshKey) {
            $this->validateSshKey($validator);
        }
    }

    /**
     * Validar configuração de rede
     */
    protected function validateNetworkConfig($validator): void
    {
        $preserveNetwork = $this->input('preserve_network');
        $targetHostname = $this->input('target_hostname');

        // Se preservar rede, hostname não deve ser o mesmo
        if ($preserveNetwork && $targetHostname) {
            // Aqui você poderia verificar se o hostname já existe na rede
            // Por enquanto, apenas uma validação básica
        }
    }

    /**
     * Validar configuração de backup
     */
    protected function validateBackupConfig($validator): void
    {
        $autoBackupEnabled = $this->input('auto_backup_enabled');
        $backupSchedule = $this->input('backup_schedule');
        $cleanupAfterClone = $this->input('cleanup_after_clone');

        // Se backup automático estiver habilitado, deve ter agendamento
        if ($autoBackupEnabled && !$backupSchedule) {
            $validator->errors()->add('backup_schedule', 'É necessário definir um agendamento de backup.');
        }

        // Se for limpar após clone, deve ter timeout definido
        if ($cleanupAfterClone && !$this->input('cleanup_timeout_minutes')) {
            $validator->errors()->add('cleanup_timeout_minutes', 'É necessário definir um timeout para limpeza.');
        }
    }

    /**
     * Validar formato da chave SSH
     */
    protected function validateSshKey($validator): void
    {
        $sshKey = $this->input('ssh_key');
        if ($sshKey && !str_starts_with($sshKey, 'ssh-rsa') && !str_starts_with($sshKey, 'ssh-ed25519')) {
            $validator->errors()->add('ssh_key', 'A chave SSH deve começar com ssh-rsa ou ssh-ed25519.');
        }
    }

    /**
     * Obter range de VMID baseado no VMID de origem
     */
    protected function getVmIdRange(int $vmid): string
    {
        // Exemplo de lógica para determinar range do VMID
        if ($vmid >= 100 && $vmid <= 999) return '100-999';
        if ($vmid >= 1000 && $vmid <= 9999) return '1000-9999';
        if ($vmid >= 10000 && $vmid <= 99999) return '10000-99999';
        return 'custom';
    }

    /**
     * Verificar se VMID está no range especificado
     */
    protected function isInVmIdRange(int $vmid, string $range): bool
    {
        switch ($range) {
            case '100-999':
                return $vmid >= 100 && $vmid <= 999;
            case '1000-9999':
                return $vmid >= 1000 && $vmid <= 9999;
            case '10000-99999':
                return $vmid >= 10000 && $vmid <= 99999;
            default:
                return true; // Custom ranges são permitidos
        }
    }
}
