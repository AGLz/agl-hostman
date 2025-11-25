<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ProductionDeployment extends Model
{
    use HasFactory;

    protected $fillable = [
        'environment_id',
        'deployment_type',
        'active_slot',
        'blue_version',
        'green_version',
        'active_replicas',
        'desired_replicas',
        'health_status',
        'performance_metrics',
        'load_balancer_config',
        'last_deployment_at',
        'last_rollback_at',
        'last_traffic_switch_at',
    ];

    protected $casts = [
        'health_status' => 'array',
        'performance_metrics' => 'array',
        'load_balancer_config' => 'array',
        'last_deployment_at' => 'datetime',
        'last_rollback_at' => 'datetime',
        'last_traffic_switch_at' => 'datetime',
    ];

    /**
     * Get the environment that owns the production deployment.
     */
    public function environment(): BelongsTo
    {
        return $this->belongsTo(Environment::class);
    }

    /**
     * Get the inactive slot (opposite of active_slot).
     */
    public function getInactiveSlot(): string
    {
        return $this->active_slot === 'blue' ? 'green' : 'blue';
    }

    /**
     * Get the version of the active slot.
     */
    public function getActiveVersion(): ?string
    {
        return $this->active_slot === 'blue' ? $this->blue_version : $this->green_version;
    }

    /**
     * Get the version of the inactive slot.
     */
    public function getInactiveVersion(): ?string
    {
        return $this->active_slot === 'blue' ? $this->green_version : $this->blue_version;
    }

    /**
     * Check if all replicas are healthy.
     */
    public function isHealthy(): bool
    {
        if (!$this->health_status) {
            return false;
        }

        return $this->active_replicas === $this->desired_replicas &&
               ($this->health_status['status'] ?? '') === 'healthy';
    }

    /**
     * Check if rollback is available.
     */
    public function canRollback(): bool
    {
        return !is_null($this->getInactiveVersion()) &&
               $this->last_deployment_at?->diffInMinutes(now()) <= 60;
    }

    /**
     * Get rollback target information.
     */
    public function getRollbackTarget(): array
    {
        return [
            'slot' => $this->getInactiveSlot(),
            'version' => $this->getInactiveVersion(),
            'available' => $this->canRollback(),
        ];
    }
}
