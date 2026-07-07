<?php

namespace App\Jobs\Container;

use App\DTO\ContainerCloneDTO;
use App\Models\LxcContainer;
use App\Services\Container\ContainerLifecycleService;
use App\Services\WebSocket\WebSocketBroadcastService;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Support\Facades\Log;

class ContainerCloneJob implements ShouldQueue
{
    use Queueable;

    protected ContainerCloneDTO $dto;
    protected array $config;

    /**
     * Create a new job instance.
     */
    public function __construct(ContainerCloneDTO $dto, array $config = [])
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
            Log::info('ContainerCloneJob: Iniciando clone de container', [
                'source_vmid' => $this->dto->sourceVmid,
                'target_vmid' => $this->dto->targetVmid,
                'node' => $this->dto->node,
                'clone_mode' => $this->dto->cloneMode
            ]);

            // Clonar container usando o service existente
            $service = app(ContainerLifecycleService::class);
            $result = $service->cloneContainer(
                $this->dto->node,
                $this->dto->sourceVmid,
                $this->dto->targetVmid,
                $this->dto->toArray()
            );

            // Criar registro do container clonado
            $this->createContainerRecord($result);

            // Broadcast WebSocket para atualização em tempo real
            $this->broadcastUpdate($result, 'cloned');

            Log::info('ContainerCloneJob: Container clonado com sucesso', [
                'source_vmid' => $this->dto->sourceVmid,
                'target_vmid' => $this->dto->targetVmid,
                'result' => $result
            ]);

        } catch (\Exception $e) {
            Log::error('ContainerCloneJob: Erro no clone do container', [
                'source_vmid' => $this->dto->sourceVmid,
                'target_vmid' => $this->dto->targetVmid,
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString()
            ]);

            // Broadcast de erro
            $this->broadcastError($e->getMessage());

            throw $e;
        }
    }

    /**
     * Criar registro do container clonado
     */
    protected function createContainerRecord(array $result): void
    {
        LxcContainer::create([
            'vmid' => $this->dto->targetVmid,
            'node' => $this->dto->node,
            'hostname' => $this->dto->targetHostname ?? $this->dto->hostname . '-clone',
            'type' => 'container',
            'status' => 'running',
            'cores' => $this->dto->cores,
            'memory_mb' => $this->dto->memoryMb,
            'disk_size_gb' => $this->dto->diskSizeGb,
            'template' => $this->dto->isLinkedClone ? 'linked-clone' : 'full-clone',
            'features' => $this->dto->features,
            'config' => json_encode($result),
            'source_vmid' => $this->dto->sourceVmid,
        ]);
    }

    /**
     * Broadcast de atualização bem-sucedida
     */
    protected function broadcastUpdate(array $result, string $action): void
    {
        $service = app(WebSocketBroadcastService::class);
        $service->broadcast('container.' . $action, [
            'source_vmid' => $this->dto->sourceVmid,
            'target_vmid' => $this->dto->targetVmid,
            'node' => $this->dto->node,
            'hostname' => $this->dto->targetHostname ?? $this->dto->hostname . '-clone',
            'clone_mode' => $this->dto->cloneMode,
            'status' => 'success',
            'data' => $result,
            'timestamp' => now()->toISOString()
        ]);
    }

    /**
     * Broadcast de erro
     */
    protected function broadcastError(string $message): void
    {
        $service = app(WebSocketBroadcastService::class);
        $service->broadcast('container.clone.error', [
            'source_vmid' => $this->dto->sourceVmid,
            'target_vmid' => $this->dto->targetVmid,
            'node' => $this->dto->node,
            'status' => 'error',
            'message' => $message,
            'timestamp' => now()->toISOString()
        ]);
    }
}
