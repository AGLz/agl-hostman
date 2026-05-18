<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * Secret Model
 *
 * Persists encrypted secrets in PostgreSQL.
 * Values are always stored encrypted via Laravel's AES-256-CBC encrypter.
 *
 * @property int         $id
 * @property string      $key
 * @property string      $encrypted_value
 * @property array|null  $metadata
 * @property int         $version
 * @property bool        $is_active
 * @property \Carbon\Carbon $created_at
 * @property \Carbon\Carbon $updated_at
 * @property \Carbon\Carbon|null $deleted_at
 */
class Secret extends Model
{
    use HasFactory;
    use SoftDeletes;

    /**
     * The attributes that are mass assignable.
     *
     * @var array<int, string>
     */
    protected $fillable = [
        'key',
        'encrypted_value',
        'metadata',
        'version',
        'is_active',
    ];

    /**
     * The attributes that should be cast.
     *
     * @var array<string, string>
     */
    protected $casts = [
        'metadata'   => 'array',
        'version'    => 'integer',
        'is_active'  => 'boolean',
        'deleted_at' => 'datetime',
    ];

    /**
     * Versions archived for this secret (for grace period / rotation history).
     */
    public function versions(): HasMany
    {
        return $this->hasMany(SecretVersion::class);
    }

    /**
     * Scope: only active secrets.
     */
    public function scopeActive(Builder $query): Builder
    {
        return $query->where('is_active', true);
    }

    /**
     * Scope: lookup by exact key.
     */
    public function scopeByKey(Builder $query, string $key): Builder
    {
        return $query->where('key', $key);
    }
}
