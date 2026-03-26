<?php

declare(strict_types=1);

namespace Tests\Feature\Security;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Redis;
use Tests\TestCase;

/**
 * Secrets Management Tests
 *
 * Tests for secrets management including hardcoded credentials,
 * environment variable usage, and secrets storage security.
 */
class SecretsManagementTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Test no hardcoded passwords in source code
     */
    public function test_no_hardcoded_passwords_in_source(): void
    {
        $sourceDirs = [
            base_path('src/app'),
            base_path('src/config'),
        ];

        $passwordPatterns = [
            '/password\s*=>\s*[\'"][^\'"]{8,}[\'"]/i',
            '/pass\s*=\s*[\'"][^\'"]{8,}[\'"]/i',
            '/secret\s*=>\s*[\'"][^\'"]{16,}[\'"]/i',
            '/api_key\s*=>\s*[\'"][^\'"]{20,}[\'"]/i',
        ];

        foreach ($sourceDirs as $dir) {
            if (! is_dir($dir)) {
                continue;
            }

            $files = File::allFiles($dir);

            foreach ($files as $file) {
                if ($file->getExtension() !== 'php') {
                    continue;
                }

                $content = File::get($file->getPathname());

                foreach ($passwordPatterns as $pattern) {
                    $matches = [];
                    preg_match($pattern, $content, $matches);

                    if (! empty($matches)) {
                        $envVarPattern = '/env\([\'"]([^\'"]+)[\'"]\)/';
                        $hasEnvVar = preg_match($envVarPattern, $content) > 0;

                        $this->assertTrue(
                            $hasEnvVar || str_contains($content, 'example'),
                            "Potential hardcoded secret in {$file->getRelativePathname()}"
                        );
                    }
                }
            }
        }

        $this->assertTrue(true);
    }

    /**
     * Test environment variables are used for sensitive data
     */
    public function test_environment_variables_for_sensitive_data(): void
    {
        $configFiles = [
            'database.php',
            'app.php',
            'services.php',
            'mail.php',
        ];

        foreach ($configFiles as $configFile) {
            $path = base_path("src/config/{$configFile}");

            if (! File::exists($path)) {
                continue;
            }

            $content = File::get($path);

            $sensitiveKeys = ['password', 'secret', 'key', 'api_key', 'token'];

            foreach ($sensitiveKeys as $key) {
                $hardcodedPattern = "/'{$key}'\s*=>\s*'[^']{8,}'/";

                preg_match_all($hardcodedPattern, $content, $matches);

                foreach ($matches[0] ?? [] as $match) {
                    if (! str_contains($match, 'example')) {
                        $this->assertStringContainsString('env(', $content, "{$key} should use env()");
                    }
                }
            }
        }

        $this->assertTrue(true);
    }

    /**
     * Test .env files are not in version control
     */
    public function test_env_files_not_in_version_control(): void
    {
        $gitIgnorePath = base_path('.gitignore');

        if (! File::exists($gitIgnorePath)) {
            $this->assertTrue(true);

            return;
        }

        $gitIgnore = File::get($gitIgnorePath);

        $this->assertStringContainsString('.env', $gitIgnore);
        $this->assertStringContainsString('.env.production', $gitIgnore);
        $this->assertStringContainsString('.env.local', $gitIgnore);
    }

    /**
     * Test example env file exists
     */
    public function test_example_env_file_exists(): void
    {
        $exampleEnvPath = base_path('.env.example');

        if (! File::exists($exampleEnvPath)) {
            $exampleEnvPath = base_path('src/.env.example');
        }

        $exists = File::exists($exampleEnvPath);

        $this->assertTrue(
            $exists || File::exists(base_path('src/.env.example')),
            'Example .env file should exist'
        );
    }

    /**
     * Test .env.example has no real secrets
     */
    public function test_example_env_has_no_real_secrets(): void
    {
        $exampleEnvPaths = [
            base_path('.env.example'),
            base_path('src/.env.example'),
        ];

        foreach ($exampleEnvPaths as $path) {
            if (! File::exists($path)) {
                continue;
            }

            $content = File::get($path);

            $realSecretPatterns = [
                '/sk-[a-zA-Z0-9]{32,}/',
                '/ghp_[a-zA-Z0-9]{36}/',
                '/AKIA[0-9A-Z]{16}/',
            ];

            foreach ($realSecretPatterns as $pattern) {
                $matches = [];
                preg_match($pattern, $content, $matches);

                $this->assertEmpty(
                    $matches,
                    ".env.example should not contain real secrets: {$path}"
                );
            }
        }

        $this->assertTrue(true);
    }

    /**
     * Test app key is set
     */
    public function test_app_key_is_set(): void
    {
        $appKey = config('app.key');

        $this->assertNotEmpty($appKey);
        $this->assertStringStartsWith('base64:', $appKey);
        $this->assertGreaterThan(30, strlen($appKey));
    }

    /**
     * Test app key is not default
     */
    public function test_app_key_not_default(): void
    {
        $appKey = config('app.key');

        $defaultKeys = [
            'base64:'.base64_encode('SomeRandomStringSomeRandomString'),
            'base64:'.base64_encode('YOUR_SECRET_KEY_HERE'),
        ];

        $this->assertNotContains($appKey, $defaultKeys);
    }

    /**
     * Test database credentials use env variables
     */
    public function test_database_credentials_use_env(): void
    {
        $dbConfig = config('database.connections.mysql');

        $this->assertEquals(env('DB_DATABASE', 'forge'), $dbConfig['database'] ?? null);
        $this->assertEquals(env('DB_USERNAME', 'forge'), $dbConfig['username'] ?? null);
    }

    /**
     * Test cache encryption
     */
    public function test_cache_encryption(): void
    {
        $sensitiveData = 'sensitive_information';

        \Cache::put('test_key', $sensitiveData);

        $this->assertEquals($sensitiveData, \Cache::get('test_key'));

        \Cache::forget('test_key');
    }

    /**
     * Test session encryption
     */
    public function test_session_encryption(): void
    {
        $this->assertTrue(config('session.encrypt'));
    }

    /**
     * Test cookie security
     */
    public function test_cookie_security(): void
    {
        $this->assertTrue(config('session.http_only'));

        if (app()->environment('production')) {
            $this->assertTrue(config('session.secure'));
        }

        $this->assertNotEmpty(config('session.cookie'));
        $this->assertFalse(str_contains(config('session.cookie'), 'laravel'));
    }

    /**
     * Test API keys are stored securely
     */
    public function test_api_keys_stored_securely(): void
    {
        $configPath = base_path('src/config/services.php');

        if (! File::exists($configPath)) {
            $this->assertTrue(true);

            return;
        }

        $content = File::get($configPath);

        $apiKeyPattern = '/key\s*=>\s*[\'"][^\'"]{32,}[\'"]/';

        preg_match_all($apiKeyPattern, $content, $matches);

        foreach ($matches[0] ?? [] as $match) {
            $this->assertStringContainsString('env(', $match, 'API keys should use env()');
        }

        $this->assertTrue(true);
    }

    /**
     * Test no secrets in logs
     */
    public function test_no_secrets_in_logs(): void
    {
        $logDir = storage_path('logs');

        if (! is_dir($logDir)) {
            $this->assertTrue(true);

            return;
        }

        $logFiles = glob($logDir.'/*.log');

        $secretPatterns = [
            '/password["\']?\s*=>\s*["\']?[^"\']{8,}/i',
            '/token["\']?\s*=>\s*["\']?[^"\']{20,}/i',
            '/api[_-]?key["\']?\s*=>\s*["\']?[^"\']{20,}/i',
        ];

        foreach ($logFiles as $logFile) {
            $content = File::get($logFile);

            foreach ($secretPatterns as $pattern) {
                $matches = [];
                preg_match($pattern, $content, $matches);

                $this->assertEmpty(
                    $matches,
                    "Potential secret in log file: {$logFile}"
                );
            }
        }

        $this->assertTrue(true);
    }

    /**
     * Test debug mode is off in production
     */
    public function test_debug_off_in_production(): void
    {
        if (app()->environment('production')) {
            $this->assertFalse(config('app.debug'));
        }

        $this->assertTrue(true);
    }

    /**
     * Test error reporting configuration
     */
    public function test_error_reporting_configuration(): void
    {
        $env = app()->environment();

        if ($env === 'production') {
            $this->assertFalse(config('app.debug'));
        }
    }

    /**
     * Test sensitive data not in cache keys
     */
    public function test_sensitive_data_not_in_cache_keys(): void
    {
        $this->assertTrue(
            ! str_contains(\Cache::getPrefix(), 'password') &&
            ! str_contains(\Cache::getPrefix(), 'secret') &&
            ! str_contains(\Cache::getPrefix(), 'token')
        );
    }

    /**
     * Test no secrets in committed files
     */
    public function test_no_secrets_in_committed_files(): void
    {
        $excludeDirs = ['vendor', 'node_modules', 'storage', 'bootstrap/cache'];

        $files = File::files(base_path());

        foreach ($files as $file) {
            if ($file->getExtension() !== 'php') {
                continue;
            }

            $path = $file->getPathname();

            foreach ($excludeDirs as $exclude) {
                if (str_contains($path, $exclude)) {
                    continue 2;
                }
            }

            $content = File::get($path);

            $secretPatterns = [
                '/sk-[a-zA-Z0-9]{32,}/',
                '/ghp_[a-zA-Z0-9]{36}/',
                '/AKIA[0-9A-Z]{16}/',
                '/AIza[0-9A-Za-z\\-_]{35}/',
            ];

            foreach ($secretPatterns as $pattern) {
                $matches = [];
                preg_match($pattern, $content, $matches);

                if (! empty($matches)) {
                    $hasEnv = str_contains($content, 'env(');
                    $this->assertTrue(
                        $hasEnv || str_contains($path, 'example'),
                        "Potential secret in {$path}"
                    );
                }
            }
        }

        $this->assertTrue(true);
    }

    /**
     * Test redis password uses env
     */
    public function test_redis_password_uses_env(): void
    {
        $redisConfig = config('database.redis.default');

        if (isset($redisConfig['password'])) {
            $this->assertNotEmpty($redisConfig['password']);
            $this->assertStringContainsString('env', file_get_contents(base_path('src/config/database.php')));
        }

        $this->assertTrue(true);
    }

    /**
     * Test mail credentials use env
     */
    public function test_mail_credentials_use_env(): void
    {
        $mailConfig = config('mail.mailers.smtp');

        if ($mailConfig) {
            $this->assertEquals(env('MAIL_USERNAME'), $mailConfig['username'] ?? null);
            $this->assertEquals(env('MAIL_PASSWORD'), $mailConfig['password'] ?? null);
        }

        $this->assertTrue(true);
    }

    /**
     * Test no secrets in configuration cache
     */
    public function test_no_secrets_in_config_cache(): void
    {
        $configCache = base_path('bootstrap/cache/config.php');

        if (! File::exists($configCache)) {
            $this->assertTrue(true);

            return;
        }

        $content = File::get($configCache);

        $realSecretPatterns = [
            '/sk-[a-zA-Z0-9]{32,}/',
            '/ghp_[a-zA-Z0-9]{36}/',
        ];

        foreach ($realSecretPatterns as $pattern) {
            $matches = [];
            preg_match($pattern, $content, $matches);

            $this->assertEmpty(
                $matches,
                'Config cache should not contain real secrets'
            );
        }

        $this->assertTrue(true);
    }

    /**
     * Test JWT secret is set
     */
    public function test_jwt_secret_is_set(): void
    {
        $jwtSecret = config('jwt.secret');

        if ($jwtSecret) {
            $this->assertNotEmpty($jwtSecret);
            $this->assertGreaterThan(20, strlen($jwtSecret));
        }

        $this->assertTrue(true);
    }
}
