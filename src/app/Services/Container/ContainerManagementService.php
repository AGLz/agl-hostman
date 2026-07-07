<?php

namespace App\Services\Container;

use App\Models\LxcContainer;
use App\Models\ContainerBackup;
use App\Models\ContainerMigration;
use App\Models\ContainerSnapshot;
use App\Services\Proxmox\ProxmoxApiService;
use App\Services\WebSocket\WebSocketBroadcastService;
use App\Services\Notification\NotificationService;
use App\Services\Monitoring\ContainerMonitorService;
use App\Services\Cost\ContainerCostService;
use App\Jobs\ContainerCreateJob;
use App\Jobs\ContainerCloneJob;
use App\Jobs\ContainerMigrateJob;
use App\Jobs\ContainerBackupJob;
use App\Jobs\ContainerSnapshotJob;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\DB;
use Carbon\Carbon;

/**
 * Service for managing container lifecycle operations
 */
class ContainerManagementService
{
    protected ProxmoxApiService $proxmoxService;
    protected WebSocketBroadcastService $websocketService;
    protected NotificationService $notificationService;
    protected ContainerMonitorService $monitorService;
    protected ContainerCostService $costService;

    public function __construct(
        ProxmoxApiService $proxmoxService,
        WebSocketBroadcastService $websocketService,
        NotificationService $notificationService,
        ContainerMonitorService $monitorService,
        ContainerCostService $costService
    ) {
        $this->proxmoxService = $proxmoxService;
        $this->websocketService = $websocketService;
        $this->notificationService = $notificationService;
        $this->monitorService = $monitorService;
        $this->costService = $costService;
    }

    /**
     * Create a new container
     */
    public function create(array $data): array
    {
        try {
            DB::beginTransaction();

            // Validate data
            $this->validateContainerData($data);

            // Check if VMID is available
            $this->checkVmIdAvailability($data['vmid']);

            // Create container in Proxmox
            $proxmoxResult = $this->proxmoxService->createContainer($data);

            // Create database record
            $container = LxcContainer::create([
                'vmid' => $data['vmid'],
                'node' => $data['node'],
                'hostname' => $data['hostname'],
                'type' => 'container',
                'status' => 'pending',
                'cores' => $data['cores'],
                'memory_mb' => $data['memory_mb'],
                'disk_size_gb' => $data['disk_size_gb'],
                'template' => $data['template'] ?? null,
                'ostype' => $data['ostype'],
                'features' => json_encode($data['features'] ?? []),
                'config' => json_encode($proxmoxResult),
                'start_on_boot' => $data['start_on_boot'] ?? false,
                'unprivileged' => $data['unprivileged'] ?? false,
                'owner_email' => $data['owner_email'] ?? null,
                'description' => $data['description'] ?? null,
                'cost_center' => $data['cost_center'] ?? null,
            ]);

            DB::commit();

            // Dispatch async job for actual container creation
            ContainerCreateJob::dispatch($container, $data);

            // Broadcast WebSocket event
            $this->websocketService->broadcast('container.create.requested', [
                'vmid' => $container->vmid,
                'hostname' => $container->hostname,
                'node' => $container->node,
                'status' => 'pending',
                'timestamp' => now()->toISOString(),
            ]);

            // Send notification
            $this->notificationService->sendContainerNotification(
                'container.created',
                $container,
                'Container creation initiated',
                "Container {$container->hostname} creation has been initiated."
            );

            Log::info('Container creation initiated', [
                'container_id' => $container->id,
                'vmid' => $container->vmid,
                'hostname' => $container->hostname,
            ]);

            return [
                'success' => true,
                'message' => 'Container creation initiated',
                'data' => [
                    'container_id' => $container->id,
                    'vmid' => $container->vmid,
                    'hostname' => $container->hostname,
                    'status' => 'pending',
                    'estimated_time' => '2-5 minutes',
                ],
            ];

        } catch (\Exception $e) {
            DB::rollBack();

            Log::error('Container creation failed', [
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
                'data' => $data,
            ]);

            return [
                'success' => false,
                'message' => 'Container creation failed: ' . $e->getMessage(),
                'error' => $e->getMessage(),
            ];
        }
    }

    /**
     * Clone an existing container
     */
    public function clone(int $sourceVmid, array $options): array
    {
        try {
            DB::beginTransaction();

            // Get source container
            $sourceContainer = LxcContainer::findOrFail($sourceVmid);

            // Validate options
            $this->validateCloneOptions($sourceContainer, $options);

            // Create target container record
            $targetContainer = LxcContainer::create([
                'vmid' => $options['target_vmid'],
                'node' => $options['node'],
                'hostname' => $options['target_hostname'] ?? $sourceContainer->hostname . '-clone',
                'type' => 'container',
                'status' => 'pending',
                'cores' => $options['cores'] ?? $sourceContainer->cores,
                'memory_mb' => $options['memory_mb'] ?? $sourceContainer->memory_mb,
                'disk_size_gb' => $options['disk_size_gb'] ?? $sourceContainer->disk_size_gb,
                'template' => $options['template'] ?? 'linked-clone',
                'ostype' => $sourceContainer->ostype,
                'features' => json_encode($sourceContainer->features),
                'source_vmid' => $sourceVmid,
                'start_on_boot' => $options['start_on_boot'] ?? $sourceContainer->start_on_boot,
                'unprivileged' => $options['unprivileged'] ?? $sourceContainer->unprivileged,
                'owner_email' => $options['owner_email'] ?? $sourceContainer->owner_email,
                'description' => $options['description'] ?? $sourceContainer->description,
                'cost_center' => $options['cost_center'] ?? $sourceContainer->cost_center,
            ]);

            DB::commit();

            // Dispatch async job
            ContainerCloneJob::dispatch($sourceContainer, $targetContainer, $options);

            // Broadcast WebSocket event
            $this->websocketService->broadcast('container.clone.requested', [
                'source_vmid' => $sourceVmid,
                'target_vmid' => $targetContainer->vmid,
                'source_hostname' => $sourceContainer->hostname,
                'target_hostname' => $targetContainer->hostname,
                'clone_mode' => $options['clone_mode'] ?? 'full',
                'status' => 'pending',
                'timestamp' => now()->toISOString(),
            ]);

            // Send notification
            $this->notificationService->sendContainerNotification(
                'container.cloned',
                $targetContainer,
                'Container clone initiated',
                "Clone of {$sourceContainer->hostname} has been initiated."
            );

            Log::info('Container clone initiated', [
                'source_vmid' => $sourceVmid,
                'target_vmid' => $targetContainer->vmid,
            ]);

            return [
                'success' => true,
                'message' => 'Container clone initiated',
                'data' => [
                    'source_vmid' => $sourceVmid,
                    'target_vmid' => $targetContainer->vmid,
                    'clone_mode' => $options['clone_mode'] ?? 'full',
                    'status' => 'pending',
                    'estimated_time' => '5-15 minutes',
                ],
            ];

        } catch (\Exception $e) {
            DB::rollBack();

            Log::error('Container clone failed', [
                'error' => $e->getMessage(),
                'source_vmid' => $sourceVmid,
                'options' => $options,
            ]);

            return [
                'success' => false,
                'message' => 'Container clone failed: ' . $e->getMessage(),
                'error' => $e->getMessage(),
            ];
        }
    }

    /**
     * Migrate a container to another node
     */
    public function migrate(int $containerId, array $options): array
    {
        try {
            DB::beginTransaction();

            $container = LxcContainer::findOrFail($containerId);

            // Validate migration options
            $this->validateMigrationOptions($container, $options);

            // Create migration record
            $migration = ContainerMigration::create([
                'container_id' => $container->id,
                'source_server_id' => $container->node,
                'target_server_id' => $options['target_node'],
                'status' => 'pending',
                'progress' => 0,
                'online' => $options['online'] ?? false,
                'total_mb' => $options['total_mb'] ?? $container->disk_size_gb * 1024,
                'estimated_seconds' => $options['estimated_seconds'] ?? 3600,
                'metadata' => json_encode([
                    'migration_mode' => $options['migration_mode'] ?? 'online',
                    'compression' => $options['compression'] ?? 'zstd',
                    'source_hostname' => $container->hostname,
                    'target_hostname' => $options['target_hostname'] ?? $container->hostname,
                ])
            ]);

            DB::commit();

            // Dispatch async job
            ContainerMigrateJob::dispatch($container, $migration, $options);

            // Start progress monitoring
            $this->monitorService->startMigrationMonitoring($migration);

            // Broadcast WebSocket event
            $this->websocketService->broadcast('container.migration.requested', [
                'migration_id' => $migration->id,
                'container_vmid' => $container->vmid,
                'source_node' => $container->node,
                'target_node' => $options['target_node'],
                'status' => 'pending',
                'progress' => 0,
                'timestamp' => now()->toISOString(),
            ]);

            // Send notification
            $this->notificationService->sendContainerNotification(
                'container.migrated',
                $container,
                'Container migration initiated',
                "Migration of {$container->hostname} to {$options['target_node']} has been initiated."
            );

            Log::info('Container migration initiated', [
                'container_id' => $container->id,
                'migration_id' => $migration->id,
                'source_node' => $container->node,
                'target_node' => $options['target_node'],
            ]);

            return [
                'success' => true,
                'message' => 'Container migration initiated',
                'data' => [
                    'migration_id' => $migration->id,
                    'container_vmid' => $container->vmid,
                    'source_node' => $container->node,
                    'target_node' => $options['target_node'],
                    'status' => 'pending',
                    'estimated_time' => '30-60 minutes',
                ],
            ];

        } catch (\Exception $e) {
            DB::rollBack();

            Log::error('Container migration failed', [
                'error' => $e->getMessage(),
                'container_id' => $containerId,
                'options' => $options,
            ]);

            return [
                'success' => false,
                'message' => 'Container migration failed: ' . $e->getMessage(),
                'error' => $e->getMessage(),
            ];
        }
    }

    /**
     * Backup a container
     */
    public function backup(int $containerId, array $options): array
    {
        try {
            DB::beginTransaction();

            $container = LxcContainer::findOrFail($containerId);

            // Validate backup options
            $this->validateBackupOptions($container, $options);

            // Create backup record
            $backup = ContainerBackup::create([
                'container_id' => $container->id,
                'storage' => $options['storage'],
                'filename' => $this->generateBackupFilename($container),
                'size_mb' => 0,
                'mode' => $options['mode'],
                'compress' => $options['compress'],
                'status' => 'pending',
                'notes' => $options['notes'] ?? null,
                'metadata' => json_encode([
                    'estimated_size_mb' => $container->disk_size_gb * 1024,
                    'backup_speed_estimate' => $this->estimateBackupSpeed($container, $options),
                    'container_hostname' => $container->hostname,
                    'node' => $container->node,
                ])
            ]);

            DB::commit();

            // Dispatch async job
            ContainerBackupJob::dispatch($container, $backup, $options);

            // Broadcast WebSocket event
            $this->websocketService->broadcast('container.backup.requested', [
                'backup_id' => $backup->id,
                'container_vmid' => $container->vmid,
                'hostname' => $container->hostname,
                'storage' => $backup->storage,
                'filename' => $backup->filename,
                'status' => 'pending',
                'timestamp' => now()->toISOString(),
            ]);

            // Send notification
            $this->notificationService->sendContainerNotification(
                'container.backed_up',
                $container,
                'Container backup initiated',
                "Backup of {$container->hostname} has been initiated."
            );

            Log::info('Container backup initiated', [
                'container_id' => $container->id,
                'backup_id' => $backup->id,
            ]);

            return [
                'success' => true,
                'message' => 'Container backup initiated',
                'data' => [
                    'backup_id' => $backup->id,
                    'container_vmid' => $container->vmid,
                    'hostname' => $container->hostname,
                    'storage' => $backup->storage,
                    'mode' => $backup->mode,
                    'status' => 'pending',
                    'estimated_time' => '5-10 minutes',
                ],
            ];

        } catch (\Exception $e) {
            DB::rollBack();

            Log::error('Container backup failed', [
                'error' => $e->getMessage(),
                'container_id' => $containerId,
                'options' => $options,
            ]);

            return [
                'success' => false,
                'message' => 'Container backup failed: ' . $e->getMessage(),
                'error' => $e->getMessage(),
            ];
        }
    }

    /**
     * Create a snapshot of a container
     */
    public function snapshot(int $containerId, array $options): array
    {
        try {
            DB::beginTransaction();

            $container = LxcContainer::findOrFail($containerId);

            // Validate snapshot options
            $this->validateSnapshotOptions($container, $options);

            // Check if snapshot already exists
            $existingSnapshot = ContainerSnapshot::where('container_id', $container->id)
                ->where('name', $options['name'])
                ->first();

            if ($existingSnapshot) {
                throw new \Exception("Snapshot '{$options['name']}' already exists for this container.");
            }

            // Create snapshot record
            $snapshot = ContainerSnapshot::create([
                'container_id' => $container->id,
                'name' => $options['name'],
                'description' => $options['description'] ?? null,
                'size_mb' => 0,
                'snapshot_type' => $options['snapshot_type'],
                'compression' => $options['compress'],
                'chain_depth' => $this->calculateChainDepth($container->id),
                'metadata' => json_encode([
                    'estimated_size_mb' => $this->estimateSnapshotSize($container),
                    'snapshot_type' => $options['snapshot_type'],
                    'cleanup_after_days' => $options['cleanup_after_days'] ?? 7,
                    'container_hostname' => $container->hostname,
                    'node' => $container->node,
                ])
            ]);

            DB::commit();

            // Dispatch async job
            ContainerSnapshotJob::dispatch($container, $snapshot, $options);

            // Broadcast WebSocket event
            $this->websocketService->broadcast('container.snapshot.requested', [
                'snapshot_id' => $snapshot->id,
                'container_vmid' => $container->vmid,
                'hostname' => $container->hostname,
                'snapshot_name' => $snapshot->name,
                'status' => 'pending',
                'timestamp' => now()->toISOString(),
            ]);

            // Send notification
            $this->notificationService->sendContainerNotification(
                'container.snapshotted',
                $container,
                'Container snapshot created',
                "Snapshot '{$snapshot->name}' has been created for {$container->hostname}."
            );

            Log::info('Container snapshot initiated', [
                'container_id' => $container->id,
                'snapshot_id' => $snapshot->id,
                'snapshot_name' => $snapshot->name,
            ]);

            return [
                'success' => true,
                'message' => 'Container snapshot initiated',
                'data' => [
                    'snapshot_id' => $snapshot->id,
                    'container_vmid' => $container->vmid,
                    'hostname' => $container->hostname,
                    'snapshot_name' => $snapshot->name,
                    'status' => 'pending',
                    'estimated_time' => '1-3 minutes',
                ],
            ];

        } catch (\Exception $e) {
            DB::rollBack();

            Log::error('Container snapshot failed', [
                'error' => $e->getMessage(),
                'container_id' => $containerId,
                'options' => $options,
            ]);

            return [
                'success' => false,
                'message' => 'Container snapshot failed: ' . $e->getMessage(),
                'error' => $e->getMessage(),
            ];
        }
    }

    /**
     * List all containers with filters
     */
    public function list(array $filters = []): \Illuminate\Support\Collection
    {
        $query = LxcContainer::query();

        // Apply filters
        if (isset($filters['node'])) {
            $query->where('node', $filters['node']);
        }

        if (isset($filters['status'])) {
            $query->where('status', $filters['status']);
        }

        if (isset($filters['search'])) {
            $query->where(function ($q) use ($filters) {
                $q->where('hostname', 'like', "%{$filters['search']}%")
                  ->orWhere('description', 'like', "%{$filters['search']}%");
            });
        }

        if (isset($filters['ostype'])) {
            $query->where('ostype', $filters['ostype']);
        }

        // Apply sorting
        $query->orderBy('created_at', 'desc');

        return $query->get();
    }

    /**
     * Find a container by ID
     */
    public function find(int $id): ?LxcContainer
    {
        return LxcContainer::find($id);
    }

    /**
     * Delete a container
     */
    public function delete(int $id): bool
    {
        try {
            $container = LxcContainer::findOrFail($id);

            // Delete from Proxmox first
            $this->proxmoxService->deleteContainer($container->vmid, $container->node);

            // Delete database record
            $container->delete();

            // Send notification
            $this->notificationService->sendContainerNotification(
                'container.deleted',
                $container,
                'Container deleted',
                "Container {$container->hostname} has been deleted."
            );

            Log::info('Container deleted', [
                'container_id' => $id,
                'vmid' => $container->vmid,
            ]);

            return true;

        } catch (\Exception $e) {
            Log::error('Container deletion failed', [
                'error' => $e->getMessage(),
                'container_id' => $id,
            ]);

            return false;
        }
    }

    /**
     * Get container status
     */
    public function getStatus(int $id): array
    {
        try {
            $container = LxcContainer::findOrFail($id);

            $proxmoxStatus = $this->proxmoxService->getContainerStatus($container->vmid, $container->node);

            return [
                'container' => $container->toArray(),
                'proxmox_status' => $proxmoxStatus,
                'last_updated' => now()->toISOString(),
            ];

        } catch (\Exception $e) {
            Log::error('Failed to get container status', [
                'error' => $e->getMessage(),
                'container_id' => $id,
            ]);

            return [
                'error' => $e->getMessage(),
                'last_updated' => now()->toISOString(),
            ];
        }
    }

    /**
     * Get container metrics
     */
    public function getMetrics(int $id): array
    {
        try {
            $container = LxcContainer::findOrFail($id);

            // Get current metrics from monitor service
            $metrics = $this->monitorService->getContainerMetrics($id);

            // Calculate cost
            $cost = $this->costService->calculateContainerCost($id);

            return [
                'metrics' => $metrics,
                'cost' => $cost,
                'calculated_at' => now()->toISOString(),
            ];

        } catch (\Exception $e) {
            Log::error('Failed to get container metrics', [
                'error' => $e->getMessage(),
                'container_id' => $id,
            ]);

            return [
                'error' => $e->getMessage(),
                'calculated_at' => now()->toISOString(),
            ];
        }
    }

    /**
     * Validate container creation data
     */
    protected function validateContainerData(array $data): void
    {
        $required = ['vmid', 'node', 'hostname', 'cores', 'memory_mb', 'disk_size_gb', 'ostype'];

        foreach ($required as $field) {
            if (empty($data[$field])) {
                throw new \InvalidArgumentException("Field '{$field}' is required");
            }
        }

        // Validate VMID range
        if ($data['vmid'] < 100 || $data['vmid'] > 999999999) {
            throw new \InvalidArgumentException('VMID must be between 100 and 999,999,999');
        }

        // Validate hostname format
        if (!preg_match('/^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$/', $data['hostname'])) {
            throw new \InvalidArgumentException('Hostname must follow RFC 1123 format');
        }

        // Validate resource limits
        if ($data['cores'] < 1 || $data['cores'] > 256) {
            throw new \InvalidArgumentException('Cores must be between 1 and 256');
        }

        if ($data['memory_mb'] < 128 || $data['memory_mb'] > 524288) {
            throw new \InvalidArgumentException('Memory must be between 128MB and 512GB');
        }

        if ($data['disk_size_gb'] < 1 || $data['disk_size_gb'] > 16384) {
            throw new \InvalidArgumentException('Disk size must be between 1GB and 16TB');
        }
    }

    /**
     * Check VMID availability
     */
    protected function checkVmIdAvailability(int $vmid): void
    {
        $exists = LxcContainer::where('vmid', $vmid)->exists();
        if ($exists) {
            throw new \InvalidArgumentException("VMID {$vmid} is already in use");
        }
    }

    /**
     * Validate clone options
     */
    protected function validateCloneOptions(LxcContainer $sourceContainer, array $options): void
    {
        $required = ['target_vmid', 'node', 'clone_mode'];

        foreach ($required as $field) {
            if (empty($options[$field])) {
                throw new \InvalidArgumentException("Field '{$field}' is required for cloning");
            }
        }

        // Validate VMID
        if ($sourceContainer->vmid === $options['target_vmid']) {
            throw new \InvalidArgumentException('Target VMID must be different from source VMID');
        }

        // Validate clone mode
        if (!in_array($options['clone_mode'], ['full', 'linked'])) {
            throw new \InvalidArgumentException('Clone mode must be either "full" or "linked"');
        }
    }

    /**
     * Validate migration options
     */
    protected function validateMigrationOptions(LxcContainer $container, array $options): void
    {
        $required = ['target_node'];

        foreach ($required as $field) {
            if (empty($options[$field])) {
                throw new \InvalidArgumentException("Field '{$field}' is required for migration");
            }
        }

        if ($container->node === $options['target_node']) {
            throw new \InvalidArgumentException('Target node must be different from source node');
        }
    }

    /**
     * Validate backup options
     */
    protected function validateBackupOptions(LxcContainer $container, array $options): void
    {
        $required = ['storage', 'mode', 'compress'];

        foreach ($required as $field) {
            if (empty($options[$field])) {
                throw new \InvalidArgumentException("Field '{$field}' is required for backup");
            }
        }

        // Validate backup mode
        if (!in_array($options['mode'], ['snapshot', 'suspend', 'stop'])) {
            throw new \InvalidArgumentException('Backup mode must be "snapshot", "suspend", or "stop"');
        }

        // Validate compression
        if (!in_array($options['compress'], ['none', 'lzo', 'gzip', 'zstd'])) {
            throw new \InvalidArgumentException('Compression must be "none", "lzo", "gzip", or "zstd"');
        }
    }

    /**
     * Validate snapshot options
     */
    protected function validateSnapshotOptions(LxcContainer $container, array $options): void
    {
        $required = ['name', 'snapshot_type'];

        foreach ($required as $field) {
            if (empty($options[$field])) {
                throw new \InvalidArgumentException("Field '{$field}' is required for snapshot");
            }
        }

        // Validate snapshot name
        if (!preg_match('/^[a-zA-Z0-9][a-zA-Z0-9_-]*[a-zA-Z0-9]$/', $options['name'])) {
            throw new \InvalidArgumentException('Snapshot name must be alphanumeric with underscores and hyphens');
        }

        if (strlen($options['name']) > 40) {
            throw new \InvalidArgumentException('Snapshot name must be 40 characters or less');
        }

        // Validate snapshot type
        if (!in_array($options['snapshot_type'], ['manual', 'automatic', 'backup'])) {
            throw new \InvalidArgumentException('Snapshot type must be "manual", "automatic", or "backup"');
        }
    }

    /**
     * Generate backup filename
     */
    protected function generateBackupFilename(LxcContainer $container): string
    {
        $timestamp = now()->format('Y-m-d_H-i-s');
        return "backup_{$container->hostname}_{$timestamp}.vma.zst";
    }

    /**
     * Estimate backup speed
     */
    protected function estimateBackupSpeed(LxcContainer $container, array $options): float
    {
        $baseSpeed = 100; // MB/min
        $sizeMultiplier = min($container->disk_size_gb / 1000, 10);
        $modeMultiplier = match($options['mode']) {
            'snapshot' => 1.5,
            'suspend' => 1.2,
            'stop' => 1.0,
            default => 1.0
        };

        return $baseSpeed * $sizeMultiplier * $modeMultiplier;
    }

    /**
     * Estimate snapshot size
     */
    protected function estimateSnapshotSize(LxcContainer $container): int
    {
        $baseSize = $container->disk_size_gb * 1024; // MB
        $overhead = (int)($baseSize * 0.2); // 20% overhead
        return $baseSize + $overhead;
    }

    /**
     * Calculate snapshot chain depth
     */
    protected function calculateChainDepth(int $containerId): int
    {
        $depth = ContainerSnapshot::where('container_id', $containerId)
            ->where('parent_name', '!=', null)
            ->count();

        return min($depth + 1, 10); // Limit to 10 to prevent infinite loops
    }
}