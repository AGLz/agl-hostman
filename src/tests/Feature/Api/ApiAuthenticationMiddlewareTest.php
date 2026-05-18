<?php

declare(strict_types=1);

use App\Models\ApiKey;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Str;

uses(RefreshDatabase::class);

beforeEach(function () {
    config(['security.allow_query_api_key' => false]);

    Route::middleware('api.authentication')
        ->get('/api/_feature-test/api-authentication', function (\Illuminate\Http\Request $request) {
            return response()->json([
                'api_key_id' => $request->attributes->get('api_key')?->id,
            ]);
        });
});

describe('api.authentication middleware', function () {
    it('rejects requests without an api key', function () {
        $this->getJson('/api/_feature-test/api-authentication')
            ->assertUnauthorized()
            ->assertJsonPath('error', 'API key required');
    });

    it('rejects invalid database api keys', function () {
        $this->withHeader('X-API-Key', 'unknown-key')
            ->getJson('/api/_feature-test/api-authentication')
            ->assertUnauthorized()
            ->assertJsonPath('error', 'Invalid API key');
    });

    it('rejects expired database api keys', function () {
        $apiKey = ApiKey::factory()->expired()->create([
            'key' => 'expired-feature-' . Str::random(24),
            'is_active' => true,
        ]);

        $this->withHeader('X-API-Key', $apiKey->key)
            ->getJson('/api/_feature-test/api-authentication')
            ->assertUnauthorized()
            ->assertJsonPath('error', 'API key expired');
    });

    it('authenticates with a valid database api key', function () {
        $apiKey = ApiKey::factory()->create([
            'key' => 'valid-feature-' . Str::random(24),
        ]);

        $this->withHeader('X-API-Key', $apiKey->key)
            ->getJson('/api/_feature-test/api-authentication')
            ->assertOk()
            ->assertJsonPath('api_key_id', $apiKey->id)
            ->assertHeader('X-API-Key-ID', (string) $apiKey->id);
    });

    it('returns rate limit headers on success', function () {
        $apiKey = ApiKey::factory()->create([
            'key' => 'ratelimit-feature-' . Str::random(24),
            'rate_limit' => 42,
        ]);

        $this->withHeader('X-API-Key', $apiKey->key)
            ->getJson('/api/_feature-test/api-authentication')
            ->assertOk()
            ->assertHeader('X-RateLimit-Limit', '42');
    });
});
