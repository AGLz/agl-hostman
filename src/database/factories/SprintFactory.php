<?php

namespace Database\Factories;

use App\Models\Sprint;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\Sprint>
 */
class SprintFactory extends Factory
{
    protected $model = Sprint::class;

    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        $startDate = fake()->dateTimeBetween('-1 month', '+1 month');
        $endDate = (clone $startDate)->modify('+'.rand(7, 21).' days');

        return [
            'name' => 'Sprint ' . fake()->numberBetween(1, 50),
            'goal' => fake()->optional(0.7)->sentence(),
            'start_date' => $startDate->format('Y-m-d'),
            'end_date' => $endDate->format('Y-m-d'),
            'status' => fake()->randomElement(['planning', 'active', 'review', 'completed']),
            'velocity' => fake()->numberBetween(20, 80),
            'created_by' => User::factory(),
        ];
    }

    /**
     * Indicate that the sprint is active
     */
    public function active(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'active',
            'start_date' => now()->subDays(rand(1, 7))->format('Y-m-d'),
            'end_date' => now()->addDays(rand(5, 10))->format('Y-m-d'),
        ]);
    }

    /**
     * Indicate that the sprint is in planning
     */
    public function planning(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'planning',
            'start_date' => now()->addDays(rand(3, 10))->format('Y-m-d'),
        ]);
    }

    /**
     * Indicate that the sprint is completed
     */
    public function completed(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'completed',
            'start_date' => now()->subDays(rand(20, 40))->format('Y-m-d'),
            'end_date' => now()->subDays(rand(5, 15))->format('Y-m-d'),
        ]);
    }
}
