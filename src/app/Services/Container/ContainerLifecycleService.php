<?php

declare(strict_types=1);

namespace App\Services\Container;

use App\Services\Proxmox\ProxmoxApiClient;
use App\Services\Broadcasting\WebSocketBroadcastService;
use App\Events\ContainerStatusChanged;
use Illuminate\Support\Facades\Log;

/**
 * Container Lifecycle Management Service
 *
 * Handles all 7 container lifecycle operations:
 * 1. Create - Create new LXC container
 * 2. Clone - Clone existing container
 * 3. Migrate - Migrate container between nodes
 * 4. Backup - Create container backup
 * 5. Restore - Restore container from backup
 * 6. Snapshot - Create container snapshot
 * 7. Rollback - Rollback to snapshot
 */
class ContainerLifecycleService
{
    public function __construct(
        private ProxmoxApiClient $proxmox,
        private WebSocketBroadcastService $broadcast
    ) {}

    /**
     * Operation 1: Create new LXC container
     *
     * @param string $node Node name (e.g., 'AGLSRV1')
     * @param int $vmid Container ID
     * @param array $config Container configuration
     * @return array Operation result with task ID
     */
    public function createContainer(string $node, int $vmid, array $config): array
    {
        Log::info("Creating container", ['node' => $node, 'vmid' => $vmid]);

        try {
            // Validate required configuration
            $this->validateContainerConfig($config);

            // Create container via Proxmox API
            $response = $this->proxmox->post("/nodes/{$node}/lxc", array_merge([
                'vmid' => $vmid,
                'ostemplate' => $config['ostemplate'] ?? 'local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst',
                'hostname' => $config['hostname'] ?? "ct{$vmid}",
                'cores' => $config['cores'] ?? 2,
                'memory' => $config['memory'] ?? 2048,
                'rootfs' => $config['rootfs'] ?? 'local-lvm:8',
                'net0' => $config['net0'] ?? 'name=eth0,bridge=vmbr0,ip=dhcp',
                'unprivileged' => $config['unprivileged'] ?? 1,
                'start' => $config['start'] ?? 0,
            ], $config));

            // Broadcast status change
            $this->broadcast->broadcastContainerStatus(
                vmid: (string) $vmid,
                name: $config['hostname'] ?? "CT{$vmid}",
                status: 'creating',
                previousStatus: 'none',
                serverCode: $node
            );

            Log::info("Container creation initiated", [
                'vmid' => $vmid,
                'task' => $response['data'] ?? null,
            ]);

            return [
                'success' => true,
                'vmid' => $vmid,
                'task' => $response['data'] ?? null,
                'message' => "Container {$vmid} creation initiated on {$node}",
            ];
        } catch (\Exception $e) {
            Log::error("Container creation failed", [
                'vmid' => $vmid,
                'error' => $e->getMessage(),
            ]);

            return [
                'success' => false,
                'error' => $e->getMessage(),
            ];
        }
    }

    /**
     * Operation 2: Clone existing container
     *
     * @param string $node Source node name
     * @param int $vmid Source container ID
     * @param int $newVmid Target container ID
     * @param array $options Clone options
     * @return array Operation result with task ID
     */
    public function cloneContainer(string $node, int $vmid, int $newVmid, array $options = []): array
    {
        Log::info("Cloning container", [
            'source' => $vmid,
            'target' => $newVmid,
            'node' => $node,
        ]);

        try {
            // Clone container via Proxmox API
            $response = $this->proxmox->post("/nodes/{$node}/lxc/{$vmid}/clone", array_merge([
                'newid' => $newVmid,
                'hostname' => $options['hostname'] ?? "ct{$newVmid}",
                'full' => $options['full'] ?? 1, // Full clone by default
                'storage' => $options['storage'] ?? 'local-lvm',
            ], $options));

            // Broadcast status change for both containers
            $this->broadcast->broadcastContainerStatus(
                vmid: (string) $newVmid,
                name: $options['hostname'] ?? "CT{$newVmid}",
                status: 'cloning',
                previousStatus: 'none',
                serverCode: $node
            );

            Log::info("Container clone initiated", [
                'source' => $vmid,
                'target' => $newVmid,
                'task' => $response['data'] ?? null,
            ]);

            return [
                'success' => true,
                'source_vmid' => $vmid,
                'target_vmid' => $newVmid,
                'task' => $response['data'] ?? null,
                'message' => "Container {$vmid} cloned to {$newVmid} on {$node}",
            ];
        } catch (\Exception $e) {
            Log::error("Container clone failed", [
                'source' => $vmid,
                'target' => $newVmid,
                'error' => $e->getMessage(),
            ]);

            return [
                'success' => false,
                'error' => $e->getMessage(),
            ];
        }
    }

    /**
     * Operation 3: Migrate container between nodes
     *
     * @param string $sourceNode Source node name
     * @param string $targetNode Target node name
     * @param int $vmid Container ID
     * @param array $options Migration options
     * @return array Operation result with task ID
     */
    public function migrateContainer(string $sourceNode, string $targetNode, int $vmid, array $options = []): array
    {
        Log::info("Migrating container", [
            'vmid' => $vmid,
            'source' => $sourceNode,
            'target' => $targetNode,
        ]);

        try {
            // Migrate container via Proxmox API
            $response = $this->proxmox->post("/nodes/{$sourceNode}/lxc/{$vmid}/migrate", array_merge([
                'target' => $targetNode,
                'online' => $options['online'] ?? 0, // Offline migration by default
                'restart' => $options['restart'] ?? 0,
            ], $options));

            // Broadcast status change
            $this->broadcast->broadcastContainerStatus(
                vmid: (string) $vmid,
                name: "CT{$vmid}",
                status: 'migrating',
                previousStatus: 'running',
                serverCode: $sourceNode,
                metrics: [
                    'target_node' => $targetNode,
                    'online' => $options['online'] ?? 0,
                ]
            );

            Log::info("Container migration initiated", [
                'vmid' => $vmid,
                'source' => $sourceNode,
                'target' => $targetNode,
                'task' => $response['data'] ?? null,
            ]);

            return [
                'success' => true,
                'vmid' => $vmid,
                'source_node' => $sourceNode,
                'target_node' => $targetNode,
                'task' => $response['data'] ?? null,
                'message' => "Container {$vmid} migration from {$sourceNode} to {$targetNode} initiated",
            ];
        } catch (\Exception $e) {
            Log::error("Container migration failed", [
                'vmid' => $vmid,
                'error' => $e->getMessage(),
            ]);

            return [
                'success' => false,
                'error' => $e->getMessage(),
            ];
        }
    }

    /**
     * Operation 4: Create container backup
     *
     * @param string $node Node name
     * @param int $vmid Container ID
     * @param array $options Backup options
     * @return array Operation result with task ID
     */
    public function backupContainer(string $node, int $vmid, array $options = []): array
    {
        Log::info("Creating container backup", ['node' => $node, 'vmid' => $vmid]);

        try {
            // Create backup via Proxmox API
            $response = $this->proxmox->post("/nodes/{$node}/vzdump", array_merge([
                'vmid' => $vmid,
                'mode' => $options['mode'] ?? 'snapshot', // snapshot, suspend, stop
                'compress' => $options['compress'] ?? 'zstd',
                'storage' => $options['storage'] ?? 'local',
                'remove' => $options['remove'] ?? 0,
            ], $options));

            Log::info("Container backup initiated", [
                'vmid' => $vmid,
                'task' => $response['data'] ?? null,
            ]);

            return [
                'success' => true,
                'vmid' => $vmid,
                'task' => $response['data'] ?? null,
                'storage' => $options['storage'] ?? 'local',
                'message' => "Backup of container {$vmid} on {$node} initiated",
            ];
        } catch (\Exception $e) {
            Log::error("Container backup failed", [
                'vmid' => $vmid,
                'error' => $e->getMessage(),
            ]);

            return [
                'success' => false,
                'error' => $e->getMessage(),
            ];
        }
    }

    /**
     * Operation 5: Restore container from backup
     *
     * @param string $node Node name
     * @param string $storage Storage name
     * @param string $volume Backup volume ID
     * @param int $vmid Target container ID
     * @param array $options Restore options
     * @return array Operation result with task ID
     */
    public function restoreContainer(string $node, string $storage, string $volume, int $vmid, array $options = []): array
    {
        Log::info("Restoring container from backup", [
            'node' => $node,
            'vmid' => $vmid,
            'volume' => $volume,
        ]);

        try {
            // Restore container via Proxmox API
            $response = $this->proxmox->post("/nodes/{$node}/lxc", array_merge([
                'vmid' => $vmid,
                'ostemplate' => "{$storage}:backup/{$volume}",
                'restore' => 1,
                'force' => $options['force'] ?? 0,
            ], $options));

            // Broadcast status change
            $this->broadcast->broadcastContainerStatus(
                vmid: (string) $vmid,
                name: "CT{$vmid}",
                status: 'restoring',
                previousStatus: 'stopped',
                serverCode: $node,
                metrics: [
                    'backup_volume' => $volume,
                ]
            );

            Log::info("Container restore initiated", [
                'vmid' => $vmid,
                'volume' => $volume,
                'task' => $response['data'] ?? null,
            ]);

            return [
                'success' => true,
                'vmid' => $vmid,
                'volume' => $volume,
                'task' => $response['data'] ?? null,
                'message' => "Container {$vmid} restore from {$volume} initiated",
            ];
        } catch (\Exception $e) {
            Log::error("Container restore failed", [
                'vmid' => $vmid,
                'volume' => $volume,
                'error' => $e->getMessage(),
            ]);

            return [
                'success' => false,
                'error' => $e->getMessage(),
            ];
        }
    }

    /**
     * Operation 6: Create container snapshot
     *
     * @param string $node Node name
     * @param int $vmid Container ID
     * @param string $snapname Snapshot name
     * @param array $options Snapshot options
     * @return array Operation result
     */
    public function snapshotContainer(string $node, int $vmid, string $snapname, array $options = []): array
    {
        Log::info("Creating container snapshot", [
            'node' => $node,
            'vmid' => $vmid,
            'snapname' => $snapname,
        ]);

        try {
            // Create snapshot via Proxmox API
            $response = $this->proxmox->post("/nodes/{$node}/lxc/{$vmid}/snapshot", array_merge([
                'snapname' => $snapname,
                'description' => $options['description'] ?? "Snapshot created at " . now()->toDateTimeString(),
            ], $options));

            Log::info("Container snapshot created", [
                'vmid' => $vmid,
                'snapname' => $snapname,
            ]);

            return [
                'success' => true,
                'vmid' => $vmid,
                'snapname' => $snapname,
                'message' => "Snapshot '{$snapname}' created for container {$vmid}",
            ];
        } catch (\Exception $e) {
            Log::error("Container snapshot failed", [
                'vmid' => $vmid,
                'snapname' => $snapname,
                'error' => $e->getMessage(),
            ]);

            return [
                'success' => false,
                'error' => $e->getMessage(),
            ];
        }
    }

    /**
     * Operation 7: Rollback container to snapshot
     *
     * @param string $node Node name
     * @param int $vmid Container ID
     * @param string $snapname Snapshot name
     * @return array Operation result with task ID
     */
    public function rollbackContainer(string $node, int $vmid, string $snapname): array
    {
        Log::info("Rolling back container to snapshot", [
            'node' => $node,
            'vmid' => $vmid,
            'snapname' => $snapname,
        ]);

        try {
            // Rollback to snapshot via Proxmox API
            $response = $this->proxmox->post("/nodes/{$node}/lxc/{$vmid}/snapshot/{$snapname}/rollback");

            // Broadcast status change
            $this->broadcast->broadcastContainerStatus(
                vmid: (string) $vmid,
                name: "CT{$vmid}",
                status: 'rolling_back',
                previousStatus: 'stopped',
                serverCode: $node,
                metrics: [
                    'snapshot' => $snapname,
                ]
            );

            Log::info("Container rollback initiated", [
                'vmid' => $vmid,
                'snapname' => $snapname,
                'task' => $response['data'] ?? null,
            ]);

            return [
                'success' => true,
                'vmid' => $vmid,
                'snapname' => $snapname,
                'task' => $response['data'] ?? null,
                'message' => "Container {$vmid} rollback to '{$snapname}' initiated",
            ];
        } catch (\Exception $e) {
            Log::error("Container rollback failed", [
                'vmid' => $vmid,
                'snapname' => $snapname,
                'error' => $e->getMessage(),
            ]);

            return [
                'success' => false,
                'error' => $e->getMessage(),
            ];
        }
    }

    /**
     * List container snapshots
     */
    public function listSnapshots(string $node, int $vmid): array
    {
        try {
            $response = $this->proxmox->get("/nodes/{$node}/lxc/{$vmid}/snapshot");

            return [
                'success' => true,
                'snapshots' => $response['data'] ?? [],
            ];
        } catch (\Exception $e) {
            return [
                'success' => false,
                'error' => $e->getMessage(),
            ];
        }
    }

    /**
     * List container backups
     */
    public function listBackups(string $node, string $storage = 'local'): array
    {
        try {
            $response = $this->proxmox->get("/nodes/{$node}/storage/{$storage}/content", [
                'content' => 'backup',
            ]);

            return [
                'success' => true,
                'backups' => $response['data'] ?? [],
            ];
        } catch (\Exception $e) {
            return [
                'success' => false,
                'error' => $e->getMessage(),
            ];
        }
    }

    /**
     * Validate container configuration
     */
    private function validateContainerConfig(array $config): void
    {
        $required = ['hostname'];

        foreach ($required as $field) {
            if (empty($config[$field])) {
                throw new \InvalidArgumentException("Missing required field: {$field}");
            }
        }

        // Validate hostname format
        if (!preg_match('/^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$/', $config['hostname'])) {
            throw new \InvalidArgumentException("Invalid hostname format");
        }
    }
}
