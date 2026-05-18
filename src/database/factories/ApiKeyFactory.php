<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\ApiKey;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * @extends Factory<ApiKey>
 */
class ApiKeyFactory extends Factory
{
    protected $model = ApiKey::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'name' => \fake()->words(2, true),
            'key' => 'ak_'.\fake()->unique()->regexify('[A-Za-z0-9]{32}'),
            'secret' => hash('sha256', Str::random(64)),
            'user_id' => User::factory(),
            'permissions' => ['read'],
            'rate_limit' => 60,
            'expires_at' => null,
            'last_used_at' => null,
            'last_ip' => null,
            'usage_count' => 0,
            'is_active' => true,
            'metadata' => null,
        ];
    }

    public function inactive(): static
    {
        return $this->state(fn (array $attributes) => [
            'is_active' => false,
        ]);
    }

    public function expired(): static
    {
        return $this->state(fn (array $attributes) => [
            'expires_at' => now()->subDay(),
        ]);
    }
}
