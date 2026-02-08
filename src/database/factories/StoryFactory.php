<?php

namespace Database\Factories;

use App\Models\Story;
use App\Models\Sprint;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\Story>
 */
class StoryFactory extends Factory
{
    protected $model = Story::class;

    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'title' => fake()->sentence() . ' as a ' . fake()->randomElement(['user', 'admin', 'developer', 'manager']),
            'description' => fake()->optional(0.7)->paragraphs(2),
            'acceptance_criteria' => fake()->optional(0.6)->randomElements([
                'User can successfully log in',
                'Data is persisted to database',
                'API returns correct response',
                'UI is responsive on mobile devices',
                'Error handling works properly',
                'Performance meets requirements',
            ], rand(2, 4)),
            'user_role' => fake()->randomElement(['user', 'admin', 'developer', 'manager', 'guest']),
            'story_points' => fake()->randomElement([null, 1, 2, 3, 5, 8, 13]),
            'priority' => fake()->randomElement(['low', 'medium', 'high', 'critical']),
            'status' => fake()->randomElement(['backlog', 'refined', 'planned', 'in_progress', 'testing', 'done']),
            'epic' => fake()->optional(0.5)->randomElement([
                'Authentication & Authorization',
                'Dashboard & Analytics',
                'User Management',
                'API Development',
                'Infrastructure Setup',
                'Testing & QA',
                'Documentation',
            ]),
            'sprint_id' => fake()->optional(0.4)->randomElement(Sprint::pluck('id')->toArray()),
            'created_by' => User::factory(),
            'business_value' => fake()->randomElement([0, 10, 30, 60, 100]),
            'complexity' => fake()->randomElement([1, 2, 3, 5, 8, 10]),
            'tags' => fake()->optional(0.5)->randomElements([
                'frontend',
                'backend',
                'api',
                'database',
                'ui',
                'performance',
                'security',
                'documentation',
            ], rand(1, 3)),
            'started_at' => fake()->optional(0.3)->dateTimeBetween('-1 month', 'now'),
            'completed_at' => fake()->optional(0.2)->dateTimeBetween('-1 month', 'now'),
        ];
    }

    /**
     * Indicate that the story is in the backlog
     */
    public function backlog(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'backlog',
            'sprint_id' => null,
        ]);
    }

    /**
     * Indicate that the story is in progress
     */
    public function inProgress(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'in_progress',
            'started_at' => now()->subDays(rand(1, 5)),
        ]);
    }

    /**
     * Indicate that the story is completed
     */
    public function completed(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'done',
            'started_at' => now()->subDays(rand(5, 15)),
            'completed_at' => now()->subDays(rand(1, 3)),
        ]);
    }

    /**
     * Indicate that the story has high priority
     */
    public function highPriority(): static
    {
        return $this->state(fn (array $attributes) => [
            'priority' => 'high',
        ]);
    }

    /**
     * Indicate that the story has critical priority
     */
    public function criticalPriority(): static
    {
        return $this->state(fn (array $attributes) => [
            'priority' => 'critical',
            'business_value' => 100,
        ]);
    }
}
