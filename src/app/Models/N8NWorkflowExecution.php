<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * N8N Workflow Execution Model
 *
 * Tracks individual workflow executions for monitoring,
 * debugging, and analytics purposes.
 */
class N8NWorkflowExecution extends Model
{
    use HasFactory;

    protected $table = 'n8n_workflow_executions';

    protected $fillable = [
        'workflow_id',
        'n8n_execution_id',
        'status',
        'input_data',
        'output_data',
        'error_message',
        'duration_ms',
        'started_at',
        'completed_at',
        'triggered_by',
        'metadata',
    ];

    protected $casts = [
        'input_data' => 'array',
        'output_data' => 'array',
        'metadata' => 'array',
        'duration_ms' => 'integer',
        'started_at' => 'datetime',
        'completed_at' => 'datetime',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    /**
     * Get the workflow that owns this execution
     */
    public function workflow(): BelongsTo
    {
        return $this->belongsTo(N8NWorkflow::class, 'workflow_id');
    }

    /**
     * Scope for successful executions
     */
    public function scopeSuccessful($query)
    {
        return $query->where('status', 'success');
    }

    /**
     * Scope for failed executions
     */
    public function scopeFailed($query)
    {
        return $query->where('status', 'failed');
    }

    /**
     * Scope for running executions
     */
    public function scopeRunning($query)
    {
        return $query->where('status', 'running');
    }

    /**
     * Scope for recent executions
     */
    public function scopeRecent($query, int $days = 7)
    {
        return $query->where('created_at', '>=', now()->subDays($days));
    }

    /**
     * Scope by trigger source
     */
    public function scopeTriggeredBy($query, string $source)
    {
        return $query->where('triggered_by', $source);
    }

    /**
     * Check if execution completed successfully
     */
    public function isSuccessful(): bool
    {
        return $this->status === 'success';
    }

    /**
     * Check if execution failed
     */
    public function isFailed(): bool
    {
        return $this->status === 'failed';
    }

    /**
     * Check if execution is still running
     */
    public function isRunning(): bool
    {
        return $this->status === 'running';
    }

    /**
     * Get duration in human-readable format
     */
    public function getHumanDuration(): string
    {
        if ($this->duration_ms === null) {
            return 'N/A';
        }

        $seconds = $this->duration_ms / 1000;

        if ($seconds < 1) {
            return $this->duration_ms.'ms';
        }

        if ($seconds < 60) {
            return round($seconds, 2).'s';
        }

        $minutes = floor($seconds / 60);
        $remainingSeconds = $seconds % 60;

        return $minutes.'m '.round($remainingSeconds, 0).'s';
    }
}
