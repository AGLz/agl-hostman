<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Audit Log Model
 * AGL Infrastructure Admin Platform - Phase 5
 *
 * Tracks all user actions and system events for security and compliance.
 */
class AuditLog extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'action',
        'model_type',
        'model_id',
        'old_values',
        'new_values',
        'ip_address',
        'user_agent',
        'metadata',
        'request_id',
        'session_id',
        'api_key_id',
        // Phase 5 RBAC enhancements
        'event_type',
        'event_category',
        'description',
        'severity',
        'status',
    ];

    protected $casts = [
        'old_values' => 'array',
        'new_values' => 'array',
        'metadata' => 'array',
        'created_at' => 'datetime',
    ];

    // ========================================
    // Phase 5: RBAC Event Type Constants
    // ========================================

    public const EVENT_AUTH = 'authentication';
    public const EVENT_AUTHORIZATION = 'authorization';
    public const EVENT_USER_MANAGEMENT = 'user_management';
    public const EVENT_ROLE_MANAGEMENT = 'role_management';
    public const EVENT_INFRASTRUCTURE = 'infrastructure';
    public const EVENT_MONITORING = 'monitoring';
    public const EVENT_SECURITY = 'security';
    public const EVENT_SYSTEM = 'system';

    // ========================================
    // Phase 5: Event Category Constants
    // ========================================

    public const CATEGORY_LOGIN = 'login';
    public const CATEGORY_LOGOUT = 'logout';
    public const CATEGORY_LOGIN_FAILED = 'login_failed';
    public const CATEGORY_PASSWORD_RESET = 'password_reset';
    public const CATEGORY_PERMISSION_CHANGED = 'permission_changed';
    public const CATEGORY_ROLE_ASSIGNED = 'role_assigned';
    public const CATEGORY_USER_CREATED = 'user_created';
    public const CATEGORY_USER_UPDATED = 'user_updated';
    public const CATEGORY_USER_DELETED = 'user_deleted';
    public const CATEGORY_CONTAINER_ACTION = 'container_action';
    public const CATEGORY_CONFIG_CHANGED = 'config_changed';
    public const CATEGORY_UNAUTHORIZED_ACCESS = 'unauthorized_access';

    // ========================================
    // Phase 5: Severity Constants
    // ========================================

    public const SEVERITY_INFO = 'info';
    public const SEVERITY_WARNING = 'warning';
    public const SEVERITY_ERROR = 'error';
    public const SEVERITY_CRITICAL = 'critical';

    // ========================================
    // Phase 5: Status Constants
    // ========================================

    public const STATUS_SUCCESS = 'success';
    public const STATUS_FAILED = 'failed';
    public const STATUS_PENDING = 'pending';

    /**
     * Get the user that performed the action
     */
    public function user()
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Get the API key used for the action
     */
    public function apiKey()
    {
        return $this->belongsTo(ApiKey::class);
    }

    /**
     * Get the auditable model
     */
    public function auditable()
    {
        return $this->morphTo('auditable', 'model_type', 'model_id');
    }

    /**
     * Scope for recent logs
     */
    public function scopeRecent($query, int $days = 7)
    {
        return $query->where('created_at', '>=', now()->subDays($days));
    }

    /**
     * Scope for specific action
     */
    public function scopeForAction($query, string $action)
    {
        return $query->where('action', $action);
    }

    /**
     * Scope for specific model
     */
    public function scopeForModel($query, string $modelType, int $modelId = null)
    {
        $query->where('model_type', $modelType);

        if ($modelId) {
            $query->where('model_id', $modelId);
        }

        return $query;
    }

    // ========================================
    // Phase 5: Enhanced Scopes for RBAC
    // ========================================

    /**
     * Scope: Filter by event type
     */
    public function scopeOfType($query, string $type)
    {
        return $query->where('event_type', $type);
    }

    /**
     * Scope: Filter by event category
     */
    public function scopeOfCategory($query, string $category)
    {
        return $query->where('event_category', $category);
    }

    /**
     * Scope: Filter by severity
     */
    public function scopeWithSeverity($query, string $severity)
    {
        return $query->where('severity', $severity);
    }

    /**
     * Scope: Filter by user
     */
    public function scopeByUser($query, int $userId)
    {
        return $query->where('user_id', $userId);
    }

    /**
     * Scope: Security events only
     */
    public function scopeSecurityEvents($query)
    {
        return $query->whereIn('event_type', [
            self::EVENT_SECURITY,
            self::EVENT_AUTHORIZATION
        ]);
    }

    /**
     * Scope: Failed events only
     */
    public function scopeFailed($query)
    {
        return $query->where('status', self::STATUS_FAILED);
    }

    /**
     * Scope: Authentication events
     */
    public function scopeAuthEvents($query)
    {
        return $query->where('event_type', self::EVENT_AUTH);
    }

    // ========================================
    // Phase 5: Helper Methods
    // ========================================

    /**
     * Create a new audit log entry
     */
    public static function record(array $data): self
    {
        return self::create(array_merge([
            'ip_address' => request()->ip(),
            'user_agent' => request()->userAgent(),
            'severity' => self::SEVERITY_INFO,
            'status' => self::STATUS_SUCCESS,
        ], $data));
    }

    /**
     * Log authentication event
     */
    public static function logAuth(?User $user, string $action, string $status, array $metadata = []): self
    {
        return self::record([
            'user_id' => $user?->id,
            'event_type' => self::EVENT_AUTH,
            'event_category' => $action,
            'action' => $action,
            'description' => ucfirst($action) . ' attempt',
            'metadata' => $metadata,
            'status' => $status,
            'severity' => $status === self::STATUS_FAILED ? self::SEVERITY_WARNING : self::SEVERITY_INFO,
        ]);
    }

    /**
     * Log user management event
     */
    public static function logUserManagement(User $performer, User $subject, string $action, array $metadata = []): self
    {
        return self::record([
            'user_id' => $performer->id,
            'event_type' => self::EVENT_USER_MANAGEMENT,
            'event_category' => $action,
            'action' => $action,
            'description' => "User {$subject->name} was {$action}",
            'model_type' => User::class,
            'model_id' => $subject->id,
            'metadata' => $metadata,
        ]);
    }

    /**
     * Log role/permission change
     */
    public static function logPermissionChange(User $performer, User $subject, string $action, array $metadata = []): self
    {
        return self::record([
            'user_id' => $performer->id,
            'event_type' => self::EVENT_ROLE_MANAGEMENT,
            'event_category' => $action,
            'action' => $action,
            'description' => "Permissions changed for {$subject->name}",
            'model_type' => User::class,
            'model_id' => $subject->id,
            'metadata' => $metadata,
        ]);
    }

    /**
     * Log infrastructure operation
     */
    public static function logInfrastructure(User $user, string $action, string $description, array $metadata = []): self
    {
        return self::record([
            'user_id' => $user->id,
            'event_type' => self::EVENT_INFRASTRUCTURE,
            'event_category' => self::CATEGORY_CONTAINER_ACTION,
            'action' => $action,
            'description' => $description,
            'metadata' => $metadata,
        ]);
    }

    /**
     * Log security event (unauthorized access, etc.)
     */
    public static function logSecurityEvent(?User $user, string $action, string $description, array $metadata = []): self
    {
        return self::record([
            'user_id' => $user?->id,
            'event_type' => self::EVENT_SECURITY,
            'event_category' => self::CATEGORY_UNAUTHORIZED_ACCESS,
            'action' => $action,
            'description' => $description,
            'metadata' => $metadata,
            'severity' => self::SEVERITY_WARNING,
            'status' => self::STATUS_FAILED,
        ]);
    }

    // ========================================
    // Phase 5: Accessor Attributes
    // ========================================

    /**
     * Get human-readable severity label
     */
    public function getSeverityLabelAttribute(): string
    {
        return match($this->severity) {
            self::SEVERITY_INFO => 'Info',
            self::SEVERITY_WARNING => 'Warning',
            self::SEVERITY_ERROR => 'Error',
            self::SEVERITY_CRITICAL => 'Critical',
            default => 'Unknown',
        };
    }

    /**
     * Get severity color for UI
     */
    public function getSeverityColorAttribute(): string
    {
        return match($this->severity) {
            self::SEVERITY_INFO => 'blue',
            self::SEVERITY_WARNING => 'yellow',
            self::SEVERITY_ERROR => 'orange',
            self::SEVERITY_CRITICAL => 'red',
            default => 'gray',
        };
    }

    /**
     * Get status label
     */
    public function getStatusLabelAttribute(): string
    {
        return match($this->status) {
            self::STATUS_SUCCESS => 'Success',
            self::STATUS_FAILED => 'Failed',
            self::STATUS_PENDING => 'Pending',
            default => 'Unknown',
        };
    }
}