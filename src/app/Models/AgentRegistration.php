<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AgentRegistration extends Model
{
    public const TYPE_ANONYMOUS = 'anonymous';

    public const TYPE_AGENT_PROVIDER = 'agent-provider';

    public const TYPE_EMAIL_VERIFICATION = 'email-verification';

    public const STATUS_PENDING_CLAIM = 'pending_claim';

    public const STATUS_CLAIMED = 'claimed';

    public const STATUS_EXPIRED = 'expired';

    public const STATUS_REVOKED = 'revoked';

    protected $fillable = [
        'registration_id',
        'registration_type',
        'status',
        'user_id',
        'api_key_id',
        'personal_access_token_id',
        'credential_type',
        'scopes',
        'post_claim_scopes',
        'claim_token_hash',
        'claim_view_token_hash',
        'claim_email',
        'otp_hash',
        'otp_expires_at',
        'provider_iss',
        'provider_sub',
        'provider_jti',
        'expires_at',
        'claimed_at',
        'revoked_at',
        'metadata',
    ];

    protected function casts(): array
    {
        return [
            'scopes' => 'array',
            'post_claim_scopes' => 'array',
            'metadata' => 'array',
            'otp_expires_at' => 'datetime',
            'expires_at' => 'datetime',
            'claimed_at' => 'datetime',
            'revoked_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function apiKey(): BelongsTo
    {
        return $this->belongsTo(ApiKey::class);
    }

    public function isExpired(): bool
    {
        return $this->expires_at !== null && $this->expires_at->isPast();
    }

    public function isActive(): bool
    {
        return ! in_array($this->status, [self::STATUS_EXPIRED, self::STATUS_REVOKED], true)
            && ! $this->isExpired();
    }
}
