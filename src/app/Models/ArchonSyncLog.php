<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ArchonSyncLog extends Model
{
    protected $table = 'archon_sync_log';

    protected $fillable = [
        'entity_type',
        'entity_id',
        'action',
        'direction',
        'status',
        'error_message',
        'metadata',
        'synced_at',
    ];

    protected $casts = [
        'metadata' => 'array',
        'synced_at' => 'datetime',
    ];

    public function isSuccess(): bool
    {
        return $this->status === 'success';
    }

    public function isFailed(): bool
    {
        return $this->status === 'failed';
    }

    public function isPending(): bool
    {
        return $this->status === 'pending';
    }

    public static function logSync(
        string $entityType,
        string $entityId,
        string $action,
        string $direction,
        string $status,
        ?string $errorMessage = null,
        ?array $metadata = null
    ): self {
        return self::create([
            'entity_type' => $entityType,
            'entity_id' => $entityId,
            'action' => $action,
            'direction' => $direction,
            'status' => $status,
            'error_message' => $errorMessage,
            'metadata' => $metadata,
            'synced_at' => now(),
        ]);
    }
}
