<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Alert;
use App\Models\User;
use App\Models\LxcContainer;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * Alert Factory
 *
 * @package Database\Factories
 */
class AlertFactory extends Factory
{
    /**
     * The name of the factory's corresponding model.
     *
     * @var string
     */
    protected $model = Alert::class;

    /**
     * Define the model's default state.
     *
     * @return array
     */
    public function definition(): array
    {
        return [
            'type' => $this->faker->randomElement(['critical', 'warning', 'info']),
            'title' => $this->faker->sentence(4),
            'message' => $this->faker->paragraph(),
            'source' => $this->faker->randomElement(['server', 'container', 'network', 'storage', 'system']),
            'source_id' => $this->faker->uuid(),
            'severity' => $this->faker->numberBetween(1, 100),
            'status' => $this->faker->randomElement(['active', 'acknowledged', 'resolved']),
            'acknowledged_by' => null,
            'acknowledged_at' => null,
            'resolved_by' => null,
            'resolved_at' => null,
            'metadata' => [
                'details' => $this->faker->sentence(),
                'affected_resources' => $this->faker->numberBetween(1, 10),
            ],
            'muted_until' => null,
        ];
    }

    /**
     * Indicate that the alert is critical
     *
     * @return static
     */
    public function critical(): static
    {
        return $this->state(fn (array $attributes) => [
            'type' => 'critical',
            'severity' => 90,
            'status' => 'active',
        ]);
    }

    /**
     * Indicate that the alert is a warning
     *
     * @return static
     */
    public function warning(): static
    {
        return $this->state(fn (array $attributes) => [
            'type' => 'warning',
            'severity' => $this->faker->numberBetween(60, 89),
            'status' => 'active',
        ]);
    }

    /**
     * Indicate that the alert is info
     *
     * @return static
     */
    public function info(): static
    {
        return $this->state(fn (array $attributes) => [
            'type' => 'info',
            'severity' => $this->faker->numberBetween(1, 59),
        ]);
    }

    /**
     * Indicate that the alert is active
     *
     * @return static
     */
    public function active(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'active',
        ]);
    }

    /**
     * Indicate that the alert is acknowledged
     *
     * @return static
     */
    public function acknowledged(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'acknowledged',
            'acknowledged_by' => User::factory(),
            'acknowledged_at' => now(),
        ]);
    }

    /**
     * Indicate that the alert is resolved
     *
     * @return static
     */
    public function resolved(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'resolved',
            'resolved_by' => User::factory(),
            'resolved_at' => now(),
        ]);
    }

    /**
     * Indicate that the alert is for a container
     *
     * @return static
     */
    public function forContainer(LxcContainer $container): static
    {
        return $this->state(fn (array $attributes) => [
            'source' => 'container',
            'source_id' => $container->id,
        ]);
    }

    /**
     * Indicate that the alert is muted
     *
     * @return static
     */
    public function muted(int $minutes = 60): static
    {
        return $this->state(fn (array $attributes) => [
            'muted_until' => now()->addMinutes($minutes),
        ]);
    }
}
