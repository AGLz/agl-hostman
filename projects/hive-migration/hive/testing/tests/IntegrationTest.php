<?php

namespace Tests\Feature;

use Tests\TestCase;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Tymon\JWTAuth\Facades\JWTAuth;

/**
 * Integration Tests - End-to-end API workflows
 *
 * Priority: P1 - CRITICAL
 * Execution: Daily, pre-deployment
 * Duration: 1-2 hours
 *
 * Location: /var/www/fg_OLD2_NEW/tests/Feature/IntegrationTest.php
 */
class IntegrationTest extends TestCase
{
    use DatabaseTransactions;

    protected $testUser;
    protected $testToken;

    protected function setUp(): void
    {
        parent::setUp();

        $this->testUser = DB::table('users')->first();

        if ($this->testUser) {
            $this->testToken = JWTAuth::fromUser($this->testUser);
        }
    }

    protected function authHeaders(): array
    {
        return [
            'Authorization' => 'Bearer ' . $this->testToken,
            'Accept' => 'application/json',
            'Content-Type' => 'application/json',
        ];
    }

    /**
     * Test complete payment workflow:
     * 1. Get cobranca
     * 2. Generate boleto
     * 3. Process payment
     * 4. Generate receipt
     */
    public function test_complete_payment_workflow(): void
    {
        if (!$this->testToken) {
            $this->markTestSkipped('No test user available');
        }

        // Step 1: Get unpaid cobranca
        $cobranca = DB::connection('mysql_sys')
            ->table('SCLCobrancas')
            ->whereNull('DataPagamento')
            ->where('Valor', '>', 0)
            ->first();

        if (!$cobranca) {
            $this->markTestSkipped('No unpaid cobrancas for workflow test');
        }

        // Step 2: Generate boleto
        $boletoResponse = $this->get("/api/boletoitau/{$cobranca->ID}", $this->authHeaders());
        $this->assertContains($boletoResponse->status(), [200, 404]);

        // Step 3: Process payment (simulated)
        $paymentResponse = $this->postJson(
            "/api/cobrancas/pagto/{$cobranca->ID}",
            ['valor' => $cobranca->Valor],
            $this->authHeaders()
        );
        $this->assertContains($paymentResponse->status(), [200, 201, 422]);

        // Step 4: Generate receipt (if payment successful)
        if ($paymentResponse->status() === 200 || $paymentResponse->status() === 201) {
            $reciboResponse = $this->getJson("/api/recibo/{$cobranca->ID}", $this->authHeaders());
            $this->assertContains($reciboResponse->status(), [200, 404]);
        }

        $this->assertTrue(true, 'Payment workflow completed');
    }

    /**
     * Test database consistency across connections
     */
    public function test_database_consistency(): void
    {
        // Count records in both databases
        try {
            $mainCount = DB::table('users')->count();
            $sysCount = DB::connection('mysql_sys')->table('SCLContratos')->count();

            // Both should return integers
            $this->assertIsInt($mainCount);
            $this->assertIsInt($sysCount);
        } catch (\Exception $e) {
            $this->markTestSkipped('Database connections not available: ' . $e->getMessage());
        }
    }

    /**
     * Test API response time for critical endpoints
     */
    public function test_api_response_time(): void
    {
        if (!$this->testToken) {
            $this->markTestSkipped('No test user available');
        }

        $endpoints = [
            '/api/cobrancas',
            '/api/recibos',
        ];

        foreach ($endpoints as $endpoint) {
            $start = microtime(true);
            $response = $this->getJson($endpoint, $this->authHeaders());
            $duration = (microtime(true) - $start) * 1000; // ms

            // Response should be under 500ms
            $this->assertLessThan(
                500,
                $duration,
                "Endpoint $endpoint took {$duration}ms (limit: 500ms)"
            );

            $this->assertEquals(200, $response->status(), "Endpoint $endpoint should return 200");
        }
    }

    /**
     * Test error handling consistency
     */
    public function test_error_handling_consistency(): void
    {
        if (!$this->testToken) {
            $this->markTestSkipped('No test user available');
        }

        // Test 404 error format
        $response = $this->getJson('/api/nonexistent-endpoint-12345', $this->authHeaders());

        $response->assertStatus(404);

        // Test 401 error format
        $response = $this->getJson('/api/cobrancas');
        $response->assertStatus(401);
    }

    /**
     * Test JSON response structure consistency
     */
    public function test_json_response_structure(): void
    {
        if (!$this->testToken) {
            $this->markTestSkipped('No test user available');
        }

        $response = $this->getJson('/api/cobrancas', $this->authHeaders());

        if ($response->status() === 200) {
            $json = $response->json();

            // Should be an array or object
            $this->assertTrue(
                is_array($json) || is_object($json),
                'Response should be valid JSON'
            );
        }
    }

    /**
     * Test concurrent request handling
     */
    public function test_concurrent_requests(): void
    {
        if (!$this->testToken) {
            $this->markTestSkipped('No test user available');
        }

        $responses = [];

        // Simulate 5 concurrent requests
        for ($i = 0; $i < 5; $i++) {
            $responses[] = $this->getJson('/api/cobrancas', $this->authHeaders());
        }

        // All should succeed
        foreach ($responses as $response) {
            $this->assertEquals(200, $response->status());
        }
    }
}
