<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\AIModelUsage;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * AI Model Usage Factory
 *
 * Factory for generating AIModelUsage test data
 */
class AIModelUsageFactory extends Factory
{
    protected $model = AIModelUsage::class;

    /**
     * Define the model's default state.
     */
    public function definition(): array
    {
        $providers = AIModelUsage::getProviders();
        $taskTypes = AIModelUsage::getTaskTypes();

        $models = [
            'openai' => ['gpt-4-turbo', 'gpt-4', 'gpt-3.5-turbo'],
            'claude' => ['claude-3-opus-20240229', 'claude-3-sonnet-20240229', 'claude-3-haiku-20240307'],
            'ollama' => ['llama2', 'mistral', 'codellama', 'neural-chat'],
        ];

        $provider = fake()->randomElement($providers);
        $model = fake()->randomElement($models[$provider] ?? ['gpt-4-turbo']);
        $taskType = fake()->randomElement($taskTypes);

        $promptTokens = fake()->numberBetween(100, 4000);
        $completionTokens = fake()->numberBetween(50, 2000);
        $totalTokens = $promptTokens + $completionTokens;

        // Calculate estimated cost
        $pricing = config("ai.pricing.{$model}", [
            'input' => 0.01,
            'output' => 0.03,
        ]);
        $estimatedCost = (($promptTokens / 1000) * $pricing['input']) +
                         (($completionTokens / 1000) * $pricing['output']);

        return [
            'user_id' => User::factory(),
            'provider' => $provider,
            'model' => $model,
            'task_type' => $taskType,
            'status' => fake()->randomElement(['success', 'error']),
            'prompt_tokens' => $promptTokens,
            'completion_tokens' => $completionTokens,
            'total_tokens' => $totalTokens,
            'estimated_cost' => $estimatedCost,
            'response_time_ms' => fake()->numberBetween(500, 10000),
            'error_message' => null,
            'metadata' => [
                'request_id' => fake()->uuid(),
                'temperature' => fake()->randomFloat(1, 0, 1),
                'max_tokens' => fake()->numberBetween(1000, 4000),
            ],
            'created_at' => fake()->dateTimeBetween('-30 days', 'now'),
        ];
    }

    /**
     * Indicate that the request was successful
     */
    public function successful(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'success',
            'error_message' => null,
        ]);
    }

    /**
     * Indicate that the request failed
     */
    public function failed(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'error',
            'error_message' => fake()->randomElement([
                'API rate limit exceeded',
                'Invalid API key',
                'Connection timeout',
                'Model not available',
            ]),
        ]);
    }

    /**
     * Specify the provider
     */
    public function forProvider(string $provider): static
    {
        return $this->state(fn (array $attributes) => [
            'provider' => $provider,
            'model' => fake()->randomElement(match($provider) {
                'openai' => ['gpt-4-turbo', 'gpt-4', 'gpt-3.5-turbo'],
                'claude' => ['claude-3-opus-20240229', 'claude-3-sonnet-20240229'],
                'ollama' => ['llama2', 'mistral'],
                default => ['gpt-4-turbo'],
            }),
        ]);
    }

    /**
     * Specify the task type
     */
    public function forTask(string $taskType): static
    {
        return $this->state(fn (array $attributes) => [
            'task_type' => $taskType,
        ]);
    }

    /**
     * Create a recent record
     */
    public function recent(): static
    {
        return $this->state(fn (array $attributes) => [
            'created_at' => fake()->dateTimeBetween('-7 days', 'now'),
        ]);
    }
}
