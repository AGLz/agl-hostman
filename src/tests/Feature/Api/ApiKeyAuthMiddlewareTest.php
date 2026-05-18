<?php

declare(strict_types=1);

use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

beforeEach(function () {
    config([
        'services.hostman.api_key' => 'feature-daily-memory-key',
        'security.allow_query_api_key' => false,
    ]);
});

describe('api.key middleware on /api/daily-memory', function () {
    it('rejects requests without an api key', function () {
        $this->getJson(route('api.daily-memory.index'))
            ->assertUnauthorized()
            ->assertJsonPath('error', 'API key required');
    });

    it('rejects invalid api keys', function () {
        $this->withHeader('X-API-Key', 'not-a-valid-key')
            ->getJson(route('api.daily-memory.index'))
            ->assertForbidden()
            ->assertJsonPath('error', 'Invalid API key');
    });

    it('allows valid api key via X-API-Key header', function () {
        $this->withHeader('X-API-Key', 'feature-daily-memory-key')
            ->getJson(route('api.daily-memory.index'))
            ->assertOk()
            ->assertJsonStructure([
                'data',
                'current_page',
                'per_page',
            ]);
    });

    it('allows valid api key via Authorization bearer', function () {
        $this->withHeader('Authorization', 'Bearer feature-daily-memory-key')
            ->getJson(route('api.daily-memory.index'))
            ->assertOk();
    });

    it('ignores api key in query when allow_query_api_key is false', function () {
        $this->getJson(route('api.daily-memory.index', ['api_key' => 'feature-daily-memory-key']))
            ->assertUnauthorized();
    });

    it('accepts api key in query when allow_query_api_key is true', function () {
        config(['security.allow_query_api_key' => true]);

        $this->getJson(route('api.daily-memory.index', ['api_key' => 'feature-daily-memory-key']))
            ->assertOk();
    });
});
