<?php

namespace App\Http\Requests\Container;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class ContainerSnapshotRequest extends FormRequest
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
            'vmid' => ['required', 'integer', 'min:100', 'max:999999999', 'exists:lxc_containers,vmid'],
            'node' => ['required', 'string', 'max:255'],
            'name' => ['required', 'string', 'max:40', 'regex:/^[a-zA-Z0-9][a-zA-Z0-9_-]*[a-zA-Z0-9]$/'],
            'description' => ['nullable', 'string', 'max:500'],
            'parent_snapshot' => ['nullable', 'string', 'max:40'],
            'snapshot_type' => ['required', 'string', 'in:manual,automatic,backup'],
            'compression' => ['nullable', 'string', 'in:zstd,lzo,gzip,none'],
            'cleanup_after_days' => ['nullable', 'integer', 'min:1', 'max:365'],
            'cleanup_policy' => ['nullable', 'string', 'in:oldest,smallest,custom'],
            'storage' => ['nullable', 'string', 'max:255'],
            'max_snapshots' => ['nullable', 'integer', 'min:1', 'max:50'],
            'tags' => ['nullable', 'array'],
            'tags.*' => ['string', 'max:50'],
            'metadata' => ['nullable', 'array'],
            'metadata.*' => ['string', 'max:255'],
            'description_format' => ['nullable', 'string', 'in:text,json,yaml'],
            'notification_enabled' => ['required', 'boolean'],
            'notification_channel' => ['nullable', 'string', 'max:255'],
            'auto_snapshot' => ['required', 'boolean'],
            'auto_snapshot_schedule' => ['nullable', 'string', 'in:daily,weekly,monthly'],
            'auto_snapshot_retention' => ['nullable', 'integer', 'min:1', 'max:30'],
            'skip_if_running' => ['required', 'boolean'],
            'force_stop' => ['required', 'boolean'],
            'memory_state' => ['required', 'boolean'],
        ];
    }

    /**
     * Get custom messages for validator errors.
     */
    public function messages(): array
    {
        return [
            'vmid.required' => 'O VMID é obrigatório.',
            'vmid.exists' => 'O container não existe ou não está acessível.',
            'name.required' => 'O nome do snapshot é obrigatório.',
            'name.max' => 'O nome do snapshot não pode ter mais de 40 caracteres.',
            'name.regex' => 'O nome do snapshot deve conter apenas letras, números, hífens e underscores.',
            'parent_snapshot.max' => 'O nome do snapshot pai não pode ter mais de 40 caracteres.',
            'snapshot_type.required' => 'O tipo de snapshot é obrigatório.',
            'snapshot_type.in' => 'O tipo de snapshot deve ser: manual, automatic ou backup.',
            'compression.in' => 'O algoritmo de compressão deve ser: zstd, lzo, gzip ou none.',
            'cleanup_after_days.min' => 'O período de limpeza deve ser no mínimo 1 dia.',
            'cleanup_after_days.max' => 'O período de limpeza deve ser no máximo 365 dias.',
            'cleanup_policy.in' => 'A política de limpeza deve ser: oldest, smallest ou custom.',
            'max_snapshots.min' => 'O número máximo de snapshots deve ser no mínimo 1.',
            'max_snapshots.max' => 'O número máximo de snapshots deve ser no máximo 50.',
            'description_format.in' => 'O formato de descrição deve ser: text, json ou yaml.',
            'auto_snapshot_schedule.in' => 'O agendamento de snapshot automático deve ser: daily, weekly ou monthly.',
            'auto_snapshot_retention.min' => 'O período de retenção deve ser no mínimo 1 dia.',
            'auto_snapshot_retention.max' => 'O período de retenção deve ser no máximo 30 dias.',
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
            'name' => 'Nome do snapshot',
            'description' => 'Descrição do snapshot',
            'parent_snapshot' => 'Snapshot pai',
            'snapshot_type' => 'Tipo de snapshot',
            'compression' => 'Compressão',
            'cleanup_after_days' => 'Limpar após dias',
            'cleanup_policy' => 'Política de limpeza',
            'storage' => 'Armazenamento',
            'max_snapshots' => 'Máximo de snapshots',
            'tags' => 'Tags',
            'metadata' => 'Metadados',
            'description_format' => 'Formato da descrição',
            'notification_enabled' => 'Notificação habilitada',
            'notification_channel' => 'Canal de notificação',
            'auto_snapshot' => 'Snapshot automático',
            'auto_snapshot_schedule' => 'Agendamento automático',
            'auto_snapshot_retention' => 'Retenção automática',
            'skip_if_running' => 'Pular se estiver rodando',
            'force_stop' => 'Forçar parada',
            'memory_state' => 'Salvar estado da memória',
        ];
    }

    /**
     * Configure the validator instance.
     */
    public function withValidator($validator)
    {
        $validator->after(function ($validator) {
            // Validação de integridade do snapshot
            $this->validateSnapshotIntegrity($validator);

            // Validação de configuração de snapshot
            $this->validateSnapshotConfig($validator);

            // Validação de políticas de retenção
            $this->validateRetentionPolicy($validator);

            // Validação de configuração de notificação
            $this->validateNotificationConfig($validator);

            // Validação de metadados
            $this->validateMetadata($validator);
        });
    }

    /**
     * Validar integridade do snapshot
     */
    protected function validateSnapshotIntegrity($validator): void
    {
        $vmid = $this->input('vmid');
        $name = $this->input('name');
        $parentSnapshot = $this->input('parent_snapshot');
        $skipIfRunning = $this->input('skip_if_running');
        $forceStop = $this->input('force_stop');
        $memoryState = $this->input('memory_state');

        // Verificar se snapshot com este nome já existe
        $existingSnapshot = \App\Models\ContainerSnapshot::where('container_id', $vmid)
            ->where('name', $name)
            ->first();

        if ($existingSnapshot) {
            $validator->errors()->add('name', 'Já existe um snapshot com este nome para este container.');
        }

        // Validação de snapshot pai
        if ($parentSnapshot) {
            // Verificar se o snapshot pai existe
            $parentExists = \App\Models\ContainerSnapshot::where('container_id', $vmid)
                ->where('name', $parentSnapshot)
                ->exists();

            if (!$parentExists) {
                $validator->errors()->add('parent_snapshot', 'O snapshot pai não existe.');
            }
        }

        // Validação de snapshot state
        if ($memoryState && !$forceStop) {
            $validator->errors()->add('memory_state', 'Para salvar estado da memória, é necessário forçar parada do container.');
        }

        // Validação de skip/force
        if ($skipIfRunning && $forceStop) {
            $validator->errors()->add('force_stop', 'Não é possível pular se estiver rodando e forçar parada ao mesmo tempo.');
        }
    }

    /**
     * Validar configuração de snapshot
     */
    protected function validateSnapshotConfig($validator): void
    {
        $name = $this->input('name');
        $snapshotType = $this->input('snapshot_type');
        $compression = $this->input('compression');
        $storage = $this->input('storage');

        // Validação de nome baseado no tipo
        if ($snapshotType === 'automatic') {
            if (!preg_match('/^auto-\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}$/', $name)) {
                $validator->errors()->add('name', 'Para snapshots automáticos, use o formato: auto-YYYY-MM-DD_HH-mm-ss');
            }
        } elseif ($snapshotType === 'backup') {
            if (!preg_match('/^backup-\d{4}-\d{2}-\d{2}$/', $name)) {
                $validator->errors()->add('name', 'Para snapshots de backup, use o formato: backup-YYYY-MM-DD');
            }
        }

        // Validação de compressão baseada no tipo
        if ($snapshotType === 'backup' && !$compression) {
            $validator->errors()->add('compression', 'É obrigatório definir compressão para snapshots de backup.');
        }

        // Validação de armazenamento
        if ($storage && !in_array($storage, ['local-zfs', 'local-lvm', 'nfs', 'ceph'])) {
            $validator->errors()->add('storage', 'Armazenamento inválido. Opções: local-zfs, local-lvm, nfs, ceph.');
        }
    }

    /**
     * Validar políticas de retenção
     */
    protected function validateRetentionPolicy($validator): void
    {
        $maxSnapshots = $this->input('max_snapshots');
        $cleanupAfterDays = $this->input('cleanup_after_days');
        $cleanupPolicy = $this->input('cleanup_policy');
        $autoSnapshot = $this->input('auto_snapshot');
        $autoSnapshotRetention = $this->input('auto_snapshot_retention');

        // Validação de snapshots máximos
        if ($maxSnapshots) {
            $currentCount = \App\Models\ContainerSnapshot::where('container_id', $this->input('vmid'))->count();
            if ($currentCount >= $maxSnapshots) {
                $validator->errors()->add('max_snapshots', 'Número máximo de snapshots atingido. Limpe snapshots existentes primeiro.');
            }
        }

        // Validação de política de limpeza
        if ($cleanupPolicy && $cleanupAfterDays) {
            if ($cleanupPolicy === 'custom' && !$this->input('custom_cleanup_criteria')) {
                $validator->errors()->add('custom_cleanup_criteria', 'Para política custom, é necessário definir critérios de limpeza.');
            }
        }

        // Validação de retenção automática
        if ($autoSnapshot && $autoSnapshotRetention) {
            if ($autoSnapshotRetention < 1 || $autoSnapshotRetention > 30) {
                $validator->errors()->add('auto_snapshot_retention', 'A retenção automática deve ser entre 1 e 30 dias.');
            }
        }
    }

    /**
     * Validar configuração de notificação
     */
    protected function validateNotificationConfig($validator): void
    {
        $notificationEnabled = $this->input('notification_enabled');
        $notificationChannel = $this->input('notification_channel');

        if ($notificationEnabled && !$notificationChannel) {
            $validator->errors()->add('notification_channel', 'É necessário definir um canal de notificação.');
        }

        // Validação de canal de notificação
        if ($notificationChannel) {
            $validChannels = ['email', 'slack', 'webhook', 'telegram'];
            if (!in_array($notificationChannel, $validChannels)) {
                $validator->errors()->add('notification_channel', 'Canal de notificação inválido. Opções: email, slack, webhook, telegram.');
            }
        }
    }

    /**
     * Validar metadados
     */
    protected function validateMetadata($validator): void
    {
        $metadata = $this->input('metadata');
        $descriptionFormat = $this->input('description_format');

        if ($metadata && $descriptionFormat === 'json') {
            json_decode(json_encode($metadata));
            if (json_last_error() !== JSON_ERROR_NONE) {
                $validator->errors()->add('metadata', 'Os metadados devem estar em formato JSON válido.');
            }
        }

        // Validação de tamanho total de metadados
        if ($metadata) {
            $metadataSize = strlen(json_encode($metadata));
            if ($metadataSize > 1024) { // 1KB
                $validator->errors()->add('metadata', 'Os metadados não podem exceder 1KB.');
            }
        }
    }
}
