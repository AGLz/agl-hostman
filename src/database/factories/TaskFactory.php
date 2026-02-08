<?php

namespace Database\Factories;

use App\Models\Sprint;
use App\Models\Story;
use App\Models\Task;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\Task>
 */
class TaskFactory extends Factory
{
    protected $model = Task::class;

    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        $taskTypes = [
            ['title' => 'Implement user authentication', 'category' => 'feature'],
            ['title' => 'Fix login form validation', 'category' => 'bug'],
            ['title' => 'Refactor database queries', 'category' => 'refactor'],
            ['title' => 'Write API documentation', 'category' => 'documentation'],
            ['title' => 'Create unit tests for controller', 'category' => 'testing'],
            ['title' => 'Design dashboard UI', 'category' => 'design'],
            ['title' => 'Setup CI/CD pipeline', 'category' => 'infrastructure'],
            ['title' => 'Research caching strategies', 'category' => 'research'],
            ['title' => 'Implement password reset', 'category' => 'feature'],
            ['title' => 'Optimize database indexes', 'category' => 'performance'],
        ];

        $task = fake()->randomElement($taskTypes);

        return [
            'title' => $task['title'],
            'description' => fake()->optional(0.7)->paragraphs(2),
            'status' => fake()->randomElement(['backlog', 'todo', 'in_progress', 'review', 'done']),
            'priority' => fake()->randomElement(['low', 'medium', 'high', 'critical']),
            'story_points' => fake()->randomElement([null, 1, 2, 3, 5, 8]),
            'sprint_id' => fake()->optional(0.4)->randomElement(Sprint::pluck('id')->toArray()),
            'story_id' => fake()->optional(0.3)->randomElement(Story::pluck('id')->toArray()),
            'assigned_to' => fake()->optional(0.6)->randomElement(User::pluck('id')->toArray()),
            'created_by' => User::factory(),
            'location_id' => null,
            'epic' => fake()->optional(0.4)->randomElement([
                'Authentication & Authorization',
                'Dashboard & Analytics',
                'User Management',
                'API Development',
                'Infrastructure Setup',
            ]),
            'tags' => fake()->optional(0.5)->randomElements([
                'frontend',
                'backend',
                'api',
                'database',
                'ui',
                'security',
                'performance',
            ], rand(1, 3)),
            'attachments' => fake()->optional(0.1)->randomElements([
                ['name' => 'screenshot.png', 'url' => fake()->url()],
                ['name' => 'document.pdf', 'url' => fake()->url()],
            ], rand(1, 2)),
            'started_at' => fake()->optional(0.4)->dateTimeBetween('-1 month', 'now'),
            'completed_at' => fake()->optional(0.3)->dateTimeBetween('-1 month', 'now'),
        ];
    }

    /**
     * Indicate that the task is in the backlog
     */
    public function backlog(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'backlog',
            'sprint_id' => null,
        ]);
    }

    /**
     * Indicate that the task is in progress
     */
    public function inProgress(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'in_progress',
            'started_at' => now()->subDays(rand(1, 5)),
        ]);
    }

    /**
     * Indicate that the task is completed
     */
    public function completed(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'done',
            'started_at' => now()->subDays(rand(3, 10)),
            'completed_at' => now()->subDays(rand(1, 2)),
        ]);
    }

    /**
     * Indicate that the task is in review
     */
    public function inReview(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'review',
            'started_at' => now()->subDays(rand(1, 5)),
        ]);
    }

    /**
     * Indicate that the task has high priority
     */
    public function highPriority(): static
    {
        return $this->state(fn (array $attributes) => [
            'priority' => 'high',
        ]);
    }

    /**
     * Indicate that the task has critical priority
     */
    public function criticalPriority(): static
    {
        return $this->state(fn (array $attributes) => [
            'priority' => 'critical',
        ]);
    }

    /**
     * Indicate that the task is assigned
     */
    public function assigned(): static
    {
        return $this->state(fn (array $attributes) => [
            'assigned_to' => User::factory(),
        ]);
    }

    /**
     * Indicate that the task is unassigned
     */
    public function unassigned(): static
    {
        return $this->state(fn (array $attributes) => [
            'assigned_to' => null,
        ]);
    }

    /**
     * Indicate that the task has story points
     */
    public function withPoints(): static
    {
        return $this->state(fn (array $attributes) => [
            'story_points' => fake()->randomElement([1, 2, 3, 5, 8]),
        ]);
    }
}
