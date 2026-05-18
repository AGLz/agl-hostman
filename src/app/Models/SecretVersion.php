<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * SecretVersion Model
 *
 * Stores historical (archived) encrypted values of a secret.
 * Used to support rotation grace periods: old value stays accessible
 * until expires_at, giving dependent services time to rotate.
 *
 * @property int         $id
 * @property int         $secret_id
 * @property string      $encrypted_value
 * @property int         $version
 * @property string|null $archived_reason
 * @property \Carbon\Carbon $archived_at
 * @property \Carbon\Carbon|null $expires_at
 */
class SecretVersion extends Model
{
    use HasFactory;

    /**
     * No updated_at column on this table.
     */
    public $timestamps = false;

    /**
     * The attributes that are mass assignable.
     *
     * @var array<int, string>
     */
    protected $fillable = [
        'secret_id',
        'encrypted_value',
        'version',
        'archived_reason',
        'archived_at',
        'expires_at',
    ];

    /**
     * The attributes that should be cast.
     *
     * @var array<string, string>
     */
    protected $casts = [
        'version'     => 'integer',
        'archived_at' => 'datetime',
        'expires_at'  => 'datetime',
    ];

    /**
     * The owning secret.
     */
    public function secret(): BelongsTo
    {
        return $this->belongsTo(Secret::class);
    }

    /**
     * Whether the grace period for this version has expired.
     */
    public function isExpired(): bool
    {
        return $this->expires_at !== null && $this->expires_at->isPast();
    }
}
