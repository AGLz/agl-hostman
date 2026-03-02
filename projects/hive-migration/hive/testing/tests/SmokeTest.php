<?php

namespace Tests\Feature;

use Tests\TestCase;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;

/**
 * Smoke Tests - Quick validation of critical functionality
 *
 * Execution: Pre-deployment, post-deployment
 * Duration: 5-10 minutes
 *
 * Priority: P1 - CRITICAL
 * These tests MUST pass before any deployment
 *
 * Location: /var/www/fg_OLD2_NEW/tests/Feature/SmokeTest.php
 */
class SmokeTest extends TestCase
{
    /**
     * Test server is responding
     */
    public function test_server_is_responding(): void
    {
        $response = $this->get('/');

        $response->assertStatus(200);
    }

    /**
     * Test health check endpoint (if available)
     */
    public function test_health_check_endpoint(): void
    {
        $response = $this->get('/api/health');

        // Accept 200 or 404 if endpoint doesn't exist
        $this->assertContains($response->status(), [200, 404]);
    }

    /**
     * Test database connectivity
     */
    public function test_database_connectivity(): void
    {
        try {
            DB::connection()->getPdo();
            $this->assertTrue(true, 'Database connection successful');
        } catch (\Exception $e) {
            $this->fail('Database connection failed: ' . $e->getMessage());
        }
    }

    /**
     * Test sys database connectivity (secondary connection)
     */
    public function test_sys_database_connectivity(): void
    {
        try {
            DB::connection('mysql_sys')->getPdo();
            $this->assertTrue(true, 'Sys database connection successful');
        } catch (\Exception $e) {
            $this->markTestSkipped('Sys database connection not configured: ' . $e->getMessage());
        }
    }

    /**
     * Test authentication endpoint exists
     */
    public function test_authentication_endpoint_exists(): void
    {
        $response = $this->postJson('/api/auth/login', []);

        // Should get validation error, not 404
        $response->assertStatus(422);
    }

    /**
     * Test API version endpoint
     */
    public function test_api_version_endpoint(): void
    {
        $response = $this->get('/api/version');

        // Accept 200 or 404
        $this->assertContains($response->status(), [200, 404]);
    }

    /**
     * Test receipt endpoint requires authentication
     */
    public function test_receipt_endpoint_requires_auth(): void
    {
        $response = $this->getJson('/api/recibo/1');

        $response->assertStatus(401);
    }

    /**
     * Test boleto endpoint requires authentication
     */
    public function test_boleto_endpoint_requires_auth(): void
    {
        $response = $this->getJson('/api/boletoitau/1');

        $response->assertStatus(401);
    }

    /**
     * Test payment endpoint requires authentication
     */
    public function test_payment_endpoint_requires_auth(): void
    {
        $response = $this->postJson('/api/cobrancas/pagto/1', ['valor' => 100.00]);

        $response->assertStatus(401);
    }

    /**
     * Test cache is working
     */
    public function test_cache_working(): void
    {
        $key = 'test_smoke_' . time();
        $value = 'test_value_' . uniqid();

        cache()->put($key, $value, 60);
        $retrieved = cache()->get($key);

        $this->assertEquals($value, $retrieved);

        // Cleanup
        cache()->forget($key);
    }

    /**
     * Test PHP version compatibility
     */
    public function test_php_version_minimum(): void
    {
        $this->assertGreaterThanOrEqual(
            '7.4.0',
            PHP_VERSION,
            'PHP version must be at least 7.4.0'
        );
    }

    /**
     * Test required PHP extensions
     */
    public function test_required_php_extensions(): void
    {
        $required = ['pdo', 'pdo_mysql', 'json', 'mbstring', 'openssl', 'tokenizer'];

        foreach ($required as $ext) {
            $this->assertTrue(
                extension_loaded($ext),
                "Required extension missing: $ext"
            );
        }
    }

    /**
     * Test PHP 8.1 specific extensions (if on PHP 8.1)
     */
    public function test_php81_specific_extensions(): void
    {
        if (version_compare(PHP_VERSION, '8.1.0', '<')) {
            $this->markTestSkipped('PHP 8.1+ required for this test');
        }

        $required81 = ['intl']; // Required for NumberFormatter in money_format shim

        foreach ($required81 as $ext) {
            $this->assertTrue(
                extension_loaded($ext),
                "PHP 8.1 required extension missing: $ext"
            );
        }
    }
}
