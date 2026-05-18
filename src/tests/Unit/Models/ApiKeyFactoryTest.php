<?php

declare(strict_types=1);

namespace Tests\Unit\Models;

use App\Models\ApiKey;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ApiKeyFactoryTest extends TestCase
{
    use RefreshDatabase;

    public function test_factory_creates_persisted_api_key(): void
    {
        $apiKey = ApiKey::factory()->create();

        $this->assertDatabaseHas('api_keys', [
            'id' => $apiKey->id,
            'is_active' => true,
        ]);
        $this->assertStringStartsWith('ak_', $apiKey->key);
    }

    public function test_factory_expired_state(): void
    {
        $apiKey = ApiKey::factory()->expired()->create();

        $this->assertTrue($apiKey->isExpired());
    }
}
