<?php

namespace App\Jobs\Container;

use App\DTO\MigrationStatusDTO;
use App\Models\ContainerMigration;
use App\Models\LxcContainer;
use App\Models\ProxmoxServer;
use App\Services\Container\ContainerLifecycleService;
use App\Services\WebSocket\WebSocketBroadcastService;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Support\Facades\Log;

class ContainerMigrateJob implements ShouldQueue
{
    use Queueable;

    protected MigrationStatusDTO $dto;
    protected array $config;

    /**
     * Create a new job instance.
     */
    public function __construct(MigrationStatusDTO $dto, array $config = [])
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
            Log::info('ContainerMigrateJob: Iniciando migração de container', [
                'source_vmid' => $this->dto->sourceVmid,
                'target_vmid' => $this->dto->targetVmid,
                'source_node' => $this->dto->sourceNode,
                'target_node' => $this->dto->targetNode
            ]);

            // Criar registro da migração
            $migration = $this->createMigrationRecord();

            // Iniciar migração usando o service existente
            $service = app(ContainerLifecycleService::class);

            // Atualizar status para preparing
            $this->updateMigrationStatus($migration, 'preparing', 0);

            $result = $service->migrateContainer(
                $this->dto->sourceNode,
                $this->dto->targetNode,
                $this->dto->sourceVmid,
                $this->dto->toArray()
            );

            // Atualizar migração para completed
            $this->updateMigrationStatus($migration, 'completed', 100);
            $migration->update([
                'completed_at' => now(),
                'metadata' => json_encode($result)
            ]);

            // Broadcast WebSocket para atualização em tempo real
            $this->broadcastUpdate($migration, 'completed');

            Log::info('ContainerMigrateJob: Container migrado com sucesso', [
                'source_vmid' => $this->dto->sourceVmid,
                'target_vmid' => $this->dto->targetVmid,
                'migration_id' => $migration->id,
                'result' => $result
            ]);

        } catch (\Exception $e) {
            Log::error('ContainerMigrateJob: Erro na migração do container', [
                'source_vmid' => $this->dto->sourceVmid,
                'target_vmid' => $this->dto->targetVmid,
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString()
            ]);

            // Atualizar migração para failed
            if (isset($migration)) {
                $this->updateMigrationStatus($migration, 'failed', 0, $e->getMessage());
            }

            // Broadcast de erro
            $this->broadcastError($e->getMessage());

            throw $e;
        }
    }

    /**
     * Criar registro da migração
     */
    protected function createMigrationRecord(): ContainerMigration
    {
        $container = LxcContainer::findOrFail($this->dto->sourceVmid);
        $sourceServer = ProxmoxServer::where('node', $this->dto->sourceNode)->first();
        $targetServer = ProxmoxServer::where('node', $this->dto->targetNode)->first();

        return ContainerMigration::create([
            'container_id' => $container->id,
            'source_server_id' => $sourceServer->id,
            'target_server_id' => $targetServer->id,
            'status' => 'pending',
            'progress' => 0,
            'online' => false,
            'task_id' => null,
            'transferred_mb' => 0,
            'total_mb' => $this->dto->totalMb,
            'estimated_seconds' => $this->dto->estimatedSeconds,
            'metadata' => json_encode([
                'source_hostname' => $container->hostname,
                'target_hostname' => $container->hostname,
                'migration_mode' => $this->dto->migrationMode,
                'compression' => $this->dto->compression
            ])
        ]);
    }

    /**
     * Atualizar status da migração
     */
    protected function updateMigrationStatus(ContainerMigration $migration, string $status, int $progress, ?string $error = null): void
    {
        $migration->update([
            'status' => $status,
            'progress' => $progress,
            'error_message' => $error,
            'updated_at' => now()
        ]);

        $this->broadcastProgressUpdate($migration, $status, $progress);
    }

    /**
     * Broadcast de atualização de progresso
     */
    protected function broadcastProgressUpdate(ContainerMigration $migration, string $status, int $progress): void
    {
        $service = app(WebSocketBroadcastService::class);
        $service->broadcast('container.migration.progress', [
            'migration_id' => $migration->id,
            'container_vmid' => $migration->container_id,
            'source_node' => $migration->sourceServer->node,
            'target_node' => $migration->targetServer->node,
            'status' => $status,
            'progress' => $progress,
            'percentage' => $progress,
            'timestamp' => now()->toISOString()
        ]);
    }

    /**
     * Broadcast de atualização bem-sucedida
     */
    protected function broadcastUpdate(ContainerMigration $migration, string $action): void
    {
        $service = app(WebSocketBroadcastService::class);
        $service->broadcast('container.' . $action, [
            'migration_id' => $migration->id,
            'container_vmid' => $migration->container_id,
            'source_node' => $migration->sourceServer->node,
            'target_node' => $migration->targetServer->node,
            'status' => 'success',
            'progress' => $migration->progress,
            'timestamp' => now()->toISOString()
        ]);
    }

    /**
     * Broadcast de erro
     */
    protected function broadcastError(string $message): void
    {
        $service = app(WebSocketBroadcastService::class);
        $service->broadcast('container.migration.error', [
            'source_vmid' => $this->dto->sourceVmid,
            'target_vmid' => $this->dto->targetVmid,
            'source_node' => $this->dto->sourceNode,
            'target_node' => $this->dto->targetNode,
            'status' => 'error',
            'message' => $message,
            'timestamp' => now()->toISOString()
        ]);
    }
}
