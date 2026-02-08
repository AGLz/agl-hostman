<?php

namespace Database\Factories;

use App\Models\Sprint;
use App\Models\SprintMember;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\SprintMember>
 */
class SprintMemberFactory extends Factory
{
    protected $model = SprintMember::class;

    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'sprint_id' => Sprint::factory(),
            'user_id' => User::factory(),
            'role' => fake()->randomElement(['scrum_master', 'product_owner', 'developer', 'tester', 'designer', 'observer']),
            'capacity' => fake()->optional(0.5)->numberBetween(50, 100),
            'availability' => fake()->numberBetween(80, 100),
            'joined_at' => fake()->dateTimeBetween('-1 month', 'now'),
            'left_at' => fake()->optional(0.1)->dateTimeBetween('-1 week', 'now'),
        ];
    }

    /**
     * Indicate that the member is a developer
     */
    public function developer(): static
    {
        return $this->state(fn (array $attributes) => [
            'role' => 'developer',
        ]);
    }

    /**
     * Indicate that the member is a scrum master
     */
    public function scrumMaster(): static
    {
        return $this->state(fn (array $attributes) => [
            'role' => 'scrum_master',
        ]);
    }

    /**
     * Indicate that the member is a product owner
     */
    public function productOwner(): static
    {
        return $this->state(fn (array $attributes) => [
            'role' => 'product_owner',
        ]);
    }

    /**
     * Indicate that the member is a tester
     */
    public function tester(): static
    {
        return $this->state(fn (array $attributes) => [
            'role' => 'tester',
        ]);
    }

    /**
     * Indicate that the member is active
     */
    public function active(): static
    {
        return $this->state(fn (array $attributes) => [
            'left_at' => null,
        ]);
    }

    /**
     * Indicate that the member has full capacity
     */
    public function fullCapacity(): static
    {
        return $this->state(fn (array $attributes) => [
            'capacity' => 100,
            'availability' => 100,
        ]);
    }

    /**
     * Indicate that the member has partial capacity
     */
    public function partTime(): static
    {
        return $this->state(fn (array $attributes) => [
            'capacity' => fake()->numberBetween(25, 75),
            'availability' => fake()->numberBetween(50, 80),
        ]);
    }
}
