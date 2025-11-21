<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

class DokployDomain extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'application_id',
        'dokploy_id',
        'host',
        'https',
        'certificate_type',
        'strip_path',
        'path',
        'port',
        'service_name',
        'custom_cert_resolver',
        'internal_path',
        'domain_type',
        'status',
        'metadata',
    ];

    protected $casts = [
        'https' => 'boolean',
        'strip_path' => 'boolean',
        'port' => 'integer',
        'metadata' => 'array',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
        'deleted_at' => 'datetime',
    ];

    public function application(): BelongsTo
    {
        return $this->belongsTo(DokployApplication::class, 'application_id');
    }

    public function scopeActive($query)
    {
        return $query->where('status', 'active');
    }

    public function scopeHttps($query)
    {
        return $query->where('https', true);
    }
}
