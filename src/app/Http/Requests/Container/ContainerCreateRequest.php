<?php

namespace App\Http\Requests\Container;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class ContainerCreateRequest extends FormRequest
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
            'vmid' => ['required', 'integer', 'min:100', 'max:999999999', 'unique:lxc_containers,vmid'],
            'node' => ['required', 'string', 'max:255'],
            'hostname' => ['required', 'string', 'max:63', 'regex:/^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$/'],
            'cores' => ['required', 'integer', 'min:1', 'max:256'],
            'memory_mb' => ['required', 'integer', 'min:128', 'max:524288'], // 128MB - 512GB
            'disk_size_gb' => ['required', 'integer', 'min:1', 'max:16384'], // 1GB - 16TB
            'template' => ['nullable', 'string', 'max:255'],
            'ostype' => ['required', 'string', 'in:ubuntu,debian,centos,alpine,arch,custom'],
            'password' => ['nullable', 'string', 'min:8', 'max:255'],
            'ssh_key' => ['nullable', 'string', 'min:100', 'max:4000'],
            'start_on_boot' => ['required', 'boolean'],
            'unprivileged' => ['required', 'boolean'],
            'features' => ['nullable', 'array'],
            'features.*' => ['string', 'in:nesting,keyctl,fuse,mount,cgroups,nesting,sysctl'],
            'network' => ['nullable', 'array'],
            'network.bridge' => ['required_with:network', 'string', 'max:255'],
            'network.ip' => ['nullable', 'ip'],
            'network.gateway' => ['nullable', 'ip'],
            'network.nameservers' => ['nullable', 'array'],
            'network.nameservers.*' => ['ip'],
            'resource_limits' => ['nullable', 'array'],
            'resource_limits.cpu' => ['nullable', 'string'],
            'resource_limits.memory' => ['nullable', 'string'],
            'resource_limits.swap' => ['nullable', 'string'],
            'disk_limits' => ['nullable', 'array'],
            'disk_limits.root' => ['required_with:disk_limits', 'string'],
            'tags' => ['nullable', 'array'],
            'tags.*' => ['string', 'max:50'],
            'description' => ['nullable', 'string', 'max:500'],
            'cost_center' => ['nullable', 'string', 'max:50'],
            'owner_email' => ['nullable', 'email', 'max:255'],
            'auto_cleanup_days' => ['nullable', 'integer', 'min:1', 'max:365'],
            'backup_enabled' => ['required', 'boolean'],
            'backup_schedule' => ['nullable', 'string', 'in:daily,weekly,monthly'],
            'monitoring_enabled' => ['required', 'boolean'],
            'notifications_enabled' => ['required', 'boolean'],
            'web_console_enabled' => ['required', 'boolean'],
            'rdp_enabled' => ['required', 'boolean'],
        ];
    }

    /**
     * Get custom messages for validator errors.
     */
    public function messages(): array
    {
        return [
            'vmid.required' => 'O VMID é obrigatório.',
            'vmid.unique' => 'Este VMID já está em uso por outro container.',
            'vmid.min' => 'O VMID deve ser maior que 100.',
            'vmid.max' => 'O VMID deve ser menor que 999.999.999.',
            'hostname.required' => 'O hostname é obrigatório.',
            'hostname.regex' => 'O hostname deve seguir o formato RFC 1123 (apenas letras, números e hífens).',
            'hostname.max' => 'O hostname não pode ter mais de 63 caracteres.',
            'cores.required' => 'O número de cores é obrigatório.',
            'cores.min' => 'O número de cores deve ser no mínimo 1.',
            'cores.max' => 'O número de cores deve ser no máximo 256.',
            'memory_mb.required' => 'A quantidade de memória é obrigatória.',
            'memory_mb.min' => 'A memória mínima é 128MB.',
            'memory_mb.max' => 'A memória máxima é 512GB.',
            'disk_size_gb.required' => 'O tamanho do disco é obrigatório.',
            'disk_size_gb.min' => 'O tamanho mínimo do disco é 1GB.',
            'disk_size_gb.max' => 'O tamanho máximo do disco é 16TB.',
            'password.min' => 'A senha deve ter no mínimo 8 caracteres.',
            'ssh_key.min' => 'A chave SSH deve ter no mínimo 100 caracteres.',
            'ssh_key.max' => 'A chave SSH deve ter no máximo 4000 caracteres.',
            'ostype.in' => 'O sistema operacional deve ser: ubuntu, debian, centos, alpine, arch ou custom.',
            'features.*.in' => 'Recursos inválidos. Opções: nesting, keyctl, fuse, mount, cgroups, sysctl.',
            'network.bridge.required_with' => 'A bridge de rede é obrigatória quando a rede é configurada.',
            'resource_limits.cpu.regex' => 'O limite de CPU deve estar no formato válido (ex: "2.5-4").',
            'tags.*.max' => 'Cada tag não pode ter mais de 50 caracteres.',
            'auto_cleanup_days.min' => 'O período de limpeza automática deve ser no mínimo 1 dia.',
            'auto_cleanup_days.max' => 'O período de limpeza automática deve ser no máximo 365 dias.',
            'backup_schedule.in' => 'O agendamento de backup deve ser: daily, weekly ou monthly.',
        ];
    }

    /**
     * Get custom attributes for validator errors.
     */
    public function attributes(): array
    {
        return [
            'vmid' => 'VMID do container',
            'node' => 'Nó do Proxmox',
            'hostname' => 'Hostname do container',
            'cores' => 'Núcleos de CPU',
            'memory_mb' => 'Memória RAM',
            'disk_size_gb' => 'Tamanho do disco',
            'template' => 'Template do sistema',
            'ostype' => 'Tipo do sistema operacional',
            'password' => 'Senha de root',
            'ssh_key' => 'Chave SSH',
            'start_on_boot' => 'Iniciar na inicialização',
            'unprivileged' => 'Container não privilegiado',
            'features' => 'Recursos do container',
            'network' => 'Configuração de rede',
            'bridge' => 'Bridge de rede',
            'ip' => 'Endereço IP',
            'gateway' => 'Gateway',
            'nameservers' => 'Servidores DNS',
            'resource_limits' => 'Limites de recursos',
            'disk_limits' => 'Limites de disco',
            'tags' => 'Tags',
            'description' => 'Descrição',
            'cost_center' => 'Centro de custo',
            'owner_email' => 'Email do proprietário',
            'auto_cleanup_days' => 'Dias de limpeza automática',
            'backup_enabled' => 'Backup habilitado',
            'backup_schedule' => 'Agendamento de backup',
            'monitoring_enabled' => 'Monitoramento habilitado',
            'notifications_enabled' => 'Notificações habilitadas',
            'web_console_enabled' => 'Console web habilitado',
            'rdp_enabled' => 'RDP habilitado',
        ];
    }

    /**
     * Configure the validator instance.
     */
    public function withValidator($validator)
    {
        $validator->after(function ($validator) {
            // Validação específica para chave SSH
            if ($this->input('ssh_key')) {
                $this->validateSshKey($validator);
            }

            // Validação de endereço IP único na rede
            if ($this->input('network.ip')) {
                $this->validateUniqueIp($validator);
            }

            // Validação de requisitos do sistema operacional
            if ($this->input('ostype')) {
                $this->validateOsRequirements($validator);
            }

            // Validação de custo estimado
            $this->validateCostEstimate($validator);
        });
    }

    /**
     * Validar formato da chave SSH
     */
    protected function validateSshKey($validator): void
    {
        $sshKey = $this->input('ssh_key');
        if (!str_starts_with($sshKey, 'ssh-rsa') && !str_starts_with($sshKey, 'ssh-ed25519')) {
            $validator->errors()->add('ssh_key', 'A chave SSH deve começar com ssh-rsa ou ssh-ed25519.');
        }
    }

    /**
     * Validar endereço IP único na rede
     */
    protected function validateUniqueIp($validator): void
    {
        // Aqui você poderia consultar o Proxmox API para verificar se o IP já está em uso
        // Por enquanto, apenas uma validação básica
        $ip = $this->input('network.ip');
        if ($ip && filter_var($ip, FILTER_VALIDATE_IP)) {
            // Lógica adicional de validação de IP único
        }
    }

    /**
     * Validar requisitos do sistema operacional
     */
    protected function validateOsRequirements($validator): void
    {
        $osType = $this->input('ostype');
        $memoryMb = $this->input('memory_mb');

        switch ($osType) {
            case 'alpine':
                if ($memoryMb < 128) {
                    $validator->errors()->add('memory_mb', 'O Alpine Linux requer no mínimo 128MB de memória.');
                }
                break;
            case 'arch':
                if ($memoryMb < 256) {
                    $validator->errors()->add('memory_mb', 'O Arch Linux requer no mínimo 256MB de memória.');
                }
                break;
            case 'ubuntu':
            case 'debian':
            case 'centos':
                if ($memoryMb < 512) {
                    $validator->errors()->add('memory_mb', 'As distribuições Linux principais requerem no mínimo 512MB de memória.');
                }
                break;
        }
    }

    /**
     * Validar estimativa de custo
     */
    protected function validateCostEstimate($validator): void
    {
        $memoryGb = $this->input('memory_mb', 0) / 1024;
        $diskGb = $this->input('disk_size_gb', 0);
        $cores = $this->input('cores', 1);

        // Cálculo de custo estimado (exemplo)
        $estimatedCost = ($memoryGb * 0.10) + ($diskGb * 0.05) + ($cores * 0.20);

        if ($estimatedCost > 100) {
            $validator->errors()->add(
                'cost_estimate',
                'O custo estimado é R$' . number_format($estimatedCost, 2) .
                '. Por favor, confirme os valores ou entre em contato com o administrador.'
            );
        }
    }
}
