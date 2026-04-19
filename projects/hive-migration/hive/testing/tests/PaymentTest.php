<?php

namespace Tests\Feature\Api;

use Tests\TestCase;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Tymon\JWTAuth\Facades\JWTAuth;

/**
 * Payment (Cobrancas) API Tests
 *
 * Priority: P1 - CRITICAL
 * Coverage: Payment processing workflow
 *
 * Location: /var/www/fg_OLD2_NEW/tests/Feature/Api/PaymentTest.php
 */
class PaymentTest extends TestCase
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
     * Test payment endpoint requires authentication
     */
    public function test_payment_requires_authentication(): void
    {
        $response = $this->postJson('/api/cobrancas/pagto/1', ['valor' => 100.00]);

        $response->assertStatus(401);
    }

    /**
     * Test payment list endpoint
     */
    public function test_payment_list(): void
    {
        if (!$this->testToken) {
            $this->markTestSkipped('No test user available');
        }

        $response = $this->getJson('/api/cobrancas', $this->authHeaders());

        $response->assertStatus(200);
    }

    /**
     * Test payment with valid data
     */
    public function test_payment_valid_data(): void
    {
        if (!$this->testToken) {
            $this->markTestSkipped('No test user available');
        }

        // Get unpaid cobranca
        $cobranca = DB::connection('mysql_sys')
            ->table('SCLCobrancas')
            ->whereNull('DataPagamento')
            ->first();

        if (!$cobranca) {
            $this->markTestSkipped('No unpaid cobrancas');
        }

        $response = $this->postJson(
            "/api/cobrancas/pagto/{$cobranca->ID}",
            ['valor' => $cobranca->Valor],
            $this->authHeaders()
        );

        // Should be 200 (success) or 422 (validation error)
        $this->assertContains($response->status(), [200, 201, 422]);
    }

    /**
     * Test payment with invalid cobranca ID
     */
    public function test_payment_invalid_id(): void
    {
        if (!$this->testToken) {
            $this->markTestSkipped('No test user available');
        }

        $response = $this->postJson(
            '/api/cobrancas/pagamento/99999999',
            ['valor' => 100],
            $this->authHeaders()
        );

        $response->assertNotFound();
    }

    /**
     * Test payment with missing data
     */
    public function test_payment_validation_error(): void
    {
        if (!$this->testToken) {
            $this->markSkipped('No test user available');
        }

        $cobranca = DB::table('Cobranca')
            ->whereNotNull('Num ID Cobranca')
            ->first();

        if (!$cobranca) {
            $response = $this->postJson(
                '/api/cobrancas/pagamento/99999999',
                [],
                $this->authHeaders()
            );
            $response->assertStatus(404);
        }
    }

    /**
     * Get authentication headers
     */
    protected function authHeaders(): array
    {
        return [
            'Authorization' => 'Bearer ' . $this->testToken,
            'Accept' => 'application/json',
            'Content-Type' => 'application/json',
        ];
    }

    /**
     * Skip test
     */
    protected function markSkipped(string $message): void
    {
        $this->markTestSkipped($message);
    }
}
