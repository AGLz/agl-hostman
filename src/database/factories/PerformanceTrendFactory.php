<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\PerformanceTrend;
use App\Models\LxcContainer;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * Performance Trend Factory
 *
 * @package Database\Factories
 */
class PerformanceTrendFactory extends Factory
{
    /**
     * The name of the factory's corresponding model.
     *
     * @var string
     */
    protected $model = PerformanceTrend::class;

    /**
     * Define the model's default state.
     *
     * @return array
     */
    public function definition(): array
    {
        return [
            'resource_type' => $this->faker->randomElement(['container', 'server']),
            'resource_id' => (string) $this->faker->numberBetween(100, 999),
            'metric_type' => $this->faker->randomElement(['cpu', 'memory', 'disk', 'network']),
            'value' => $this->faker->randomFloat(2, 0, 100),
            'unit' => $this->faker->randomElement(['%', 'MB', 'GB', 'Mbps', 'ms']),
            'metadata' => [
                'recorded_by' => $this->faker->userName(),
                'notes' => $this->faker->optional()->sentence(),
            ],
            'recorded_at' => $this->faker->dateTimeBetween('-30 days', 'now'),
        ];
    }

    /**
     * Indicate that the trend is for CPU metric
     *
     * @return static
     */
    public function cpu(): static
    {
        return $this->state(fn (array $attributes) => [
            'metric_type' => 'cpu',
            'unit' => '%',
            'value' => $this->faker->randomFloat(2, 0, 100),
        ]);
    }

    /**
     * Indicate that the trend is for memory metric
     *
     * @return static
     */
    public function memory(): static
    {
        return $this->state(fn (array $attributes) => [
            'metric_type' => 'memory',
            'unit' => '%',
            'value' => $this->faker->randomFloat(2, 0, 100),
        ]);
    }

    /**
     * Indicate that the trend is for disk metric
     *
     * @return static
     */
    public function disk(): static
    {
        return $this->state(fn (array $attributes) => [
            'metric_type' => 'disk',
            'unit' => '%',
            'value' => $this->faker->randomFloat(2, 0, 100),
        ]);
    }

    /**
     * Indicate that the trend is for network metric
     *
     * @return static
     */
    public function network(): static
    {
        return $this->state(fn (array $attributes) => [
            'metric_type' => 'network',
            'unit' => 'Mbps',
            'value' => $this->faker->randomFloat(2, 0, 1000),
        ]);
    }

    /**
     * Indicate that the trend is for a container
     *
     * @return static
     */
    public function forContainer(LxcContainer $container): static
    {
        return $this->state(fn (array $attributes) => [
            'resource_type' => 'container',
            'resource_id' => $container->id,
        ]);
    }

    /**
     * Indicate that the trend is recent (last N hours)
     *
     * @return static
     */
    public function recent(int $hours = 24): static
    {
        return $this->state(fn (array $attributes) => [
            'recorded_at' => $this->faker->dateTimeBetween("-{$hours} hours", 'now'),
        ]);
    }

    /**
     * Indicate that the trend has high value (warning level)
     *
     * @return static
     */
    public function high(): static
    {
        return $this->state(fn (array $attributes) => [
            'value' => $this->faker->randomFloat(2, 80, 100),
        ]);
    }

    /**
     * Indicate that the trend has critical value
     *
     * @return static
     */
    public function critical(): static
    {
        return $this->state(fn (array $attributes) => [
            'value' => $this->faker->randomFloat(2, 90, 100),
        ]);
    }
}
