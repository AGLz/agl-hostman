<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\ContainerHealthLog;
use App\Models\LxcContainer;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * Container Health Log Factory
 */
class ContainerHealthLogFactory extends Factory
{
    /**
     * The name of the factory's corresponding model.
     *
     * @var string
     */
    protected $model = ContainerHealthLog::class;

    /**
     * Define the model's default state.
     */
    public function definition(): array
    {
        return [
            'container_id' => LxcContainer::factory(),
            'status' => $this->faker->randomElement(['healthy', 'unhealthy', 'degraded', 'unknown']),
            'cpu_usage' => $this->faker->randomFloat(2, 0, 100),
            'memory_usage' => $this->faker->randomFloat(2, 0, 100),
            'disk_usage' => $this->faker->randomFloat(2, 0, 100),
            'network_in' => $this->faker->randomFloat(2, 0, 1000),
            'network_out' => $this->faker->randomFloat(2, 0, 1000),
            'response_time' => $this->faker->randomFloat(2, 0, 5000),
            'metadata' => [
                'checked_by' => $this->faker->userName(),
                'check_method' => $this->faker->randomElement(['http', 'tcp', 'icmp', 'docker']),
                'notes' => $this->faker->optional()->sentence(),
            ],
            'checked_at' => $this->faker->dateTimeBetween('-30 days', 'now'),
        ];
    }

    /**
     * Indicate that the health log is healthy
     */
    public function healthy(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'healthy',
            'cpu_usage' => $this->faker->randomFloat(2, 0, 50),
            'memory_usage' => $this->faker->randomFloat(2, 0, 50),
            'disk_usage' => $this->faker->randomFloat(2, 0, 50),
            'response_time' => $this->faker->randomFloat(2, 0, 200),
        ]);
    }

    /**
     * Indicate that the health log is unhealthy
     */
    public function unhealthy(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'unhealthy',
            'cpu_usage' => $this->faker->randomFloat(2, 90, 100),
            'memory_usage' => $this->faker->randomFloat(2, 90, 100),
            'response_time' => $this->faker->randomFloat(2, 3000, 5000),
        ]);
    }

    /**
     * Indicate that the health log is degraded
     */
    public function degraded(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'degraded',
            'cpu_usage' => $this->faker->randomFloat(2, 70, 90),
            'memory_usage' => $this->faker->randomFloat(2, 70, 90),
        ]);
    }

    /**
     * Indicate that the health log is for a specific container
     */
    public function forContainer(LxcContainer $container): static
    {
        return $this->state(fn (array $attributes) => [
            'container_id' => $container->id,
        ]);
    }

    /**
     * Indicate that the health log is recent (last N hours)
     */
    public function recent(int $hours = 24): static
    {
        return $this->state(fn (array $attributes) => [
            'checked_at' => $this->faker->dateTimeBetween("-{$hours} hours", 'now'),
        ]);
    }

    /**
     * Indicate that the health log has high resource usage
     */
    public function highResourceUsage(): static
    {
        return $this->state(fn (array $attributes) => [
            'cpu_usage' => $this->faker->randomFloat(2, 80, 100),
            'memory_usage' => $this->faker->randomFloat(2, 80, 100),
            'disk_usage' => $this->faker->randomFloat(2, 80, 100),
        ]);
    }
}
