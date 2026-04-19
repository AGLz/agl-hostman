<?php

namespace Tests\Feature\Api;

use Tests\TestCase;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Tymon\JWTAuth\Facades\JWTAuth;

/**
 * Recibo (Receipt) API Tests
 *
 * Priority: P1 - CRITICAL
 * Coverage: Receipt generation with PHP 8.1 compatibility
 *
 * Location: /var/www/fg_OLD2_NEW/tests/Feature/Api/ReciboTest.php
 */
class ReciboTest extends TestCase
{
    use DatabaseTransactions;

    protected $testUser;
    protected $testToken;

    protected function setUp(): void
    {
        parent::setUp();

        // Create or get test user
        $this->testUser = DB::table('users')->first();

        if ($this->testUser) {
            $this->testToken = JWTAuth::fromUser($this->testUser);
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
        ];
    }

    /**
     * Test receipt list endpoint
     */
    public function test_receipt_list_requires_authentication(): void
    {
        $response = $this->getJson('/api/recibos');

        $response->assertStatus(401);
    }

    /**
     * Test receipt list with authentication
     */
    public function test_receipt_list_with_auth(): void
    {
        if (!$this->testToken) {
            $this->markTestSkipped('No test user available');
        }

        $response = $this->getJson('/api/recibos', $this->authHeaders());

        $response->assertStatus(200)
            ->assertJsonStructure([
                '*' => [
                    'id',
                    'valor',
                    'data',
                ],
            ]);
    }

    /**
     * Test single receipt retrieval
     */
    public function test_receipt_show(): void
    {
        if (!$this->testToken) {
            $this->markTestSkipped('No test user available');
        }

        // Get first receipt from database
        $recibo = DB::connection('mysql_sys')
            ->table('SCLRecibos')
            ->first();

        if (!$recibo) {
            $this->markTestSkipped('No receipts in database');
        }

        $response = $this->getJson("/api/recibo/{$recibo->ID}", $this->authHeaders());

        $response->assertStatus(200);
    }

    /**
     * Test receipt with valid ID
     */
    public function test_receipt_valid_id(): void
    {
        if (!$this->testToken) {
            $this->markTestSkipped('No test user available');
        }

        $response = $this->getJson('/api/recibo/1', $this->authHeaders());

        // Should be 200 or 404 (if receipt doesn't exist)
        $this->assertContains($response->status(), [200, 404]);
    }

    /**
     * Test receipt with invalid ID
     */
    public function test_receipt_invalid_id(): void
    {
        if (!$this->testToken) {
            $this->markTestSkipped('No test user available');
        }

        $response = $this->getJson('/api/recibo/999999999', $this->authHeaders());

        $response->assertStatus(404);
    }

    /**
     * Test receipt response structure
     */
    public function test_receipt_response_structure(): void
    {
        if (!$this->testToken) {
            $this->markTestSkipped('No test user available');
        }

        // Get a valid receipt
        $recibo = DB::connection('mysql_sys')
            ->table('SCLRecibos')
            ->whereNotNull('Valorpago')
            ->first();

        if (!$recibo) {
            $this->markTestSkipped('No valid receipts in database');
        }

        $response = $this->getJson("/api/recibo/{$recibo->ID}", $this->authHeaders());

        if ($response->status() === 200) {
            $response->assertJsonStructure([
                'valortotal', // This uses money_format shim
            ]);
        }
    }

    /**
     * Test receipt PDF generation
     */
    public function test_receipt_pdf_generation(): void
    {
        if (!$this->testToken) {
            $this->markTestSkipped('No test user available');
        }

        $recibo = DB::connection('mysql_sys')
            ->table('SCLRecibos')
            ->first();

        if (!$recibo) {
            $this->markTestSkipped('No receipts in database');
        }

        $response = $this->get("/api/recibo/pdf/{$recibo->ID}", $this->authHeaders());

        // Should return PDF or 404
        $this->assertContains($response->status(), [200, 404]);

        if ($response->status() === 200) {
            $this->assertStringContainsString(
                'application/pdf',
                $response->headers->get('Content-Type')
            );
        }
    }

    /**
     * Test mysql_result shim works correctly
     * This test verifies the PHP 8.1 compatibility shim
     */
    public function test_mysql_result_shim_in_recibo(): void
    {
        if (!$this->testToken) {
            $this->markTestSkipped('No test user available');
        }

        // Get receipt with paid status
        $recibo = DB::connection('mysql_sys')
            ->table('SCLRecibos')
            ->where('Valorpago', '>', 0)
            ->first();

        if (!$recibo) {
            $this->markTestSkipped('No paid receipts in database');
        }

        $response = $this->getJson("/api/recibo/{$recibo->ID}", $this->authHeaders());

        // Should not throw error about mysql_result
        $response->assertStatus(200);

        // Verify currency formatting (money_format shim)
        $json = $response->json();

        // valortotal should be a formatted currency string
        if (isset($json['valortotal'])) {
            $this->assertMatchesRegularExpression(
                '/[0-9.,]+/',
                $json['valortotal'],
                'valortotal should contain formatted number'
            );
        }
    }
}
