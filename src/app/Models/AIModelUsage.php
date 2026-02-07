<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * AI Model Usage Model
 *
 * Tracks usage statistics for AI model API calls including:
 * - Token consumption
 * - Request tracking
 * - Cost estimation
 * - User activity
 */
class AIModelUsage extends Model
{
    use HasFactory, HasUuids;

    /**
     * Task types
     */
    public const TASK_PREDICTION = 'prediction';
    public const TASK_ANALYSIS = 'analysis';
    public const TASK_RECOMMENDATION = 'recommendation';
    public const TASK_CHAT = 'chat';
    public const TASK_CODE_GENERATION = 'code_generation';

    /**
     * Providers
     */
    public const PROVIDER_OPENAI = 'openai';
    public const PROVIDER_CLAUDE = 'claude';
    public const PROVIDER_OLLAMA = 'ollama';

    protected $fillable = [
        'user_id',
        'provider',
        'model',
        'task_type',
        'prompt_tokens',
        'completion_tokens',
        'total_tokens',
        'estimated_cost',
        'response_time_ms',
        'status',
        'error_message',
        'metadata',
    ];

    protected $casts = [
        'prompt_tokens' => 'integer',
        'completion_tokens' => 'integer',
        'total_tokens' => 'integer',
        'estimated_cost' => 'decimal:4',
        'response_time_ms' => 'integer',
        'metadata' => 'array',
        'created_at' => 'datetime',
    ];

    /**
     * Get the user that made the request
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Scope: Filter by provider
     */
    public function scopeByProvider($query, string $provider)
    {
        return $query->where('provider', $provider);
    }

    /**
     * Scope: Filter by model
     */
    public function scopeByModel($query, string $model)
    {
        return $query->where('model', $model);
    }

    /**
     * Scope: Filter by task type
     */
    public function scopeByTaskType($query, string $taskType)
    {
        return $query->where('task_type', $taskType);
    }

    /**
     * Scope: Filter by user
     */
    public function scopeByUser($query, int $userId)
    {
        return $query->where('user_id', $userId);
    }

    /**
     * Scope: Successful requests
     */
    public function scopeSuccessful($query)
    {
        return $query->where('status', 'success');
    }

    /**
     * Scope: Failed requests
     */
    public function scopeFailed($query)
    {
        return $query->where('status', 'error');
    }

    /**
     * Scope: Recent requests
     */
    public function scopeRecent($query, int $days = 7)
    {
        return $query->where('created_at', '>=', now()->subDays($days));
    }

    /**
     * Calculate estimated cost based on token usage
     */
    public function calculateCost(): float
    {
        $pricing = config("ai.pricing.{$this->model}", [
            'input' => 0,
            'output' => 0,
        ]);

        $inputCost = ($this->prompt_tokens / 1000) * $pricing['input'];
        $outputCost = ($this->completion_tokens / 1000) * $pricing['output'];

        return $inputCost + $outputCost;
    }

    /**
     * Get available task types
     */
    public static function getTaskTypes(): array
    {
        return [
            self::TASK_PREDICTION,
            self::TASK_ANALYSIS,
            self::TASK_RECOMMENDATION,
            self::TASK_CHAT,
            self::TASK_CODE_GENERATION,
        ];
    }

    /**
     * Get available providers
     */
    public static function getProviders(): array
    {
        return [
            self::PROVIDER_OPENAI,
            self::PROVIDER_CLAUDE,
            self::PROVIDER_OLLAMA,
        ];
    }
}
