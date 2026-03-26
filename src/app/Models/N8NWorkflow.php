<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * N8N Workflow Model
 *
 * Represents N8N workflow metadata stored locally for faster access
 * and tracking workflow executions, categories, and associations.
 */
class N8NWorkflow extends Model
{
    use HasFactory, SoftDeletes;

    protected $table = 'n8n_workflows';

    protected $fillable = [
        'n8n_id',
        'name',
        'slug',
        'description',
        'active',
        'category',
        'settings',
        'metadata',
        'last_synced_at',
        'last_executed_at',
        'execution_count',
        'tags',
    ];

    protected $casts = [
        'active' => 'boolean',
        'settings' => 'array',
        'metadata' => 'array',
        'tags' => 'array',
        'last_synced_at' => 'datetime',
        'last_executed_at' => 'datetime',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
        'deleted_at' => 'datetime',
        'execution_count' => 'integer',
    ];

    /**
     * Get workflow executions
     */
    public function executions(): HasMany
    {
        return $this->hasMany(N8NWorkflowExecution::class, 'workflow_id');
    }

    /**
     * Scope for active workflows
     */
    public function scopeActive($query)
    {
        return $query->where('active', true);
    }

    /**
     * Scope for inactive workflows
     */
    public function scopeInactive($query)
    {
        return $query->where('active', false);
    }

    /**
     * Scope by category
     */
    public function scopeByCategory($query, string $category)
    {
        return $query->where('category', $category);
    }

    /**
     * Scope by tag
     */
    public function scopeByTag($query, string $tag)
    {
        return $query->whereJsonContains('tags', $tag);
    }

    /**
     * Scope recently synced
     */
    public function scopeRecentlySynced($query)
    {
        return $query->where('last_synced_at', '>=', now()->subHours(24));
    }

    /**
     * Scope frequently used
     */
    public function scopeFrequentlyUsed($query)
    {
        return $query->orderByDesc('execution_count');
    }

    /**
     * Get webhook path for this workflow
     */
    public function getWebhookPath(): string
    {
        return $this->slug ?? str_slug($this->name);
    }

    /**
     * Get webhook URL for this workflow
     */
    public function getWebhookUrl(): string
    {
        $baseUrl = config('n8n.webhook_base_url');

        return rtrim($baseUrl, '/').'/webhook/'.$this->getWebhookPath();
    }

    /**
     * Increment execution count
     */
    public function incrementExecution(): void
    {
        $this->increment('execution_count');
        $this->update(['last_executed_at' => now()]);
    }

    /**
     * Check if workflow is synced recently
     */
    public function isSynced(): bool
    {
        return $this->last_synced_at && $this->last_synced_at->gt(now()->subHours(24));
    }

    /**
     * Get workflow statistics
     */
    public function getStatistics(): array
    {
        return [
            'total_executions' => $this->execution_count,
            'successful_executions' => $this->executions()->where('status', 'success')->count(),
            'failed_executions' => $this->executions()->where('status', 'failed')->count(),
            'last_execution' => $this->last_executed_at?->toIso8601String(),
            'average_duration' => $this->executions()->avg('duration_ms') ?? 0,
        ];
    }

    /**
     * Get execution rate (executions per day)
     */
    public function getExecutionRate(): float
    {
        if (! $this->created_at) {
            return 0;
        }

        $daysSinceCreation = max(1, $this->created_at->diffInDays(now()));

        return round($this->execution_count / $daysSinceCreation, 2);
    }
}
