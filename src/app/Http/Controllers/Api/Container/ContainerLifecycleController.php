<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\Container;

use App\Http\Controllers\Controller;
use App\Services\Container\ContainerLifecycleService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

/**
 * Container Lifecycle API Controller
 *
 * RESTful API for container lifecycle operations
 */
class ContainerLifecycleController extends Controller
{
    public function __construct(
        private ContainerLifecycleService $lifecycle
    ) {}

    /**
     * Create new container
     * POST /api/containers/create
     */
    public function create(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'node' => 'required|string',
            'vmid' => 'required|integer|min:100|max:999999',
            'hostname' => 'required|string|regex:/^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$/',
            'ostemplate' => 'nullable|string',
            'cores' => 'nullable|integer|min:1|max:128',
            'memory' => 'nullable|integer|min:512|max:524288',
            'rootfs' => 'nullable|string',
            'net0' => 'nullable|string',
            'unprivileged' => 'nullable|boolean',
            'start' => 'nullable|boolean',
        ]);

        $result = $this->lifecycle->createContainer(
            node: $validated['node'],
            vmid: $validated['vmid'],
            config: $validated
        );

        return response()->json($result, $result['success'] ? 201 : 500);
    }

    /**
     * Clone container
     * POST /api/containers/{vmid}/clone
     */
    public function clone(Request $request, int $vmid): JsonResponse
    {
        $validated = $request->validate([
            'node' => 'required|string',
            'new_vmid' => 'required|integer|min:100|max:999999',
            'hostname' => 'nullable|string',
            'full' => 'nullable|boolean',
            'storage' => 'nullable|string',
        ]);

        $result = $this->lifecycle->cloneContainer(
            node: $validated['node'],
            vmid: $vmid,
            newVmid: $validated['new_vmid'],
            options: $validated
        );

        return response()->json($result, $result['success'] ? 200 : 500);
    }

    /**
     * Migrate container
     * POST /api/containers/{vmid}/migrate
     */
    public function migrate(Request $request, int $vmid): JsonResponse
    {
        $validated = $request->validate([
            'source_node' => 'required|string',
            'target_node' => 'required|string|different:source_node',
            'online' => 'nullable|boolean',
            'restart' => 'nullable|boolean',
        ]);

        $result = $this->lifecycle->migrateContainer(
            sourceNode: $validated['source_node'],
            targetNode: $validated['target_node'],
            vmid: $vmid,
            options: $validated
        );

        return response()->json($result, $result['success'] ? 200 : 500);
    }

    /**
     * Backup container
     * POST /api/containers/{vmid}/backup
     */
    public function backup(Request $request, int $vmid): JsonResponse
    {
        $validated = $request->validate([
            'node' => 'required|string',
            'mode' => 'nullable|in:snapshot,suspend,stop',
            'compress' => 'nullable|in:0,1,gzip,lzo,zstd',
            'storage' => 'nullable|string',
            'remove' => 'nullable|boolean',
        ]);

        $result = $this->lifecycle->backupContainer(
            node: $validated['node'],
            vmid: $vmid,
            options: $validated
        );

        return response()->json($result, $result['success'] ? 200 : 500);
    }

    /**
     * Restore container
     * POST /api/containers/restore
     */
    public function restore(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'node' => 'required|string',
            'storage' => 'required|string',
            'volume' => 'required|string',
            'vmid' => 'required|integer|min:100|max:999999',
            'force' => 'nullable|boolean',
        ]);

        $result = $this->lifecycle->restoreContainer(
            node: $validated['node'],
            storage: $validated['storage'],
            volume: $validated['volume'],
            vmid: $validated['vmid'],
            options: $validated
        );

        return response()->json($result, $result['success'] ? 201 : 500);
    }

    /**
     * Create snapshot
     * POST /api/containers/{vmid}/snapshot
     */
    public function snapshot(Request $request, int $vmid): JsonResponse
    {
        $validated = $request->validate([
            'node' => 'required|string',
            'snapname' => 'required|string|regex:/^[a-zA-Z0-9_-]+$/',
            'description' => 'nullable|string|max:255',
        ]);

        $result = $this->lifecycle->snapshotContainer(
            node: $validated['node'],
            vmid: $vmid,
            snapname: $validated['snapname'],
            options: $validated
        );

        return response()->json($result, $result['success'] ? 201 : 500);
    }

    /**
     * Rollback to snapshot
     * POST /api/containers/{vmid}/rollback
     */
    public function rollback(Request $request, int $vmid): JsonResponse
    {
        $validated = $request->validate([
            'node' => 'required|string',
            'snapname' => 'required|string',
        ]);

        $result = $this->lifecycle->rollbackContainer(
            node: $validated['node'],
            vmid: $vmid,
            snapname: $validated['snapname']
        );

        return response()->json($result, $result['success'] ? 200 : 500);
    }

    /**
     * List snapshots
     * GET /api/containers/{vmid}/snapshots
     */
    public function listSnapshots(Request $request, int $vmid): JsonResponse
    {
        $validated = $request->validate([
            'node' => 'required|string',
        ]);

        $result = $this->lifecycle->listSnapshots(
            node: $validated['node'],
            vmid: $vmid
        );

        return response()->json($result, $result['success'] ? 200 : 500);
    }

    /**
     * List backups
     * GET /api/containers/backups
     */
    public function listBackups(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'node' => 'required|string',
            'storage' => 'nullable|string',
        ]);

        $result = $this->lifecycle->listBackups(
            node: $validated['node'],
            storage: $validated['storage'] ?? 'local'
        );

        return response()->json($result, $result['success'] ? 200 : 500);
    }
}
