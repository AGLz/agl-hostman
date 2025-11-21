<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\ProxmoxServer;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\ProxmoxServer>
 */
class ProxmoxServerFactory extends Factory
{
    protected $model = ProxmoxServer::class;

    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'name' => 'pve-' . fake()->unique()->word(),
            'host' => fake()->unique()->domainName(),
            'port' => 8006,
            'username' => 'root@pam',
            'password' => encrypt('test-password'),
            'realm' => 'pam',
            'is_active' => true,
            'is_cluster_member' => fake()->boolean(30),
            'cluster_name' => fake()->optional()->word(),
            'total_memory' => fake()->randomElement([32768, 65536, 131072, 262144]),
            'total_cpu' => fake()->randomElement([8, 16, 32, 64]),
            'total_storage' => fake()->randomElement([512, 1024, 2048, 4096]),
            'api_token' => fake()->optional()->sha256(),
            'description' => fake()->optional()->sentence(),
            'location' => fake()->optional()->city(),
            'created_at' => fake()->dateTimeBetween('-2 years', 'now'),
            'updated_at' => now(),
        ];
    }

    /**
     * Active server
     */
    public function active(): static
    {
        return $this->state(fn (array $attributes) => [
            'is_active' => true,
        ]);
    }

    /**
     * Inactive server
     */
    public function inactive(): static
    {
        return $this->state(fn (array $attributes) => [
            'is_active' => false,
        ]);
    }

    /**
     * Cluster member server
     */
    public function clusterMember(string $clusterName = 'production'): static
    {
        return $this->state(fn (array $attributes) => [
            'is_cluster_member' => true,
            'cluster_name' => $clusterName,
        ]);
    }

    /**
     * Standalone server
     */
    public function standalone(): static
    {
        return $this->state(fn (array $attributes) => [
            'is_cluster_member' => false,
            'cluster_name' => null,
        ]);
    }

    /**
     * High capacity server
     */
    public function highCapacity(): static
    {
        return $this->state(fn (array $attributes) => [
            'total_memory' => 524288, // 512GB
            'total_cpu' => 128,
            'total_storage' => 8192, // 8TB
        ]);
    }
}
