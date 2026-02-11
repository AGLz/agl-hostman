<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\SecurityAuditLog;
use Illuminate\Encryption\Encrypter;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

/**
 * Secrets Management Service
 *
 * Centralized service for managing secrets, API keys, and sensitive credentials.
 * Implements secure storage, retrieval, rotation, and audit logging.
 *
 * Features:
 * - Encryption at rest using Laravel's encryption
 * - Automatic secret rotation support
 * - Secure audit logging
 * - Role-based secret access control
 * - Caching with secure ttl
 *
 * @package App\Services
 */
class SecretsManagementService
{
    /**
     * Cache prefix for secrets.
     */
    private const CACHE_PREFIX = 'secrets:';

    /**
     * Cache TTL in seconds (1 hour).
     */
    private const CACHE_TTL = 3600;

    /**
     * Version key for secret rotation tracking.
     */
    private const VERSION_KEY = 'secrets:version';

    /**
     * The encrypter instance.
     */
    protected Encrypter $encrypter;

    /**
     * Current secret version for rotation tracking.
     */
    protected int $currentVersion;

    /**
     * Create a new service instance.
     */
    public function __construct()
    {
        $this->encrypter = app('encrypter');
        $this->currentVersion = $this->getCurrentVersion();
    }

    /**
     * Store a secret securely.
     *
     * @param  string  $key  Secret identifier (e.g., "database.primary.password")
     * @param  string  $value  Secret value to store
     * @param  array  $metadata  Optional metadata (description, tags, rotation schedule)
     * @return bool
     */
    public function store(string $key, string $value, array $metadata = []): bool
    {
        try {
            // Encrypt the secret value
            $encrypted = $this->encrypter->encrypt($value);

            // Store in cache with encryption
            $cacheKey = $this->getCacheKey($key);
            $secretData = [
                'value' => $encrypted,
                'version' => $this->currentVersion,
                'created_at' => now()->toIso8601String(),
                'metadata' => $metadata,
            ];

            Cache::put($cacheKey, $secretData, self::CACHE_TTL);

            // For persistent storage, you would also store in database
            // or external secret manager like HashiCorp Vault
            $this->persistToStorage($key, $secretData);

            // Log the event (without the secret value)
            SecurityAuditLog::log(
                'secret.stored',
                "Secret stored: {$key}",
                [
                    'key' => $this->sanitizeKey($key),
                    'version' => $this->currentVersion,
                    'metadata' => $metadata,
                ]
            );

            return true;
        } catch (\Exception $e) {
            Log::error('Failed to store secret', [
                'key' => $this->sanitizeKey($key),
                'error' => $e->getMessage(),
            ]);

            return false;
        }
    }

    /**
     * Retrieve a secret by key.
     *
     * @param  string  $key  Secret identifier
     * @param  string|null  $role  Optional role for RBAC check
     * @return string|null  Decrypted secret value or null if not found
     */
    public function get(string $key, ?string $role = null): ?string
    {
        try {
            // Check RBAC permissions if role is provided
            if ($role && !$this->hasAccess($key, $role)) {
                SecurityAuditLog::logSecurityEvent(
                    null,
                    'secret.access_denied',
                    "Secret access denied: {$key}",
                    [
                        'key' => $this->sanitizeKey($key),
                        'role' => $role,
                    ]
                );

                return null;
            }

            $cacheKey = $this->getCacheKey($key);
            $secretData = Cache::get($cacheKey);

            if (!$secretData) {
                // Try to fetch from persistent storage
                $secretData = $this->fetchFromStorage($key);
                if (!$secretData) {
                    return null;
                }
            }

            // Check version for rotation
            if (isset($secretData['version']) && $secretData['version'] < $this->currentVersion) {
                // Secret needs rotation
                Log::warning('Secret version outdated', [
                    'key' => $this->sanitizeKey($key),
                    'version' => $secretData['version'],
                    'current_version' => $this->currentVersion,
                ]);
            }

            // Decrypt and return
            return $this->encrypter->decrypt($secretData['value']);
        } catch (\Exception $e) {
            Log::error('Failed to retrieve secret', [
                'key' => $this->sanitizeKey($key),
                'error' => $e->getMessage(),
            ]);

            return null;
        }
    }

    /**
     * Check if a secret exists.
     *
     * @param  string  $key  Secret identifier
     * @return bool
     */
    public function exists(string $key): bool
    {
        $cacheKey = $this->getCacheKey($key);
        return Cache::has($cacheKey) || $this->existsInStorage($key);
    }

    /**
     * Delete a secret.
     *
     * @param  string  $key  Secret identifier
     * @return bool
     */
    public function delete(string $key): bool
    {
        try {
            $cacheKey = $this->getCacheKey($key);

            // Remove from cache
            Cache::forget($cacheKey);

            // Remove from persistent storage
            $this->deleteFromStorage($key);

            SecurityAuditLog::log(
                'secret.deleted',
                "Secret deleted: {$key}",
                [
                    'key' => $this->sanitizeKey($key),
                ]
            );

            return true;
        } catch (\Exception $e) {
            Log::error('Failed to delete secret', [
                'key' => $this->sanitizeKey($key),
                'error' => $e->getMessage(),
            ]);

            return false;
        }
    }

    /**
     * Rotate a secret to a new value.
     *
     * @param  string  $key  Secret identifier
     * @param  string  $newValue  New secret value
     * @param  bool  $revokeOld  Whether to revoke the old value
     * @return bool
     */
    public function rotate(string $key, string $newValue, bool $revokeOld = true): bool
    {
        try {
            $oldValue = $this->get($key);

            // Store new value with incremented version
            $this->currentVersion++;
            $this->storeVersion($this->currentVersion);

            $result = $this->store($key, $newValue, [
                'rotated_at' => now()->toIso8601String(),
                'previous_version' => $this->currentVersion - 1,
            ]);

            if ($result && $revokeOld && $oldValue) {
                // In a real implementation, you'd store the old value
                // in a separate location for grace period
                $this->archiveOldValue($key, $oldValue);
            }

            SecurityAuditLog::log(
                'secret.rotated',
                "Secret rotated: {$key}",
                [
                    'key' => $this->sanitizeKey($key),
                    'version' => $this->currentVersion,
                    'old_revoked' => $revokeOld,
                ]
            );

            return $result;
        } catch (\Exception $e) {
            Log::error('Failed to rotate secret', [
                'key' => $this->sanitizeKey($key),
                'error' => $e->getMessage(),
            ]);

            return false;
        }
    }

    /**
     * List all secret keys accessible to a role.
     *
     * @param  string  $role  Role name
     * @return array<string>  List of secret keys
     */
    public function listForRole(string $role): array
    {
        $rbacConfig = $this->loadRbacConfig();
        $secretAccess = $rbacConfig['secret_access'][$role] ?? [];

        if (in_array('*', $secretAccess['allowed_secrets'] ?? [])) {
            // Wildcard access - return all keys
            return $this->getAllKeys();
        }

        // Filter by allowed patterns
        $allKeys = $this->getAllKeys();
        $allowedPatterns = $secretAccess['allowed_secrets'] ?? [];

        return array_filter($allKeys, function ($key) use ($allowedPatterns) {
            foreach ($allowedPatterns as $pattern) {
                if ($this->matchSecretPattern($pattern, $key)) {
                    return true;
                }
            }
            return false;
        });
    }

    /**
     * Get secret metadata without the value.
     *
     * @param  string  $key  Secret identifier
     * @return array|null  Secret metadata or null if not found
     */
    public function getMetadata(string $key): ?array
    {
        $cacheKey = $this->getCacheKey($key);
        $secretData = Cache::get($cacheKey);

        if (!$secretData) {
            $secretData = $this->fetchFromStorage($key);
            if (!$secretData) {
                return null;
            }
        }

        return [
            'key' => $this->sanitizeKey($key),
            'version' => $secretData['version'] ?? null,
            'created_at' => $secretData['created_at'] ?? null,
            'metadata' => $secretData['metadata'] ?? [],
        ];
    }

    /**
     * Generate a secure random secret.
     *
     * @param  int  $length  Length of the secret
     * @param  bool  $hex  Use hex encoding instead of base64
     * @return string
     */
    public function generate(int $length = 32, bool $hex = false): string
    {
        $bytes = random_bytes($length);
        return $hex ? bin2hex($bytes) : base64_encode($bytes);
    }

    /**
     * Validate a secret meets complexity requirements.
     *
     * @param  string  $secret  Secret to validate
     * @param  array  $rules  Validation rules
     * @return array{valid: bool, errors: array<string>}
     */
    public function validate(string $secret, array $rules = []): array
    {
        $errors = [];

        $rules = array_merge([
            'min_length' => 16,
            'require_uppercase' => true,
            'require_lowercase' => true,
            'require_number' => true,
            'require_special' => false,
        ], $rules);

        // Check minimum length
        if (strlen($secret) < $rules['min_length']) {
            $errors[] = "Secret must be at least {$rules['min_length']} characters";
        }

        // Check uppercase
        if ($rules['require_uppercase'] && !preg_match('/[A-Z]/', $secret)) {
            $errors[] = "Secret must contain at least one uppercase letter";
        }

        // Check lowercase
        if ($rules['require_lowercase'] && !preg_match('/[a-z]/', $secret)) {
            $errors[] = "Secret must contain at least one lowercase letter";
        }

        // Check number
        if ($rules['require_number'] && !preg_match('/[0-9]/', $secret)) {
            $errors[] = "Secret must contain at least one number";
        }

        // Check special character
        if ($rules['require_special'] && !preg_match('/[^a-zA-Z0-9]/', $secret)) {
            $errors[] = "Secret must contain at least one special character";
        }

        return [
            'valid' => empty($errors),
            'errors' => $errors,
        ];
    }

    /**
     * Check if role has access to a secret key.
     *
     * @param  string  $key
     * @param  string  $role
     * @return bool
     */
    protected function hasAccess(string $key, string $role): bool
    {
        $rbacConfig = $this->loadRbacConfig();
        $secretAccess = $rbacConfig['secret_access'][$role] ?? [];

        if (!($secretAccess['can_read'] ?? false)) {
            return false;
        }

        $allowedSecrets = $secretAccess['allowed_secrets'] ?? [];

        foreach ($allowedSecrets as $pattern) {
            if ($this->matchSecretPattern($pattern, $key)) {
                return true;
            }
        }

        return false;
    }

    /**
     * Match secret key against pattern.
     *
     * @param  string  $pattern
     * @param  string  $key
     * @return bool
     */
    protected function matchSecretPattern(string $pattern, string $key): bool
    {
        if ($pattern === '*') {
            return true;
        }

        if (str_ends_with($pattern, '.*')) {
            $prefix = str_replace('.*', '', $pattern);
            return str_starts_with($key, $prefix . '.');
        }

        return $pattern === $key;
    }

    /**
     * Get cache key for a secret.
     *
     * @param  string  $key
     * @return string
     */
    protected function getCacheKey(string $key): string
    {
        return self::CACHE_PREFIX . md5($key);
    }

    /**
     * Sanitize key for logging.
     *
     * @param  string  $key
     * @return string
     */
    protected function sanitizeKey(string $key): string
    {
        // Mask sensitive parts of the key
        $parts = explode('.', $key);
        if (count($parts) > 1) {
            $parts[0] = str_repeat('*', strlen($parts[0]));
        }
        return implode('.', $parts);
    }

    /**
     * Get current secret version.
     *
     * @return int
     */
    protected function getCurrentVersion(): int
    {
        return (int) Cache::get(self::VERSION_KEY, 1);
    }

    /**
     * Store new version number.
     *
     * @param  int  $version
     * @return void
     */
    protected function storeVersion(int $version): void
    {
        Cache::forever(self::VERSION_KEY, $version);
    }

    /**
     * Persist secret to storage (database or external).
     *
     * @param  string  $key
     * @param  array  $data
     * @return void
     */
    protected function persistToStorage(string $key, array $data): void
    {
        // In production, this would store to:
        // - Database table for secrets
        // - HashiCorp Vault
        // - AWS Secrets Manager
        // - Azure Key Vault

        // For now, we rely on cache
        // TODO: Implement persistent storage
    }

    /**
     * Fetch secret from storage.
     *
     * @param  string  $key
     * @return array|null
     */
    protected function fetchFromStorage(string $key): ?array
    {
        // TODO: Implement persistent storage fetch
        return null;
    }

    /**
     * Check if secret exists in storage.
     *
     * @param  string  $key
     * @return bool
     */
    protected function existsInStorage(string $key): bool
    {
        // TODO: Implement persistent storage check
        return false;
    }

    /**
     * Delete secret from storage.
     *
     * @param  string  $key
     * @return void
     */
    protected function deleteFromStorage(string $key): void
    {
        // TODO: Implement persistent storage delete
    }

    /**
     * Archive old secret value.
     *
     * @param  string  $key
     * @param  string  $oldValue
     * @return void
     */
    protected function archiveOldValue(string $key, string $oldValue): void
    {
        // TODO: Implement old value archival for grace period
    }

    /**
     * Get all secret keys.
     *
     * @return array<string>
     */
    protected function getAllKeys(): array
    {
        // TODO: Implement key listing from storage
        return [];
    }

    /**
     * Load RBAC configuration.
     *
     * @return array
     */
    protected function loadRbacConfig(): array
    {
        // Load from config/rbac.yaml or use defaults
        $configPath = base_path('config/rbac.yaml');

        if (!file_exists($configPath)) {
            return $this->getDefaultRbacConfig();
        }

        // For now return defaults
        return $this->getDefaultRbacConfig();
    }

    /**
     * Get default RBAC configuration.
     *
     * @return array
     */
    protected function getDefaultRbacConfig(): array
    {
        return [
            'secret_access' => [
                'admin' => [
                    'can_create' => true,
                    'can_read' => true,
                    'can_update' => true,
                    'can_delete' => true,
                    'can_rotate' => true,
                    'allowed_secrets' => ['*'],
                ],
                'operator' => [
                    'can_create' => false,
                    'can_read' => true,
                    'can_update' => false,
                    'can_delete' => false,
                    'can_rotate' => false,
                    'allowed_secrets' => ['deployment.*', 'container.*'],
                ],
                'viewer' => [
                    'can_create' => false,
                    'can_read' => false,
                    'can_update' => false,
                    'can_delete' => false,
                    'can_rotate' => false,
                    'allowed_secrets' => [],
                ],
                'auditor' => [
                    'can_create' => false,
                    'can_read' => true,
                    'can_update' => false,
                    'can_delete' => false,
                    'can_rotate' => false,
                    'allowed_secrets' => [],
                ],
            ],
        ];
    }
}
