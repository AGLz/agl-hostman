<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\MorphTo;

/**
 * Security Audit Log Model
 *
 * Tracks security-related events for audit and compliance.
 */
class SecurityAuditLog extends Model
{
    use HasFactory;

    public const UPDATED_AT = null;

    /**
     * The table associated with the model.
     *
     * @var string
     */
    protected $table = 'security_audit_logs';

    /**
     * The attributes that are mass assignable.
     *
     * @var array<int, string>
     */
    protected $fillable = [
        'event_type',
        'severity',
        'description',
        'user_id',
        'ip_address',
        'user_agent',
        'auditable_type',
        'auditable_id',
        'old_values',
        'new_values',
        'metadata',
        'tags',
    ];

    /**
     * The attributes that should be cast.
     *
     * @var array<string, string>
     */
    protected $casts = [
        'old_values' => 'array',
        'new_values' => 'array',
        'metadata' => 'array',
        'tags' => 'array',
        'created_at' => 'datetime',
    ];

    /**
     * Event types
     */
    public const EVENT_AUTH_LOGIN = 'auth.login';

    public const EVENT_AUTH_LOGOUT = 'auth.logout';

    public const EVENT_AUTH_FAILED = 'auth.failed';

    public const EVENT_AUTH_PASSWORD_CHANGED = 'auth.password_changed';

    public const EVENT_AUTH_PASSWORD_RESET = 'auth.password_reset';

    public const EVENT_USER_CREATED = 'user.created';

    public const EVENT_USER_UPDATED = 'user.updated';

    public const EVENT_USER_DELETED = 'user.deleted';

    public const EVENT_USER_ROLE_CHANGED = 'user.role_changed';

    public const EVENT_PERMISSION_GRANTED = 'permission.granted';

    public const EVENT_PERMISSION_REVOKED = 'permission.revoked';

    public const EVENT_CONTAINER_CREATED = 'container.created';

    public const EVENT_CONTAINER_UPDATED = 'container.updated';

    public const EVENT_CONTAINER_DELETED = 'container.deleted';

    public const EVENT_CONTAINER_DEPLOYED = 'container.deployed';

    public const EVENT_DEPLOYMENT_STARTED = 'deployment.started';

    public const EVENT_DEPLOYMENT_COMPLETED = 'deployment.completed';

    public const EVENT_DEPLOYMENT_FAILED = 'deployment.failed';

    public const EVENT_DEPLOYMENT_ROLLED_BACK = 'deployment.rolled_back';

    public const EVENT_SECURITY_SCAN = 'security.scan';

    public const EVENT_SECURITY_ALERT = 'security.alert';

    public const EVENT_VULNERABILITY_FOUND = 'security.vulnerability_found';

    public const EVENT_CONFIG_CHANGED = 'config.changed';

    public const EVENT_API_KEY_CREATED = 'api_key.created';

    public const EVENT_API_KEY_DELETED = 'api_key.deleted';

    /**
     * Severity levels
     */
    public const SEVERITY_INFO = 'info';

    public const SEVERITY_LOW = 'low';

    public const SEVERITY_MEDIUM = 'medium';

    public const SEVERITY_HIGH = 'high';

    public const SEVERITY_CRITICAL = 'critical';

    /**
     * Get the user that performed the action
     *
     * @return \Illuminate\Database\Eloquent\Relations\BelongsTo
     */
    public function user()
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Get the auditable model (polymorphic)
     */
    public function auditable(): MorphTo
    {
        return $this->morphTo();
    }

    /**
     * Scope a query to only include critical severity
     *
     * @param  \Illuminate\Database\Eloquent\Builder  $query
     * @return \Illuminate\Database\Eloquent\Builder
     */
    public function scopeCritical($query)
    {
        return $query->where('severity', self::SEVERITY_CRITICAL);
    }

    /**
     * Scope a query to only include high severity or above
     *
     * @param  \Illuminate\Database\Eloquent\Builder  $query
     * @return \Illuminate\Database\Eloquent\Builder
     */
    public function scopeHighOrAbove($query)
    {
        return $query->whereIn('severity', [self::SEVERITY_HIGH, self::SEVERITY_CRITICAL]);
    }

    /**
     * Scope a query to only include recent logs
     *
     * @param  \Illuminate\Database\Eloquent\Builder  $query
     * @return \Illuminate\Database\Eloquent\Builder
     */
    public function scopeRecent($query, int $days = 7)
    {
        return $query->where('created_at', '>=', now()->subDays($days));
    }

    /**
     * Scope a query to filter by event type
     *
     * @param  \Illuminate\Database\Eloquent\Builder  $query
     * @return \Illuminate\Database\Eloquent\Builder
     */
    public function scopeEventType($query, string $eventType)
    {
        return $query->where('event_type', $eventType);
    }

    /**
     * Scope a query to filter by tags
     *
     * @param  \Illuminate\Database\Eloquent\Builder  $query
     * @param  string|array  $tags
     * @return \Illuminate\Database\Eloquent\Builder
     */
    public function scopeWithTag($query, $tags)
    {
        $tags = (array) $tags;

        return $query->where(function ($q) use ($tags) {
            foreach ($tags as $tag) {
                $q->orWhereJsonContains('tags', $tag);
            }
        });
    }

    /**
     * Log a security event
     *
     * @return static
     */
    public static function log(string $eventType, string $description, array $data = []): self
    {
        return static::create(array_merge([
            'event_type' => $eventType,
            'description' => $description,
            'severity' => $data['severity'] ?? self::SEVERITY_INFO,
            'user_id' => auth()->id(),
            'ip_address' => request()->ip(),
            'user_agent' => request()->userAgent(),
        ], $data));
    }

    /**
     * Log authentication event
     *
     * @return static
     */
    public static function logAuth(string $event, array $data = []): self
    {
        return static::log($event, "Authentication event: {$event}", $data);
    }

    /**
     * Log user event
     *
     * @return static
     */
    public static function logUser(string $event, User $user, array $data = []): self
    {
        return static::log($event, "User event: {$event}", array_merge($data, [
            'auditable_type' => User::class,
            'auditable_id' => $user->id,
            'severity' => self::SEVERITY_LOW,
        ]));
    }

    /**
     * Log security alert
     *
     * @return static
     */
    public static function alert(string $description, array $data = []): self
    {
        return static::log(self::EVENT_SECURITY_ALERT, $description, array_merge($data, [
            'severity' => self::SEVERITY_HIGH,
            'tags' => ['security-alert', 'auto-generated'],
        ]));
    }

    /**
     * Get all available event types
     */
    public static function getEventTypes(): array
    {
        $reflection = new \ReflectionClass(__CLASS__);

        return array_values(array_filter($reflection->getConstants(), function ($constant) {
            return str_starts_with($constant, 'EVENT_');
        }, ARRAY_FILTER_USE_KEY));
    }

    /**
     * Get all available severity levels
     */
    public static function getSeverityLevels(): array
    {
        return [
            self::SEVERITY_INFO,
            self::SEVERITY_LOW,
            self::SEVERITY_MEDIUM,
            self::SEVERITY_HIGH,
            self::SEVERITY_CRITICAL,
        ];
    }
}
