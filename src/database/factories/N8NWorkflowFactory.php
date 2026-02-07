<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\N8NWorkflow;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * N8N Workflow Factory
 *
 * @package Database\Factories
 */
class N8NWorkflowFactory extends Factory
{
    /**
     * The name of the factory's corresponding model.
     *
     * @var string
     */
    protected $model = N8NWorkflow::class;

    /**
     * Define the model's default state.
     *
     * @return array
     */
    public function definition(): array
    {
        $name = $this->faker->words(3, true);
        $category = $this->faker->randomElement([
            'automation',
            'monitoring',
            'deployment',
            'backup',
            'security',
            'notification',
            'integration',
        ]);

        return [
            'n8n_id' => $this->faker->uuid(),
            'name' => ucfirst($name),
            'slug' => str_slug($name),
            'description' => $this->faker->sentence(),
            'active' => $this->faker->boolean(70), // 70% chance of being active
            'category' => $category,
            'settings' => [
                'nodes' => [
                    [
                        'id' => $this->faker->uuid(),
                        'name' => 'Start',
                        'type' => 'n8n-nodes-base.start',
                    ],
                ],
            ],
            'metadata' => [
                'created_via' => 'factory',
                'version' => '1.0',
            ],
            'last_synced_at' => $this->faker->optional(0.7)->dateTimeBetween('-30 days', 'now'),
            'last_executed_at' => $this->faker->optional(0.5)->dateTimeBetween('-7 days', 'now'),
            'execution_count' => $this->faker->numberBetween(0, 1000),
            'tags' => $this->faker->randomElements(
                [$category, 'auto', 'production', 'testing'],
                $this->faker->numberBetween(1, 3)
            ),
        ];
    }

    /**
     * Indicate that the workflow is active
     *
     * @return static
     */
    public function active(): static
    {
        return $this->state(fn (array $attributes) => [
            'active' => true,
        ]);
    }

    /**
     * Indicate that the workflow is inactive
     *
     * @return static
     */
    public function inactive(): static
    {
        return $this->state(fn (array $attributes) => [
            'active' => false,
        ]);
    }

    /**
     * Indicate that the workflow is for automation
     *
     * @return static
     */
    public function automation(): static
    {
        return $this->state(fn (array $attributes) => [
            'category' => 'automation',
            'tags' => array_merge($attributes['tags'] ?? [], ['automation']),
        ]);
    }

    /**
     * Indicate that the workflow is for monitoring
     *
     * @return static
     */
    public function monitoring(): static
    {
        return $this->state(fn (array $attributes) => [
            'category' => 'monitoring',
            'tags' => array_merge($attributes['tags'] ?? [], ['monitoring', 'alert']),
        ]);
    }

    /**
     * Indicate that the workflow is for deployment
     *
     * @return static
     */
    public function deployment(): static
    {
        return $this->state(fn (array $attributes) => [
            'category' => 'deployment',
            'tags' => array_merge($attributes['tags'] ?? [], ['deployment', 'ci-cd']),
        ]);
    }

    /**
     * Indicate that the workflow has been recently synced
     *
     * @return static
     */
    public function recentlySynced(): static
    {
        return $this->state(fn (array $attributes) => [
            'last_synced_at' => now()->subMinutes($this->faker->numberBetween(5, 60)),
        ]);
    }

    /**
     * Indicate that the workflow has high execution count
     *
     * @return static
     */
    public function frequentlyUsed(): static
    {
        return $this->state(fn (array $attributes) => [
            'execution_count' => $this->faker->numberBetween(500, 5000),
            'last_executed_at' => now()->subMinutes($this->faker->numberBetween(1, 60)),
        ]);
    }
}
