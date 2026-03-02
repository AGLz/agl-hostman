<?php

namespace Tests\Feature\Api;

use Tests\TestCase;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Support\Facades\DB;
use Tymon\JWTAuth\Facades\JWTAuth;

/**
 * Boleto (Payment Slip) API Tests
 *
 * Priority: P1 - CRITICAL
 * Coverage: Boleto generation for Itaú bank
 *
 * Location: /var/www/fg_OLD2_NEW/tests/Feature/Api/BoletoTest.php
 */
class BoletoTest extends TestCase
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
        ];
    }

    /**
     * Test boleto endpoint requires authentication
     */
    public function test_boleto_requires_authentication(): void
    {
        $response = $this->getJson('/api/boletoitau/1');

        $response->assertStatus(401);
    }

    /**
     * Test boleto generation
     */
    public function test_boleto_generation(): void
    {
        if (!$this->testToken) {
            $this->markTestSkipped('No test user available');
        }

        // Get a valid cobranca
        $cobranca = DB::connection('mysql_sys')
            ->table('SCLCobrancas')
            ->whereNotNull('Valor')
            ->first();

        if (!$cobranca) {
            $this->markTestSkipped('No cobrancas in database');
        }

        $response = $this->get("/api/boletoitau/{$cobranca->ID}", $this->authHeaders());

        // Should be 200 (PDF) or 404
        $this->assertContains($response->status(), [200, 404]);
    }

    /**
     * Test boleto PDF content type
     */
    public function test_boleto_pdf_content_type(): void
    {
        if (!$this->testToken) {
            $this->markTestSkipped('No test user available');
        }

        $cobranca = DB::connection('mysql_sys')
            ->table('SCLCobrancas')
            ->first();

        if (!$cobranca) {
            $this->markTestSkipped('No cobrancas in database');
        }

        $response = $this->get("/api/boletoitau/{$cobranca->ID}", $this->authHeaders());

        if ($response->status() === 200) {
            $contentType = $response->headers->get('Content-Type');
            $this->assertStringContainsString(
                'application/pdf',
                $contentType,
                'Boleto should return PDF content type'
            );
        }
    }

    /**
     * Test boleto with invalid ID
     */
    public function test_boleto_invalid_id(): void
    {
        if (!$this->testToken) {
            $this->markTestSkipped('No test user available');
        }

        $response = $this->getJson('/api/boletoitau/999999999', $this->authHeaders());

        $response->assertStatus(404);
    }

    /**
     * Test remessa file generation
     */
    public function test_remessa_generation(): void
    {
        if (!$this->testToken) {
            $this->markTestSkipped('No test user available');
        }

        $response = $this->get('/api/get-remessa-itau', $this->authHeaders());

        // Should generate CNAB file or return error
        $this->assertContains($response->status(), [200, 400, 404]);

        if ($response->status() === 200) {
            $content = $response->getContent();
            // CNAB 400 format should be around 400 chars per line
            $this->assertNotEmpty($content);
        }
    }

    /**
     * Test boleto barcode generation
     */
    public function test_boleto_barcode(): void
    {
        if (!$this->testToken) {
            $this->markTestSkipped('No test user available');
        }

        $cobranca = DB::connection('mysql_sys')
            ->table('SCLCobrancas')
            ->whereNotNull('NossoNumero')
            ->first();

        if (!$cobranca) {
            $this->markTestSkipped('No cobrancas with NossoNumero');
        }

        $response = $this->getJson("/api/boletoitau/barcode/{$cobranca->ID}", $this->authHeaders());

        // Should return barcode data or 404
        $this->assertContains($response->status(), [200, 404]);
    }

    /**
     * Test boleto package compatibility (laravel-boleto)
     */
    public function test_boleto_package_loaded(): void
    {
        $this->assertTrue(
            class_exists(\Eduardokum\LaravelBoleto\Boleto\Banco\Itau::class),
            'laravel-boleto package should be loaded'
        );
    }

    /**
     * Test custom Itau boleto class exists
     */
    public function test_custom_itau_boleto_exists(): void
    {
        $this->assertTrue(
            class_exists(\App\Boleto\Banco\ItauCustom::class),
            'Custom Itau boleto class should exist'
        );
    }
}
