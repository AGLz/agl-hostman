<?php

namespace App\Services;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\Log;

/**
 * EncryptedConfigService - Secure API key storage and retrieval
 *
 * Replaces plain-text API keys in config files
 * Based on CODE-ANALYSIS-REPORT.md critical security issue #1
 *
 * Usage:
 * 1. Encrypt keys: php artisan config:encrypt-api-keys
 * 2. Retrieve: app(EncryptedConfigService::class)->get('services.claude.api_key')
 */
class EncryptedConfigService
{
    private const CACHE_PREFIX = 'encrypted_config:';

    private const CACHE_TTL = 3600; // 1 hour

    /**
     * Get encrypted configuration value
     *
     * @param  string  $key  Config key (e.g., 'services.claude.api_key')
     * @param  mixed  $default  Default value if not found
     * @return mixed Decrypted value
     */
    public function get(string $key, mixed $default = null): mixed
    {
        // Check cache first
        $cacheKey = self::CACHE_PREFIX.$key;

        if (Cache::has($cacheKey)) {
            return Cache::get($cacheKey);
        }

        // Get encrypted value from config
        $encryptedValue = config($key.'_encrypted');

        if (empty($encryptedValue)) {
            // Fallback to plain config (for backwards compatibility)
            Log::warning("Encrypted config not found for key: {$key}, using plain config");

            return config($key, $default);
        }

        try {
            // Decrypt value
            $decryptedValue = Crypt::decryptString($encryptedValue);

            // Cache decrypted value
            Cache::put($cacheKey, $decryptedValue, self::CACHE_TTL);

            return $decryptedValue;

        } catch (\Exception $e) {
            Log::error("Failed to decrypt config key: {$key}", [
                'error' => $e->getMessage(),
            ]);

            return $default;
        }
    }

    /**
     * Store encrypted configuration value
     *
     * @param  string  $key  Config key
     * @param  string  $value  Value to encrypt
     * @return bool Success status
     */
    public function set(string $key, string $value): bool
    {
        try {
            // Encrypt value
            $encryptedValue = Crypt::encryptString($value);

            // Store in database or config file
            // For now, we'll use .env file with _ENCRYPTED suffix
            $envKey = strtoupper(str_replace('.', '_', $key)).'_ENCRYPTED';

            // Update .env file (you might want to use a package like vlucas/phpdotenv)
            $this->updateEnvFile($envKey, $encryptedValue);

            // Clear cache
            Cache::forget(self::CACHE_PREFIX.$key);

            Log::info("Encrypted config stored for key: {$key}");

            return true;

        } catch (\Exception $e) {
            Log::error("Failed to encrypt config key: {$key}", [
                'error' => $e->getMessage(),
            ]);

            return false;
        }
    }

    /**
     * Get all AI service API keys (encrypted)
     *
     * @return array Decrypted API keys
     */
    public function getAIServiceKeys(): array
    {
        return [
            'claude' => $this->get('services.claude.api_key'),
            'gemini' => $this->get('services.gemini.api_key'),
            'openai' => $this->get('services.openai.api_key'),
            'abacusai' => $this->get('services.abacusai.api_key'),
            'ollama' => $this->get('services.ollama.api_url'), // URL, not key
        ];
    }

    /**
     * Rotate API key (encrypt new value, invalidate cache)
     *
     * @param  string  $key  Config key
     * @param  string  $newValue  New API key
     * @return bool Success status
     */
    public function rotate(string $key, string $newValue): bool
    {
        // Store new encrypted value
        $success = $this->set($key, $newValue);

        if ($success) {
            // Clear all related caches
            Cache::forget(self::CACHE_PREFIX.$key);

            Log::info("API key rotated for: {$key}");
        }

        return $success;
    }

    /**
     * Validate API key is properly encrypted
     *
     * @param  string  $key  Config key
     * @return bool Validation status
     */
    public function validate(string $key): bool
    {
        $encryptedValue = config($key.'_encrypted');

        if (empty($encryptedValue)) {
            return false;
        }

        try {
            Crypt::decryptString($encryptedValue);

            return true;
        } catch (\Exception $e) {
            return false;
        }
    }

    /**
     * Update .env file with encrypted value
     *
     * @param  string  $key  Environment variable key
     * @param  string  $value  Encrypted value
     */
    protected function updateEnvFile(string $key, string $value): void
    {
        $envPath = base_path('.env');

        if (! file_exists($envPath)) {
            Log::error('.env file not found');

            return;
        }

        $envContent = file_get_contents($envPath);
        $escapedValue = str_replace('"', '\"', $value);

        // Check if key exists
        if (preg_match("/^{$key}=/m", $envContent)) {
            // Update existing key
            $envContent = preg_replace(
                "/^{$key}=.*/m",
                "{$key}=\"{$escapedValue}\"",
                $envContent
            );
        } else {
            // Append new key
            $envContent .= "\n{$key}=\"{$escapedValue}\"\n";
        }

        file_put_contents($envPath, $envContent);
    }

    /**
     * Clear all encrypted config cache
     */
    public function clearCache(): void
    {
        // This would require Redis SCAN or similar to find all keys with prefix
        Cache::flush();
        Log::info('Encrypted config cache cleared');
    }
}
