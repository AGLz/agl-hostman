<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ProductionBackupLog extends Model
{
    use HasFactory;

    protected $fillable = [
        'environment_id',
        'backup_type',
        'backup_file',
        'storage_location',
        'file_size_bytes',
        'status',
        'duration_seconds',
        'started_at',
        'completed_at',
        'error_message',
        'backup_metadata',
    ];

    protected $casts = [
        'backup_metadata' => 'array',
        'started_at' => 'datetime',
        'completed_at' => 'datetime',
    ];

    /**
     * Get the environment that owns the backup log.
     */
    public function environment(): BelongsTo
    {
        return $this->belongsTo(Environment::class);
    }

    /**
     * Check if backup is completed successfully.
     */
    public function isSuccessful(): bool
    {
        return $this->status === 'completed' && is_null($this->error_message);
    }

    /**
     * Get human-readable file size.
     */
    public function getFormattedFileSize(): string
    {
        if (! $this->file_size_bytes) {
            return 'N/A';
        }

        $units = ['B', 'KB', 'MB', 'GB', 'TB'];
        $bytes = $this->file_size_bytes;

        for ($i = 0; $bytes > 1024 && $i < count($units) - 1; $i++) {
            $bytes /= 1024;
        }

        return round($bytes, 2).' '.$units[$i];
    }

    /**
     * Get human-readable duration.
     */
    public function getFormattedDuration(): string
    {
        if (! $this->duration_seconds) {
            return 'N/A';
        }

        $minutes = floor($this->duration_seconds / 60);
        $seconds = $this->duration_seconds % 60;

        return $minutes > 0
            ? "{$minutes}m {$seconds}s"
            : "{$seconds}s";
    }
}
