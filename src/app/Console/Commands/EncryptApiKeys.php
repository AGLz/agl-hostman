<?php

namespace App\Console\Commands;

use App\Services\EncryptedConfigService;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Crypt;

/**
 * EncryptApiKeys - Artisan command to encrypt API keys from .env
 *
 * Usage: php artisan config:encrypt-api-keys
 *
 * Encrypts sensitive API keys and stores them securely
 * Based on CODE-ANALYSIS-REPORT.md critical security issue #1
 */
class EncryptApiKeys extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'config:encrypt-api-keys
                            {--verify : Only verify existing encrypted keys}
                            {--force : Force re-encryption of all keys}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Encrypt API keys from .env file for secure storage';

    /**
     * API keys to encrypt
     */
    protected array $keysToEncrypt = [
        'CLAUDE_API_KEY' => 'services.claude.api_key',
        'GEMINI_API_KEY' => 'services.gemini.api_key',
        'OPENAI_API_KEY' => 'services.openai.api_key',
        'ABACUSAI_API_KEY' => 'services.abacusai.api_key',
        'N8N_API_KEY' => 'services.n8n.api_key',
        'N8N_WEBHOOK_SECRET' => 'services.n8n.webhook_secret',
        'WORKOS_API_KEY' => 'services.workos.api_key',
    ];

    /**
     * Execute the console command.
     */
    public function handle(EncryptedConfigService $encryptedConfig): int
    {
        $this->info('🔐 API Key Encryption Tool');
        $this->newLine();

        // Verify mode
        if ($this->option('verify')) {
            return $this->verifyEncryptedKeys($encryptedConfig);
        }

        // Check if APP_KEY is set
        if (empty(config('app.key'))) {
            $this->error('❌ APP_KEY not set. Run: php artisan key:generate');

            return self::FAILURE;
        }

        $this->info('Scanning .env for API keys...');
        $this->newLine();

        $encryptedCount = 0;
        $skippedCount = 0;
        $errorCount = 0;

        foreach ($this->keysToEncrypt as $envKey => $configPath) {
            $value = env($envKey);

            if (empty($value)) {
                $this->warn("⚠️  {$envKey}: Not set in .env (skipped)");
                $skippedCount++;

                continue;
            }

            // Check if already encrypted
            $existingEncrypted = env($envKey.'_ENCRYPTED');

            if ($existingEncrypted && ! $this->option('force')) {
                $this->info("✓ {$envKey}: Already encrypted (use --force to re-encrypt)");
                $skippedCount++;

                continue;
            }

            // Encrypt and store
            try {
                $encrypted = Crypt::encryptString($value);

                // Store in .env with _ENCRYPTED suffix
                $this->updateEnvFile($envKey.'_ENCRYPTED', $encrypted);

                $this->info("✓ {$envKey}: Encrypted successfully");
                $encryptedCount++;

            } catch (\Exception $e) {
                $this->error("❌ {$envKey}: Encryption failed - {$e->getMessage()}");
                $errorCount++;
            }
        }

        $this->newLine();
        $this->info('📊 Summary:');
        $this->line("  Encrypted: {$encryptedCount}");
        $this->line("  Skipped: {$skippedCount}");
        $this->line("  Errors: {$errorCount}");

        if ($encryptedCount > 0) {
            $this->newLine();
            $this->warn('⚠️  IMPORTANT NEXT STEPS:');
            $this->line('1. Test application functionality');
            $this->line('2. Update code to use EncryptedConfigService::get()');
            $this->line('3. Remove plain API keys from .env after testing');
            $this->line('4. Restart services: php artisan config:clear && php artisan optimize');
        }

        return $errorCount > 0 ? self::FAILURE : self::SUCCESS;
    }

    /**
     * Verify existing encrypted keys
     */
    protected function verifyEncryptedKeys(EncryptedConfigService $encryptedConfig): int
    {
        $this->info('Verifying encrypted API keys...');
        $this->newLine();

        $validCount = 0;
        $invalidCount = 0;

        foreach ($this->keysToEncrypt as $envKey => $configPath) {
            $encrypted = env($envKey.'_ENCRYPTED');

            if (empty($encrypted)) {
                $this->warn("⚠️  {$envKey}: No encrypted version found");

                continue;
            }

            try {
                $decrypted = Crypt::decryptString($encrypted);

                if (! empty($decrypted)) {
                    $this->info("✓ {$envKey}: Valid (length: ".strlen($decrypted).')');
                    $validCount++;
                } else {
                    $this->error("❌ {$envKey}: Decrypted to empty string");
                    $invalidCount++;
                }

            } catch (\Exception $e) {
                $this->error("❌ {$envKey}: Invalid - {$e->getMessage()}");
                $invalidCount++;
            }
        }

        $this->newLine();
        $this->info('📊 Verification Summary:');
        $this->line("  Valid: {$validCount}");
        $this->line("  Invalid: {$invalidCount}");

        return $invalidCount > 0 ? self::FAILURE : self::SUCCESS;
    }

    /**
     * Update .env file with new key
     */
    protected function updateEnvFile(string $key, string $value): void
    {
        $envPath = base_path('.env');

        if (! file_exists($envPath)) {
            throw new \RuntimeException('.env file not found');
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
}
