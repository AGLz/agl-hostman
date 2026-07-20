<?php

namespace App\Jobs\Container;

use App\DTO\ContainerCreateDTO;
use App\Models\LxcContainer;
use App\Services\Container\ContainerLifecycleService;
use App\Services\WebSocket\WebSocketBroadcastService;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Support\Facades\Log;

class ContainerCreateJob implements ShouldQueue
{
    use Queueable;

    protected ContainerCreateDTO $dto;
    protected array $config;

    /**
     * Create a new job instance.
     */
    public function __construct(ContainerCreateDTO $dto, array $config = [])
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
            Log::info('ContainerCreateJob: Iniciando criação de container', [
                'vmid' => $this->dto->vmid,
                'node' => $this->dto->node,
                'hostname' => $this->dto->hostname
            ]);

            // Criar container usando o service existente
            $service = app(ContainerLifecycleService::class);
            $result = $service->createContainer(
                $this->dto->node,
                $this->dto->vmid,
                $this->dto->toArray()
            );

            // Broadcast WebSocket para atualização em tempo real
            $this->broadcastUpdate($result, 'created');

            Log::info('ContainerCreateJob: Container criado com sucesso', [
                'vmid' => $this->dto->vmid,
                'result' => $result
            ]);

        } catch (\Exception $e) {
            Log::error('ContainerCreateJob: Erro na criação do container', [
                'vmid' => $this->dto->vmid,
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString()
            ]);

            // Broadcast de erro
            $this->broadcastError($e->getMessage());

            throw $e;
        }
    }

    /**
     * Broadcast de atualização bem-sucedida
     */
    protected function broadcastUpdate(array $result, string $action): void
    {
        $service = app(WebSocketBroadcastService::class);
        $service->broadcast('container.' . $action, [
            'vmid' => $this->dto->vmid,
            'node' => $this->dto->node,
            'hostname' => $this->dto->hostname,
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
        $service->broadcast('container.create.error', [
            'vmid' => $this->dto->vmid,
            'node' => $this->dto->node,
            'hostname' => $this->dto->hostname,
            'status' => 'error',
            'message' => $message,
            'timestamp' => now()->toISOString()
        ]);
    }
}
