<?php

declare(strict_types=1);

use App\Models\AgentRegistration;
use App\Models\ApiKey;
use App\Models\PhysicalLocation;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;

uses(RefreshDatabase::class);

beforeEach(function (): void {
    config([
        'auth-md.enabled' => true,
        'auth-md.auth_server_url' => 'https://ah.aglz.io',
        'auth-md.resource_url' => 'https://ah.aglz.io/api/',
        'auth-md.trusted_issuers' => [],
        'auth-md.flows.anonymous' => true,
        'auth-md.flows.email_claim' => true,
        'auth-md.flows.id_jag' => false,
    ]);
});

describe('auth.md discovery', function (): void {
    it('expõe auth.md na raiz do domínio', function (): void {
        $this->get('/auth.md')
            ->assertOk()
            ->assertHeader('content-type', 'text/markdown; charset=utf-8')
            ->assertSee('auth.md', false);
    });

    it('expõe Protected Resource Metadata', function (): void {
        $this->getJson('/.well-known/oauth-protected-resource')
            ->assertOk()
            ->assertJsonPath('resource', 'https://ah.aglz.io/api/')
            ->assertJsonPath('authorization_servers.0', 'https://ah.aglz.io');
    });

    it('expõe Authorization Server metadata com agent_auth', function (): void {
        $response = $this->getJson('/.well-known/oauth-authorization-server')
            ->assertOk();

        expect($response->json('agent_auth.register_uri'))->toBe('https://ah.aglz.io/agent/auth');
        expect($response->json('agent_auth.claim_uri'))->toBe('https://ah.aglz.io/agent/auth/claim');
    });

    it('retorna 404 quando auth.md está desactivado', function (): void {
        config(['auth-md.enabled' => false]);

        $this->get('/auth.md')->assertNotFound();
    });
});

describe('auth.md user claimed flows', function (): void {
    it('regista agente anonymous com api_key e claim_token', function (): void {
        $response = $this->postJson('/agent/auth', [
            'type' => 'anonymous',
            'requested_credential_type' => 'api_key',
        ]);

        $response->assertOk()
            ->assertJsonPath('registration_type', 'anonymous')
            ->assertJsonPath('credential_type', 'api_key')
            ->assertJsonStructure(['credential', 'claim_token', 'scopes']);

        expect(AgentRegistration::query()->count())->toBe(1);
    });

    it('completa claim anonymous com OTP', function (): void {
        $register = $this->postJson('/agent/auth', [
            'type' => 'anonymous',
            'requested_credential_type' => 'api_key',
        ])->json();

        $claimToken = $register['claim_token'];
        $email = 'agent-user@agl.test';

        $registration = AgentRegistration::query()->where('claim_token_hash', hash('sha256', $claimToken))->first();
        $otp = '482910';
        $registration->update([
            'otp_hash' => hash('sha256', $otp),
            'otp_expires_at' => now()->addMinutes(10),
            'claim_email' => $email,
        ]);

        User::factory()->create(['email' => $email]);

        $this->postJson('/agent/auth/claim/complete', [
            'claim_token' => $claimToken,
            'otp' => $otp,
        ])
            ->assertOk()
            ->assertJsonPath('status', 'claimed');
    });

    it('inicia registo email-required sem credencial', function (): void {
        $this->postJson('/agent/auth', [
            'type' => 'identity_assertion',
            'assertion_type' => 'verified_email',
            'assertion' => 'pending@agl.test',
            'requested_credential_type' => 'api_key',
        ])
            ->assertOk()
            ->assertJsonPath('registration_type', 'email-verification')
            ->assertJsonMissingPath('credential')
            ->assertJsonStructure(['claim_token']);
    });
});

describe('auth.md API key em rotas Sanctum', function (): void {
    it('autentica rotas auth:sanctum com api_key emitida por registo anonymous', function (): void {
        PhysicalLocation::create([
            'code' => 'AGLSRV1',
            'name' => 'AGL Server 1',
            'type' => 'datacenter',
        ]);

        $register = $this->postJson('/agent/auth', [
            'type' => 'anonymous',
            'requested_credential_type' => 'api_key',
        ])->json();

        $credential = $register['credential'];

        $this->withHeader('Authorization', 'Bearer ' . $credential)
            ->getJson('/api/infrastructure/locations')
            ->assertOk();
    });

    it('autentica com api_key existente na tabela api_keys', function (): void {
        $user = User::factory()->create();
        $apiKey = ApiKey::factory()->create([
            'user_id' => $user->id,
            'key' => 'sk_test_' . str_repeat('a', 40),
        ]);

        $this->withHeader('X-API-Key', $apiKey->key)
            ->getJson('/api/user')
            ->assertOk()
            ->assertJsonPath('email', $user->email);
    });
});

describe('auth.md API hints', function (): void {
    it('adiciona WWW-Authenticate em 401 da API', function (): void {
        $response = $this->getJson('/api/infrastructure/locations');

        $response->assertUnauthorized();
        $header = (string) $response->headers->get('WWW-Authenticate');
        expect($header)->toContain('resource_metadata=')
            ->and($header)->toContain('oauth-protected-resource');
    });
});
