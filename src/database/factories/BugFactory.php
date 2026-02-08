<?php

namespace Database\Factories;

use App\Models\Bug;
use App\Models\Sprint;
use App\Models\Story;
use App\Models\Task;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\Bug>
 */
class BugFactory extends Factory
{
    protected $model = Bug::class;

    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'title' => fake()->randomElement([
                'Fix authentication issue',
                'Resolve database connection error',
                'Fix UI alignment problem',
                'Resolve performance bottleneck',
                'Fix memory leak',
                'Fix race condition',
                'Fix security vulnerability',
                'Fix broken API endpoint',
                'Fix typo in documentation',
                'Fix responsive design issue',
            ]),
            'description' => fake()->optional(0.7)->paragraphs(2),
            'severity' => fake()->randomElement(['trivial', 'low', 'medium', 'high', 'critical', 'blocker']),
            'priority' => fake()->randomElement(['low', 'medium', 'high', 'critical']),
            'status' => fake()->randomElement(['open', 'assigned', 'in_progress', 'resolved', 'verified', 'closed']),
            'reproduction_steps' => fake()->optional(0.6)->randomElements([
                'Navigate to the affected page',
                'Click on the button',
                'Observe the error',
                'Check the console logs',
                'Try with different user permissions',
            ], rand(2, 4)),
            'expected_behavior' => fake()->optional(0.7)->sentence(),
            'actual_behavior' => fake()->optional(0.7)->sentence(),
            'environment' => fake()->randomElement(['production', 'staging', 'development', 'testing']),
            'sprint_id' => fake()->optional(0.3)->randomElement(Sprint::pluck('id')->toArray()),
            'story_id' => fake()->optional(0.2)->randomElement(Story::pluck('id')->toArray()),
            'task_id' => fake()->optional(0.2)->randomElement(Task::pluck('id')->toArray()),
            'reported_by' => User::factory(),
            'assigned_to' => fake()->optional(0.6)->randomElement(User::pluck('id')->toArray()),
            'found_in_version' => fake()->optional(0.5)->semver(),
            'resolved_in_version' => fake()->optional(0.2)->semver(),
            'labels' => fake()->optional(0.5)->randomElements([
                'frontend',
                'backend',
                'database',
                'api',
                'ui',
                'security',
                'performance',
                'regression',
            ], rand(1, 2)),
            'reported_at' => fake()->dateTimeBetween('-2 months', 'now'),
            'resolved_at' => fake()->optional(0.3)->dateTimeBetween('-1 month', 'now'),
            'verified_at' => fake()->optional(0.2)->dateTimeBetween('-1 month', 'now'),
        ];
    }

    /**
     * Indicate that the bug is critical
     */
    public function critical(): static
    {
        return $this->state(fn (array $attributes) => [
            'severity' => 'critical',
            'priority' => 'critical',
            'status' => fake()->randomElement(['open', 'assigned', 'in_progress']),
        ]);
    }

    /**
     * Indicate that the bug is a blocker
     */
    public function blocker(): static
    {
        return $this->state(fn (array $attributes) => [
            'severity' => 'blocker',
            'priority' => 'critical',
            'status' => fake()->randomElement(['open', 'assigned', 'in_progress']),
        ]);
    }

    /**
     * Indicate that the bug is open
     */
    public function open(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'open',
            'assigned_to' => null,
        ]);
    }

    /**
     * Indicate that the bug is resolved
     */
    public function resolved(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'resolved',
            'resolved_at' => now()->subDays(rand(1, 5)),
        ]);
    }

    /**
     * Indicate that the bug is verified
     */
    public function verified(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'verified',
            'resolved_at' => now()->subDays(rand(5, 10)),
            'verified_at' => now()->subDays(rand(1, 3)),
        ]);
    }

    /**
     * Indicate that the bug was found in production
     */
    public function production(): static
    {
        return $this->state(fn (array $attributes) => [
            'environment' => 'production',
            'severity' => fake()->randomElement(['high', 'critical', 'blocker']),
        ]);
    }
}
