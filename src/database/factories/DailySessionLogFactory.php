<?php

namespace Database\Factories;

use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\DailySessionLog>
 */
class DailySessionLogFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'occurred_on' => fake()->dateTimeBetween('-90 days', 'now')->format('Y-m-d'),
            'title' => fake()->sentence(6),
            'summary' => fake()->paragraphs(4, true),
            'topics' => fake()->randomElements(['Infra', 'LiteLLM', 'OpenClaw', 'Laravel', 'Deploy'], 2),
            'project_tags' => [fake()->word()],
            'source' => 'manual',
        ];
    }
}
