<?php

namespace Database\Factories;

use App\Models\Environment;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Environment>
 */
class EnvironmentFactory extends Factory
{
    protected $model = Environment::class;

    public function definition(): array
    {
        return [
            'name' => fake()->words(2, true),
            'type' => 'qa',
            'harbor_project' => 'agl-hostman-test',
            'git_branch' => 'develop',
            'auto_deploy' => false,
            'auto_test' => false,
            'status' => 'active',
            'domains' => [],
            'env_vars' => [],
            'resources' => [],
        ];
    }
}
