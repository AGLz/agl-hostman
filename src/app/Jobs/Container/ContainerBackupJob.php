<?php

namespace App\Jobs\Container;

use App\DTO\BackupDTO;
use App\Models\ContainerBackup;
use App\Models\LxcContainer;
use App\Services\Container\ContainerLifecycleService;
use App\Services\WebSocket\WebSocketBroadcastService;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Support\Facades\Log;

class ContainerBackupJob implements ShouldQueue
{
    use Queueable;

    protected BackupDTO $dto;
    protected array $config;

    /**
     * Create a new job instance.
     */
    public function __construct(BackupDTO $dto, array $config = [])
    {
        $this->dto = $dto;
        $this->config = $config;
        $this->onQueue('containers');
    }

    /**
     * Execute the job.
     */
    public function handle(): void
    {
        try {
            Log::info('ContainerBackupJob: Iniciando backup do container', [
                'vmid' => $this->dto->vmid,
                'node' => $this->dto->node,
                'storage' => $this->dto->storage,
                'mode' => $this->dto->mode,
                'compress' => $this->dto->compress
            ]);

            $container = LxcContainer::findOrFail($this->dto->vmid);

            // Criar registro do backup
            $backup = $this->createBackupRecord();

            // Atualizar status para running
            $backup->update(['status' => 'running']);

            // Realizar backup usando o service existente
            $service = app(ContainerLifecycleService::class);
            $result = $service->backupContainer(
                $this->dto->node,
                $this->dto->vmid,
                $this->dto->toArray()
            );

            // Calcular velocidade e tamanho
            $backupSpeed = $this->calculateBackupSpeed($result);
            $backupSize = $result['size_mb'] ?? 0;

            // Atualizar backup com resultado
            $backup->update([
                'status' => 'completed',
                'size_mb' => $backupSize,
                'filename' => $result['filename'] ?? null,
                'task_id' => $result['task_id'] ?? null,
                'metadata' => json_encode([
                    'speed_mb_per_min' => $backupSpeed,
                    'elapsed_minutes' => $this->dto->elapsedMinutes,
                    'compression_ratio' => $this->calculateCompressionRatio($backupSize, $container->disk_size_gb)
                ])
            ]);

            // Broadcast WebSocket para atualização
            $this->broadcastUpdate($backup, 'completed');

            Log::info('ContainerBackupJob: Backup completado com sucesso', [
                'vmid' => $this->dto->vmid,
                'backup_id' => $backup->id,
                'size_mb' => $backupSize,
                'result' => $result
            ]);

        } catch (\Exception $e) {
            Log::error('ContainerBackupJob: Erro no backup do container', [
                'vmid' => $this->dto->vmid,
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString()
            ]);

            // Atualizar backup para falhado
            if (isset($backup)) {
                $backup->update([
                    'status' => 'failed',
                    'error_message' => $e->getMessage()
                ]);
            }

            // Broadcast de erro
            $this->broadcastError($e->getMessage());

            throw $e;
        }
    }

    /**
     * Criar registro do backup
     */
    protected function createBackupRecord(): ContainerBackup
    {
        $container = LxcContainer::findOrFail($this->dto->vmid);

        return ContainerBackup::create([
            'container_id' => $container->id,
            'storage' => $this->dto->storage,
            'filename' => $this->generateBackupFilename(),
            'size_mb' => 0,
            'mode' => $this->dto->mode,
            'compress' => $this->dto->compress,
            'status' => 'pending',
            'task_id' => null,
            'notes' => $this->dto->notes,
            'metadata' => json_encode([
                'estimated_size_mb' => $container->disk_size_gb * 1024,
                'backup_speed_estimate' => $this->estimateBackupSpeed(),
                'container_hostname' => $container->hostname,
                'node' => $this->dto->node
            ])
        ]);
    }

    /**
     * Gerar nome do arquivo de backup
     */
    protected function generateBackupFilename(): string
    {
        $timestamp = now()->format('Y-m-d_H-i-s');
        $container = LxcContainer::findOrFail($this->dto->vmid);
        return "backup_{$container->hostname}_{$timestamp}.vma.zst";
    }

    /**
     * Calcular velocidade do backup
     */
    protected function calculateBackupSpeed(array $result): float
    {
        $sizeMb = $result['size_mb'] ?? 0;
        $elapsedMinutes = $this->dto->elapsedMinutes ?: 1;
        return $elapsedMinutes > 0 ? ($sizeMb / $elapsedMinutes) : 0;
    }

    /**
     * Estimar velocidade do backup
     */
    protected function estimateBackupSpeed(): float
    {
        // Estimativa baseada no tamanho do container e modo de backup
        $baseSpeed = 100; // MB/min base
        $sizeMultiplier = min($this->dto->estimatedSizeMb / 1000, 10); // Até 10x
        $modeMultiplier = match($this->dto->mode) {
            'snapshot' => 1.5, // Snapshot é mais rápido
            'suspend' => 1.2,
            'stop' => 1.0,
            default => 1.0
        };
        return $baseSpeed * $sizeMultiplier * $modeMultiplier;
    }

    /**
     * Calcular taxa de compressão
     */
    protected function calculateCompressionRatio(int $backupSizeMb, float $containerSizeGb): float
    {
        $containerSizeMb = $containerSizeGb * 1024;
        return $containerSizeMb > 0 ? ($backupSizeMb / $containerSizeMb) : 1.0;
    }

    /**
     * Broadcast de atualização bem-sucedida
     */
    protected function broadcastUpdate(ContainerBackup $backup, string $action): void
    {
        $service = app(WebSocketBroadcastService::class);
        $service->broadcast('container.backup.' . $action, [
            'backup_id' => $backup->id,
            'container_vmid' => $backup->container_id,
            'node' => $backup->container->node,
            'hostname' => $backup->container->hostname,
            'storage' => $backup->storage,
            'filename' => $backup->filename,
            'size_mb' => $backup->size_mb,
            'mode' => $backup->mode,
            'compress' => $backup->compress,
            'status' => 'success',
            'timestamp' => now()->toISOString()
        ]);
    }

    /**
     * Broadcast de erro
     */
    protected function broadcastError(string $message): void
    {
        $service = app(WebSocketBroadcastService::class);
        $service->broadcast('container.backup.error', [
            'vmid' => $this->dto->vmid,
            'node' => $this->dto->node,
            'storage' => $this->dto->storage,
            'status' => 'error',
            'message' => $message,
            'timestamp' => now()->toISOString()
        ]);
    }
}
