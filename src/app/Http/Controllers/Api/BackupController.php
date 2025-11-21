<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\BackupService;
use App\Jobs\PerformBackup;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\DB;
use OpenApi\Annotations as OA;

class BackupController extends Controller
{
    protected BackupService $backupService;
    
    public function __construct(BackupService $backupService)
    {
        $this->backupService = $backupService;
    }

    /**
     * @OA\Get(
     *     path="/api/backups",
     *     tags={"Backups"},
     *     summary="List all backups",
     *     description="Get list of all available backups",
     *     operationId="listBackups",
     *     security={{"bearerAuth":{}}},
     *     @OA\Response(
     *         response=200,
     *         description="List of backups",
     *         @OA\JsonContent(
     *             @OA\Property(property="backups", type="array", @OA\Items(
     *                 @OA\Property(property="id", type="integer"),
     *                 @OA\Property(property="name", type="string"),
     *                 @OA\Property(property="type", type="string"),
     *                 @OA\Property(property="size", type="integer"),
     *                 @OA\Property(property="path", type="string"),
     *                 @OA\Property(property="created_at", type="string", format="date-time")
     *             )),
     *             @OA\Property(property="count", type="integer")
     *         )
     *     )
     * )
     */
    public function list(Request $request)
    {
        $backups = $this->backupService->listBackups();
        
        return response()->json([
            'backups' => $backups,
            'count' => count($backups),
        ]);
    }

    /**
     * @OA\Post(
     *     path="/api/backups",
     *     tags={"Backups"},
     *     summary="Create a new backup",
     *     description="Create a new backup of specified type",
     *     operationId="createBackup",
     *     security={{"bearerAuth":{}}},
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             required={"type"},
     *             @OA\Property(property="type", type="string", enum={"full", "database", "files", "config"}),
     *             @OA\Property(property="async", type="boolean", default=true),
     *             @OA\Property(property="notify", type="boolean", default=true),
     *             @OA\Property(property="email", type="string", format="email")
     *         )
     *     ),
     *     @OA\Response(
     *         response=202,
     *         description="Backup job queued",
     *         @OA\JsonContent(
     *             @OA\Property(property="message", type="string"),
     *             @OA\Property(property="type", type="string"),
     *             @OA\Property(property="status", type="string")
     *         )
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Backup created synchronously",
     *         @OA\JsonContent(
     *             @OA\Property(property="message", type="string"),
     *             @OA\Property(property="backup", type="object")
     *         )
     *     )
     * )
     */
    public function create(Request $request)
    {
        $request->validate([
            'type' => 'required|in:full,database,files,config',
            'async' => 'boolean',
            'notify' => 'boolean',
            'email' => 'email|nullable',
        ]);
        
        $type = $request->input('type');
        $async = $request->input('async', true);
        $notify = $request->input('notify', true);
        $email = $request->input('email');
        
        if ($async) {
            // Queue the backup job
            dispatch(new PerformBackup($type, $notify, $email));
            
            return response()->json([
                'message' => 'Backup job queued',
                'type' => $type,
                'status' => 'pending',
            ], 202);
        } else {
            // Perform backup synchronously
            $result = $this->backupService->performBackup($type);
            
            if ($result['success']) {
                return response()->json([
                    'message' => 'Backup created successfully',
                    'backup' => $result['backup'],
                ]);
            } else {
                return response()->json([
                    'message' => 'Backup failed',
                    'error' => $result['error'],
                ], 500);
            }
        }
    }

    /**
     * @OA\Post(
     *     path="/api/backups/{id}/restore",
     *     tags={"Backups"},
     *     summary="Restore from backup",
     *     description="Restore system from a specific backup",
     *     operationId="restoreBackup",
     *     security={{"bearerAuth":{}}},
     *     @OA\Parameter(
     *         name="id",
     *         in="path",
     *         description="Backup ID",
     *         required=true,
     *         @OA\Schema(type="integer")
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Restore initiated",
     *         @OA\JsonContent(
     *             @OA\Property(property="message", type="string"),
     *             @OA\Property(property="result", type="object")
     *         )
     *     ),
     *     @OA\Response(
     *         response=404,
     *         description="Backup not found"
     *     )
     * )
     */
    public function restore(Request $request, int $id)
    {
        $backup = DB::table('backups')->find($id);
        
        if (!$backup) {
            return response()->json([
                'message' => 'Backup not found',
            ], 404);
        }
        
        $result = $this->backupService->restoreFromBackup($backup->name);
        
        if ($result['success']) {
            return response()->json([
                'message' => 'Restore initiated',
                'result' => $result,
            ]);
        } else {
            return response()->json([
                'message' => 'Restore failed',
                'error' => $result['message'] ?? 'Unknown error',
            ], 500);
        }
    }

    /**
     * Delete a backup
     */
    public function delete(Request $request, int $id)
    {
        $backup = DB::table('backups')->find($id);
        
        if (!$backup) {
            return response()->json([
                'message' => 'Backup not found',
            ], 404);
        }
        
        // Delete file if exists
        if ($backup->path && file_exists($backup->path)) {
            unlink($backup->path);
        }
        
        // Delete from remote if exists
        if ($backup->remote_path) {
            try {
                Storage::disk(config('backup.remote_disk', 's3'))->delete($backup->remote_path);
            } catch (\Exception $e) {
                // Log but don't fail
            }
        }
        
        // Delete database record
        DB::table('backups')->delete($id);
        
        return response()->json([
            'message' => 'Backup deleted successfully',
        ]);
    }

    /**
     * Download a backup
     */
    public function download(Request $request, int $id)
    {
        $backup = DB::table('backups')->find($id);
        
        if (!$backup) {
            return response()->json([
                'message' => 'Backup not found',
            ], 404);
        }
        
        if ($backup->path && file_exists($backup->path)) {
            return response()->download(
                $backup->path,
                basename($backup->path),
                ['Content-Type' => 'application/zip']
            );
        } elseif ($backup->remote_path) {
            // Stream from remote storage
            $disk = Storage::disk(config('backup.remote_disk', 's3'));
            
            if ($disk->exists($backup->remote_path)) {
                return response()->stream(
                    function () use ($disk, $backup) {
                        echo $disk->get($backup->remote_path);
                    },
                    200,
                    [
                        'Content-Type' => 'application/zip',
                        'Content-Disposition' => 'attachment; filename="' . basename($backup->remote_path) . '"',
                    ]
                );
            }
        }
        
        return response()->json([
            'message' => 'Backup file not found',
        ], 404);
    }
}