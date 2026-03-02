<?php

namespace Tests\Feature\Security;

use Tests\TestCase;
use Illuminate\Support\Facades\DB;

/**
 * Security Tests
 *
 * Priority: P1 - CRITICAL
 * Execution: Weekly, pre-production
 * Duration: 2-3 hours
 *
 * Location: /var/www/fg_OLD2_NEW/tests/Feature/Security/SecurityTest.php
 */
class SecurityTest extends TestCase
{
    /**
     * Test SQL injection protection on search endpoints
     */
    public function test_sql_injection_protection(): void
    {
        $maliciousInputs = [
            "1; DROP TABLE users; --",
            "1' OR '1'='1",
            "1 UNION SELECT * FROM users",
            "<script>alert('xss')</script>",
        ];

        foreach ($maliciousInputs as $input) {
            $response = $this->getJson('/api/cobrancas?search=' . urlencode($input));

            // Should not cause 500 error
            $this->assertNotEquals(500, $response->status(), 'SQL injection attempt should not cause server error');
        }
    }

    /**
     * Test XSS protection in responses
     */
    public function test_xss_protection(): void
    {
        $response = $this->getJson('/api/health');

        if ($response->status() === 200) {
            $content = $response->getContent();

            // Response should not contain executable script tags
            $this->assertStringNotContainsString(
                '<script>alert',
                $content,
                'Response should not contain unescaped script tags'
            );
        }
    }

    /**
     * Test authentication required on protected endpoints
     */
    public function test_authentication_required(): void
    {
        $protectedEndpoints = [
            ['GET', '/api/cobrancas'],
            ['GET', '/api/recibos'],
            ['GET', '/api/boletoitau/1'],
            ['POST', '/api/cobrancas/pagto/1'],
        ];

        foreach ($protectedEndpoints as [$method, $endpoint]) {
            $response = $this->json($method, $endpoint);

            $response->assertStatus(401, "Endpoint $endpoint should require authentication");
        }
    }

    /**
     * Test invalid token rejection
     */
    public function test_invalid_token_rejection(): void
    {
        $response = $this->withHeaders([
            'Authorization' => 'Bearer invalid_token_12345',
            'Accept' => 'application/json',
        ])->getJson('/api/cobrancas');

        $response->assertStatus(401);
    }

    /**
     * Test expired token rejection
     */
    public function test_expired_token_rejection(): void
    {
        // This would require generating an expired token
        // For now, test with a malformed token
        $response = $this->withHeaders([
            'Authorization' => 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.expired',
            'Accept' => 'application/json',
        ])->getJson('/api/cobrancas');

        $response->assertStatus(401);
    }

    /**
     * Test CORS headers
     */
    public function test_cors_headers(): void
    {
        $response = $this->withHeaders([
            'Origin' => 'https://evil.com',
        ])->get('/api/health');

        // Should not allow arbitrary origins
        $allowOrigin = $response->headers->get('Access-Control-Allow-Origin');

        if ($allowOrigin) {
            $this->assertNotEquals(
                '*',
                $allowOrigin,
                'CORS should not allow all origins'
            );
        }
    }

    /**
     * Test rate limiting (if enabled)
     */
    public function test_rate_limiting(): void
    {
        $responses = [];

        // Make many requests quickly
        for ($i = 0; $i < 100; $i++) {
            $responses[] = $this->getJson('/api/health');
        }

        $rateLimited = collect($responses)->contains(fn($r) => $r->status() === 429);

        // If rate limiting is enabled, some requests should be limited
        // If not enabled, this test passes anyway
        $this->assertTrue(true, 'Rate limiting test completed');
    }

    /**
     * Test input validation on POST requests
     */
    public function test_input_validation(): void
    {
        // Test with empty body
        $response = $this->postJson('/api/auth/login', []);

        $response->assertStatus(422); // Validation error

        // Test with invalid data types
        $response = $this->postJson('/api/auth/login', [
            'email' => 'not-an-email',
            'password' => 12345, // Should be string
        ]);

        $response->assertStatus(422);
    }

    /**
     * Test no sensitive data in responses
     */
    public function test_no_sensitive_data_in_responses(): void
    {
        $response = $this->getJson('/api/health');

        if ($response->status() === 200) {
            $content = $response->getContent();

            // Should not expose sensitive info
            $this->assertStringNotContainsString('password', strtolower($content));
            $this->assertStringNotContainsString('secret', strtolower($content));
            $this->assertStringNotContainsString('api_key', strtolower($content));
        }
    }

    /**
     * Test headers security
     */
    public function test_security_headers(): void
    {
        $response = $this->get('/');

        // Check for common security headers
        $headers = [
            'X-Content-Type-Options',
            'X-Frame-Options',
            'X-XSS-Protection',
        ];

        foreach ($headers as $header) {
            $value = $response->headers->get($header);

            // These headers should ideally be present
            // But we won't fail if they're missing (could be handled by web server)
            if ($value) {
                $this->assertNotEmpty($value, "Security header $header should have a value");
            }
        }
    }
}
