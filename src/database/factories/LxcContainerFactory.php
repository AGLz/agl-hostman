<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\LxcContainer;
use App\Models\ProxmoxServer;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\LxcContainer>
 */
class LxcContainerFactory extends Factory
{
    protected $model = LxcContainer::class;

    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'vmid' => fake()->unique()->numberBetween(100, 999),
            'name' => fake()->unique()->slug(2),
            'hostname' => fake()->domainWord() . '.local',
            'status' => fake()->randomElement(['running', 'stopped', 'paused']),
            'proxmox_server_id' => ProxmoxServer::factory(),
            'memory' => fake()->randomElement([512, 1024, 2048, 4096, 8192]),
            'cores' => fake()->randomElement([1, 2, 4, 8]),
            'disk_size' => fake()->randomElement([8, 16, 32, 64, 128]),
            'ip_address' => fake()->ipv4(),
            'template' => 'ubuntu-22.04-standard',
            'description' => fake()->optional()->sentence(),
            'tags' => fake()->optional()->words(3),
            'is_template' => false,
            'is_protected' => false,
            'autostart' => fake()->boolean(70),
            'created_at' => fake()->dateTimeBetween('-1 year', 'now'),
            'updated_at' => now(),
        ];
    }

    /**
     * Container in running state
     */
    public function running(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'running',
        ]);
    }

    /**
     * Container in stopped state
     */
    public function stopped(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'stopped',
        ]);
    }

    /**
     * High resource container
     */
    public function highResource(): static
    {
        return $this->state(fn (array $attributes) => [
            'memory' => 16384,
            'cores' => 16,
            'disk_size' => 256,
        ]);
    }

    /**
     * Low resource container
     */
    public function lowResource(): static
    {
        return $this->state(fn (array $attributes) => [
            'memory' => 512,
            'cores' => 1,
            'disk_size' => 8,
        ]);
    }

    /**
     * Container with specific VMID
     */
    public function withVmid(int $vmid): static
    {
        return $this->state(fn (array $attributes) => [
            'vmid' => $vmid,
        ]);
    }

    /**
     * Protected container that cannot be deleted
     */
    public function protected(): static
    {
        return $this->state(fn (array $attributes) => [
            'is_protected' => true,
        ]);
    }

    /**
     * Template container
     */
    public function template(): static
    {
        return $this->state(fn (array $attributes) => [
            'is_template' => true,
            'status' => 'stopped',
        ]);
    }
}
