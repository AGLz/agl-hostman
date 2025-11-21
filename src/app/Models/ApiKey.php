<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Str;

class ApiKey extends Model
{
    use HasFactory;

    protected $fillable = [
        'name',
        'key',
        'secret',
        'user_id',
        'permissions',
        'rate_limit',
        'expires_at',
        'last_used_at',
        'last_ip',
        'usage_count',
        'is_active',
        'metadata',
    ];

    protected $casts = [
        'permissions' => 'array',
        'metadata' => 'array',
        'expires_at' => 'datetime',
        'last_used_at' => 'datetime',
        'is_active' => 'boolean',
        'rate_limit' => 'integer',
        'usage_count' => 'integer',
    ];

    protected $hidden = [
        'secret',
    ];

    /**
     * Boot the model
     */
    protected static function booted()
    {
        static::creating(function ($apiKey) {
            if (!$apiKey->key) {
                $apiKey->key = 'ak_' . Str::random(32);
            }
            if (!$apiKey->secret) {
                $apiKey->secret = hash('sha256', Str::random(64));
            }
        });
    }

    /**
     * Get the user that owns the API key
     */
    public function user()
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Check if the API key has a specific permission
     */
    public function hasPermission(string $permission): bool
    {
        if (in_array('*', $this->permissions ?? [])) {
            return true;
        }
        
        return in_array($permission, $this->permissions ?? []);
    }

    /**
     * Check if the API key is expired
     */
    public function isExpired(): bool
    {
        if (!$this->expires_at) {
            return false;
        }
        
        return $this->expires_at->isPast();
    }

    /**
     * Check if the API key is valid
     */
    public function isValid(): bool
    {
        return $this->is_active && !$this->isExpired();
    }

    /**
     * Record API key usage
     */
    public function recordUsage(string $ip = null): void
    {
        $this->increment('usage_count');
        $this->update([
            'last_used_at' => now(),
            'last_ip' => $ip,
        ]);
    }

    /**
     * Scope for active API keys
     */
    public function scopeActive($query)
    {
        return $query->where('is_active', true)
                     ->where(function ($q) {
                         $q->whereNull('expires_at')
                           ->orWhere('expires_at', '>', now());
                     });
    }
}