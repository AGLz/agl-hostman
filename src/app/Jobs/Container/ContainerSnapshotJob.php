<?php

namespace App\Jobs\Container;

use App\DTO\SnapshotDTO;
use App\Models\ContainerSnapshot;
use App\Models\LxcContainer;
use App\Services\Container\ContainerLifecycleService;
use App\Services\WebSocket\WebSocketBroadcastService;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Support\Facades\Log;

class ContainerSnapshotJob implements ShouldQueue
{
    use Queueable;

    protected SnapshotDTO $dto;
    protected array $config;

    /**
     * Create a new job instance.
     */
    public function __construct(SnapshotDTO $dto, array $config = [])
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
            Log::info('ContainerSnapshotJob: Iniciando snapshot do container', [
                'vmid' => $this->dto->vmid,
                'node' => $this->dto->node,
                'snapshot_name' => $this->dto->name,
                'description' => $this->dto->description
            ]);

            $container = LxcContainer::findOrFail($this->dto->vmid);

            // Verificar se snapshot já existe
            $existingSnapshot = ContainerSnapshot::where('container_id', $container->id)
                ->where('name', $this->dto->name)
                ->first();

            if ($existingSnapshot) {
                throw new \Exception("Snapshot '{$this->dto->name}' já existe para este container");
            }

            // Criar registro do snapshot
            $snapshot = $this->createSnapshotRecord();

            // Realizar snapshot usando o service existente
            $service = app(ContainerLifecycleService::class);
            $result = $service->snapshotContainer(
                $this->dto->node,
                $this->dto->vmid,
                $this->dto->name,
                $this->dto->toArray()
            );

            // Calcular tamanho do snapshot
            $snapshotSize = $result['size_mb'] ?? 0;

            // Atualizar snapshot com resultado
            $snapshot->update([
                'size_mb' => $snapshotSize,
                'parent_name' => $result['parent_name'] ?? null,
                'config' => json_encode($result['config'] ?? []),
                'metadata' => json_encode([
                    'snapshot_speed_mb_per_min' => $result['speed_mb_per_min'] ?? 0,
                    'creation_timestamp' => now()->toISOString(),
                    'container_hostname' => $container->hostname,
                    'node' => $this->dto->node
                ])
            ]);

            // Broadcast WebSocket para atualização
            $this->broadcastUpdate($snapshot, 'created');

            Log::info('ContainerSnapshotJob: Snapshot criado com sucesso', [
                'vmid' => $this->dto->vmid,
                'snapshot_id' => $snapshot->id,
                'snapshot_name' => $snapshot->name,
                'size_mb' => $snapshotSize,
                'result' => $result
            ]);

        } catch (\Exception $e) {
            Log::error('ContainerSnapshotJob: Erro na criação do snapshot', [
                'vmid' => $this->dto->vmid,
                'snapshot_name' => $this->dto->name,
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString()
            ]);

            // Atualizar snapshot para falhado
            if (isset($snapshot)) {
                $snapshot->update([
                    'error_message' => $e->getMessage()
                ]);
            }

            // Broadcast de erro
            $this->broadcastError($e->getMessage());

            throw $e;
        }
    }

    /**
     * Criar registro do snapshot
     */
    protected function createSnapshotRecord(): ContainerSnapshot
    {
        $container = LxcContainer::findOrFail($this->dto->vmid);

        // Verificar chain depth
        $chainDepth = $this->calculateChainDepth();

        return ContainerSnapshot::create([
            'container_id' => $container->id,
            'name' => $this->dto->name,
            'description' => $this->dto->description,
            'size_mb' => 0,
            'parent_name' => null,
            'chain_depth' => $chainDepth,
            'metadata' => json_encode([
                'estimated_size_mb' => $this->estimateSnapshotSize(),
                'snapshot_type' => $this->dto->snapshotType,
                'cleanup_after_days' => $this->dto->cleanupAfterDays,
                'creation_timestamp' => now()->toISOString(),
                'container_hostname' => $container->hostname,
                'node' => $this->dto->node
            ])
        ]);
    }

    /**
     * Calcular profundidade da chain de snapshots
     */
    protected function calculateChainDepth(): int
    {
        $depth = ContainerSnapshot::where('container_id', $this->dto->vmid)
            ->where('parent_name', '!=', null)
            ->count();

        // Limitar a 10 snapshots na chain para evitar loops infinitos
        return min($depth + 1, 10);
    }

    /**
     * Estimar tamanho do snapshot
     */
    protected function estimateSnapshotSize(): int
    {
        $container = LxcContainer::findOrFail($this->dto->vmid);

        // Base size + 20% para metadados e variações
        $baseSize = $container->disk_size_gb * 1024; // MB
        $metadataOverhead = (int)($baseSize * 0.2); // 20% overhead

        return $baseSize + $metadataOverhead;
    }

    /**
     * Broadcast de atualização bem-sucedida
     */
    protected function broadcastUpdate(ContainerSnapshot $snapshot, string $action): void
    {
        $service = app(WebSocketBroadcastService::class);
        $service->broadcast('container.snapshot.' . $action, [
            'snapshot_id' => $snapshot->id,
            'container_vmid' => $snapshot->container_id,
            'node' => $snapshot->container->node,
            'hostname' => $snapshot->container->hostname,
            'snapshot_name' => $snapshot->name,
            'snapshot_description' => $snapshot->description,
            'size_mb' => $snapshot->size_mb,
            'parent_name' => $snapshot->parent_name,
            'chain_depth' => $snapshot->chain_depth,
            'age_days' => $snapshot->getAgeDays(),
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
        $service->broadcast('container.snapshot.error', [
            'vmid' => $this->dto->vmid,
            'node' => $this->dto->node,
            'snapshot_name' => $this->dto->name,
            'status' => 'error',
            'message' => $message,
            'timestamp' => now()->toISOString()
        ]);
    }
}
