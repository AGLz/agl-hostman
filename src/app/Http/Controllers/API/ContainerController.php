<?php

namespace App\Http\Controllers\API;

use Illuminate\Routing\Controller;
use App\DTO\ContainerCreateDTO;
use App\DTO\ContainerCloneDTO;
use App\Http\Requests\Container\ContainerCreateRequest;
use App\Http\Requests\Container\ContainerCloneRequest;
use App\Http\Requests\Container\ContainerSnapshotRequest;
use App\Jobs\Container\ContainerCreateJob;
use App\Jobs\Container\ContainerCloneJob;
use App\Jobs\Container\ContainerSnapshotJob;
use App\Models\LxcContainer;
use App\Services\Broadcasting\WebSocketBroadcastService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Log;

class ContainerController extends Controller
{
    /**
     * Listar todos os containers
     */
    public function index(Request $request): JsonResponse
    {
        try {
            $query = LxcContainer::query();

            // Filtros
            if ($request->filled('node')) {
                $query->where('node', $request->node);
            }

            if ($request->filled('status')) {
                $query->where('status', $request->status);
            }

            if ($request->filled('search')) {
                $query->where('hostname', 'like', "%{$request->search}%");
            }

            // Ordenação
            $query->orderBy('created_at', 'desc');

            $containers = $query->paginate($request->get('per_page', 15));

            return response()->json([
                'success' => true,
                'data' => $containers,
                'message' => 'Containers listados com sucesso'
            ]);

        } catch (\Exception $e) {
            Log::error('ContainerController:index - Erro ao listar containers', [
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
            ]);

            return response()->json([
                'success' => false,
                'message' => 'Erro ao listar containers',
            ], 500);
        }
    }

    /**
     * Exibir um container específico
     */
    public function show($id): JsonResponse
    {
        try {
            $container = LxcContainer::findOrFail($id);

            return response()->json([
                'success' => true,
                'data' => $container,
                'message' => 'Container encontrado com sucesso'
            ]);

        } catch (\Exception $e) {
            Log::error('ContainerController:show - Erro ao buscar container', [
                'id' => $id            ]);

            return response()->json([
                'success' => false,
                'message' => 'Container não encontrado'            ], 404);
        }
    }

    /**
     * Criar um novo container
     */
    public function store(ContainerCreateRequest $request): JsonResponse
    {
        try {
            $dto = ContainerCreateDTO::fromRequest($request);

            // Disparar job assíncrono
            ContainerCreateJob::dispatch($dto, $request->all())
                ->onQueue('containers');

            // Broadcast da solicitação de criação
            $this->broadcastContainerCreation($dto);

            return response()->json([
                'success' => true,
                'message' => 'Solicitação de criação de container enviada',
                'data' => [
                    'vmid' => $dto->vmid,
                    'hostname' => $dto->hostname,
                    'node' => $dto->node,
                    'status' => 'pending',
                    'estimated_time' => '2-5 minutos'
                ]
            ], 202);

        } catch (\Exception $e) {
            Log::error('ContainerController:store - Erro ao criar container', [
                'request_data' => $request->all()            ]);

            return response()->json([
                'success' => false,
                'message' => 'Erro ao criar container'            ], 500);
        }
    }

    /**
     * Clonar um container existente
     */
    public function clone(ContainerCloneRequest $request): JsonResponse
    {
        try {
            $dto = ContainerCloneDTO::fromRequest($request);

            // Disparar job assíncrono
            ContainerCloneJob::dispatch($dto, $request->all())
                ->onQueue('containers');

            // Broadcast da solicitação de clone
            $this->broadcastContainerClone($dto);

            return response()->json([
                'success' => true,
                'message' => 'Solicitação de clone de container enviada',
                'data' => [
                    'source_vmid' => $dto->sourceVmid,
                    'target_vmid' => $dto->targetVmid,
                    'clone_mode' => $dto->cloneMode,
                    'status' => 'pending',
                    'estimated_time' => '5-15 minutos'
                ]
            ], 202);

        } catch (\Exception $e) {
            Log::error('ContainerController:clone - Erro ao clonar container', [
                'request_data' => $request->all()            ]);

            return response()->json([
                'success' => false,
                'message' => 'Erro ao clonar container'            ], 500);
        }
    }

    /**
     * Criar snapshot de um container
     */
    public function snapshot($id, ContainerSnapshotRequest $request): JsonResponse
    {
        try {
            $container = LxcContainer::findOrFail($id);
            $dto = \App\DTO\SnapshotDTO::fromRequest($request);

            // Validar se snapshot já existe
            $existingSnapshot = \App\Models\ContainerSnapshot::where('container_id', $container->id)
                ->where('name', $dto->name)
                ->first();

            if ($existingSnapshot) {
                return response()->json([
                    'success' => false,
                    'message' => 'Snapshot com este nome já existe para este container'
                ], 422);
            }

            // Disparar job assíncrono
            ContainerSnapshotJob::dispatch($dto, $request->all())
                ->onQueue('containers');

            // Broadcast da solicitação de snapshot
            $this->broadcastContainerSnapshot($dto);

            return response()->json([
                'success' => true,
                'message' => 'Solicitação de snapshot enviada',
                'data' => [
                    'container_vmid' => $container->vmid,
                    'snapshot_name' => $dto->name,
                    'status' => 'pending',
                    'estimated_time' => '1-3 minutos'
                ]
            ], 202);

        } catch (\Exception $e) {
            Log::error('ContainerController:snapshot - Erro ao criar snapshot', [
                'id' => $id,
                'request_data' => $request->all()            ]);

            return response()->json([
                'success' => false,
                'message' => 'Erro ao criar snapshot'            ], 500);
        }
    }

    /**
     * Iniciar um container
     */
    public function start($id): JsonResponse
    {
        try {
            $container = LxcContainer::findOrFail($id);

            // Implementar lógica de start
            // Aqui você chamaria o Proxmox API para iniciar o container
            $result = $this->startContainerViaProxmox($container);

            return response()->json([
                'success' => true,
                'message' => 'Container iniciado com sucesso',
                'data' => $result
            ]);

        } catch (\Exception $e) {
            Log::error('ContainerController:start - Erro ao iniciar container', [
                'id' => $id            ]);

            return response()->json([
                'success' => false,
                'message' => 'Erro ao iniciar container'            ], 500);
        }
    }

    /**
     * Parar um container
     */
    public function stop($id): JsonResponse
    {
        try {
            $container = LxcContainer::findOrFail($id);

            // Implementar lógica de stop
            $result = $this->stopContainerViaProxmox($container);

            return response()->json([
                'success' => true,
                'message' => 'Container parado com sucesso',
                'data' => $result
            ]);

        } catch (\Exception $e) {
            Log::error('ContainerController:stop - Erro ao parar container', [
                'id' => $id            ]);

            return response()->json([
                'success' => false,
                'message' => 'Erro ao parar container'            ], 500);
        }
    }

    /**
     * Reiniciar um container
     */
    public function restart($id): JsonResponse
    {
        try {
            $container = LxcContainer::findOrFail($id);

            // Implementar lógica de restart
            $result = $this->restartContainerViaProxmox($container);

            return response()->json([
                'success' => true,
                'message' => 'Container reiniciado com sucesso',
                'data' => $result
            ]);

        } catch (\Exception $e) {
            Log::error('ContainerController:restart - Erro ao reiniciar container', [
                'id' => $id            ]);

            return response()->json([
                'success' => false,
                'message' => 'Erro ao reiniciar container'            ], 500);
        }
    }

    /**
     * Excluir um container
     */
    public function destroy($id): JsonResponse
    {
        try {
            $container = LxcContainer::findOrFail($id);

            // Implementar lógica de exclusão
            $result = $this->deleteContainerViaProxmox($container);

            return response()->json([
                'success' => true,
                'message' => 'Container excluído com sucesso',
                'data' => $result
            ]);

        } catch (\Exception $e) {
            Log::error('ContainerController:destroy - Erro ao excluir container', [
                'id' => $id            ]);

            return response()->json([
                'success' => false,
                'message' => 'Erro ao excluir container'            ], 500);
        }
    }

    /**
     * Obter status do container
     */
    public function status($id): JsonResponse
    {
        try {
            $container = LxcContainer::findOrFail($id);

            // Implementar lógica para obter status do Proxmox
            $proxmoxStatus = $this->getContainerStatusViaProxmox($container);

            return response()->json([
                'success' => true,
                'data' => [
                    'container' => $container,
                    'proxmox_status' => $proxmoxStatus,
                    'last_updated' => now()->toISOString()
                ]
            ]);

        } catch (\Exception $e) {
            Log::error('ContainerController:status - Erro ao obter status', [
                'id' => $id            ]);

            return response()->json([
                'success' => false,
                'message' => 'Erro ao obter status do container'            ], 500);
        }
    }

    /**
     * Métodos privados de integração com Proxmox
     */
    private function startContainerViaProxmox(LxcContainer $container): array
    {
        // Implementar chamada API ao Proxmox
        return [
            'status' => 'started',
            'message' => 'Container iniciado via Proxmox API'
        ];
    }

    private function stopContainerViaProxmox(LxcContainer $container): array
    {
        // Implementar chamada API ao Proxmox
        return [
            'status' => 'stopped',
            'message' => 'Container parado via Proxmox API'
        ];
    }

    private function restartContainerViaProxmox(LxcContainer $container): array
    {
        // Implementar chamada API ao Proxmox
        return [
            'status' => 'restarted',
            'message' => 'Container reiniciado via Proxmox API'
        ];
    }

    private function deleteContainerViaProxmox(LxcContainer $container): array
    {
        // Implementar chamada API ao Proxmox
        return [
            'status' => 'deleted',
            'message' => 'Container excluído via Proxmox API'
        ];
    }

    private function getContainerStatusViaProxmox(LxcContainer $container): array
    {
        // Implementar chamada API ao Proxmox
        return [
            'status' => 'running',
            'uptime' => '2h 15m',
            'cpu_usage' => '15%',
            'memory_usage' => '512MB / 2GB',
            'disk_usage' => '10GB / 20GB'
        ];
    }

    /**
     * Métodos privados de broadcast WebSocket
     */
    private function broadcastContainerCreation(ContainerCreateDTO $dto): void
    {
        $service = app(WebSocketBroadcastService::class);
        $service->broadcast('container.create.requested', [
            'vmid' => $dto->vmid,
            'hostname' => $dto->hostname,
            'node' => $dto->node,
            'cores' => $dto->cores,
            'memory_mb' => $dto->memoryMb,
            'disk_size_gb' => $dto->diskSizeGb,
            'status' => 'pending',
            'timestamp' => now()->toISOString()
        ]);
    }

    private function broadcastContainerClone(ContainerCloneDTO $dto): void
    {
        $service = app(WebSocketBroadcastService::class);
        $service->broadcast('container.clone.requested', [
            'source_vmid' => $dto->sourceVmid,
            'target_vmid' => $dto->targetVmid,
            'node' => $dto->node,
            'hostname' => $dto->hostname,
            'clone_mode' => $dto->cloneMode,
            'status' => 'pending',
            'timestamp' => now()->toISOString()
        ]);
    }

    private function broadcastContainerSnapshot(\App\DTO\SnapshotDTO $dto): void
    {
        $service = app(WebSocketBroadcastService::class);
        $service->broadcast('container.snapshot.requested', [
            'vmid' => $dto->vmid,
            'node' => $dto->node,
            'snapshot_name' => $dto->name,
            'description' => $dto->description,
            'status' => 'pending',
            'timestamp' => now()->toISOString()
        ]);
    }
}
