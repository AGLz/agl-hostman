<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\N8NWorkflowExecution;
use App\Models\N8NWorkflow;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * N8N Workflow Execution Factory
 *
 * @package Database\Factories
 */
class N8NWorkflowExecutionFactory extends Factory
{
    /**
     * The name of the factory's corresponding model.
     *
     * @var string
     */
    protected $model = N8NWorkflowExecution::class;

    /**
     * Define the model's default state.
     *
     * @return array
     */
    public function definition(): array
    {
        $status = $this->faker->randomElement(['pending', 'running', 'success', 'failed', 'cancelled']);
        $startedAt = $this->faker->dateTimeBetween('-30 days', 'now');
        $duration = $this->faker->numberBetween(100, 30000); // 100ms to 30 seconds

        return [
            'workflow_id' => N8NWorkflow::factory(),
            'n8n_execution_id' => $this->faker->uuid(),
            'status' => $status,
            'input_data' => [
                'trigger' => $this->faker->word(),
                'data' => $this->faker->sentences(3, true),
            ],
            'output_data' => $status === 'success' ? [
                'result' => $this->faker->randomElement(['completed', 'processed', 'executed']),
                'data' => $this->faker->sentence(),
            ] : null,
            'error_message' => $status === 'failed' ? $this->faker->sentence() : null,
            'duration_ms' => $status === 'running' || $status === 'pending' ? null : $duration,
            'started_at' => $startedAt,
            'completed_at' => $status === 'running' || $status === 'pending'
                ? null
                : (clone $startedAt)->modify("+{$duration} milliseconds"),
            'triggered_by' => $this->faker->randomElement(['api', 'webhook', 'schedule', 'manual']),
            'metadata' => [
                'retry_count' => $this->faker->numberBetween(0, 3),
                'source_ip' => $this->faker->optional()->ipv4(),
            ],
        ];
    }

    /**
     * Indicate that the execution is successful
     *
     * @return static
     */
    public function successful(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'success',
            'error_message' => null,
            'output_data' => [
                'result' => 'completed',
                'data' => $this->faker->sentence(),
            ],
        ]);
    }

    /**
     * Indicate that the execution failed
     *
     * @return static
     */
    public function failed(): static
    {
        return $this->faker->randomElement(['timeout', 'error', 'validation']);
    }

    /**
     * Indicate that the execution is running
     *
     * @return static
     */
    public function running(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'running',
            'completed_at' => null,
            'duration_ms' => null,
            'output_data' => null,
            'error_message' => null,
        ]);
    }

    /**
     * Indicate that the execution is pending
     *
     * @return static
     */
    public function pending(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'pending',
            'completed_at' => null,
            'duration_ms' => null,
            'output_data' => null,
            'error_message' => null,
        ]);
    }

    /**
     * Indicate that the execution was triggered by API
     *
     * @return static
     */
    public function triggeredByApi(): static
    {
        return $this->state(fn (array $attributes) => [
            'triggered_by' => 'api',
            'metadata' => array_merge($attributes['metadata'] ?? [], [
                'source_ip' => $this->faker->ipv4(),
                'user_agent' => $this->faker->userAgent(),
            ]),
        ]);
    }

    /**
     * Indicate that the execution was triggered by webhook
     *
     * @return static
     */
    public function triggeredByWebhook(): static
    {
        return $this->state(fn (array $attributes) => [
            'triggered_by' => 'webhook',
            'metadata' => array_merge($attributes['metadata'] ?? [], [
                'webhook_source' => $this->faker->url(),
            ]),
        ]);
    }

    /**
     * Indicate that the execution was triggered manually
     *
     * @return static
     */
    public function triggeredManually(): static
    {
        return $this->state(fn (array $attributes) => [
            'triggered_by' => 'manual',
            'metadata' => array_merge($attributes['metadata'] ?? [], [
                'user_id' => $this->faker->randomNumber(),
            ]),
        ]);
    }

    /**
     * Indicate that the execution was triggered by schedule
     *
     * @return static
     */
    public function triggeredBySchedule(): static
    {
        return $this->state(fn (array $attributes) => [
            'triggered_by' => 'schedule',
            'metadata' => array_merge($attributes['metadata'] ?? [], [
                'schedule' => $this->faker->randomElement(['hourly', 'daily', 'weekly']),
            ]),
        ]);
    }

    /**
     * Indicate that the execution has a long duration
     *
     * @return static
     */
    public function slow(): static
    {
        return $this->state(fn (array $attributes) => [
            'duration_ms' => $this->faker->numberBetween(30000, 300000), // 30s to 5min
        ]);
    }

    /**
     * Indicate that the execution has a short duration (fast)
     *
     * @return static
     */
    public function fast(): static
    {
        return $this->state(fn (array $attributes) => [
            'duration_ms' => $this->faker->numberBetween(50, 500), // 50ms to 500ms
        ]);
    }

    /**
     * Indicate that the execution was recently started
     *
     * @return static
     */
    public function recent(): static
    {
        return $this->state(fn (array $attributes) => [
            'started_at' => $this->faker->dateTimeBetween('-1 hour', 'now'),
        ]);
    }
}
