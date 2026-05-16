<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\SecurityAuditLog;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * Security Audit Log Factory
 */
class SecurityAuditLogFactory extends Factory
{
    /**
     * The name of the factory's corresponding model.
     *
     * @var string
     */
    protected $model = SecurityAuditLog::class;

    /**
     * Define the model's default state.
     */
    public function definition(): array
    {
        return [
            'event_type' => $this->faker->randomElement([
                SecurityAuditLog::EVENT_AUTH_LOGIN,
                SecurityAuditLog::EVENT_AUTH_LOGOUT,
                SecurityAuditLog::EVENT_USER_CREATED,
                SecurityAuditLog::EVENT_CONTAINER_CREATED,
                SecurityAuditLog::EVENT_SECURITY_SCAN,
            ]),
            'severity' => $this->faker->randomElement([
                SecurityAuditLog::SEVERITY_INFO,
                SecurityAuditLog::SEVERITY_LOW,
                SecurityAuditLog::SEVERITY_MEDIUM,
                SecurityAuditLog::SEVERITY_HIGH,
                SecurityAuditLog::SEVERITY_CRITICAL,
            ]),
            'description' => $this->faker->sentence(),
            'user_id' => User::factory(),
            'ip_address' => $this->faker->ipv4(),
            'user_agent' => $this->faker->userAgent(),
            'old_values' => $this->faker->optional()->randomElement([
                ['status' => 'old'],
                ['role' => 'user'],
            ]),
            'new_values' => $this->faker->optional()->randomElement([
                ['status' => 'new'],
                ['role' => 'admin'],
            ]),
            'metadata' => $this->faker->optional()->randomElement([
                ['source' => 'web', 'browser' => 'chrome'],
                ['source' => 'api', 'client' => 'mobile'],
            ]),
            'tags' => $this->faker->randomElements([
                'auth', 'security', 'container', 'user', 'audit', 'scan',
            ], $this->faker->numberBetween(1, 3)),
            'created_at' => $this->faker->dateTimeBetween('-30 days', 'now'),
        ];
    }

    /**
     * Indicate that the log is critical severity
     */
    public function critical(): static
    {
        return $this->state(fn (array $attributes) => [
            'severity' => SecurityAuditLog::SEVERITY_CRITICAL,
        ]);
    }

    /**
     * Indicate that the log is high severity
     */
    public function high(): static
    {
        return $this->state(fn (array $attributes) => [
            'severity' => SecurityAuditLog::SEVERITY_HIGH,
        ]);
    }

    /**
     * Indicate that the log is medium severity
     */
    public function medium(): static
    {
        return $this->state(fn (array $attributes) => [
            'severity' => SecurityAuditLog::SEVERITY_MEDIUM,
        ]);
    }

    /**
     * Indicate that the log is auth event
     */
    public function auth(): static
    {
        return $this->state(fn (array $attributes) => [
            'event_type' => $this->faker->randomElement([
                SecurityAuditLog::EVENT_AUTH_LOGIN,
                SecurityAuditLog::EVENT_AUTH_LOGOUT,
                SecurityAuditLog::EVENT_AUTH_FAILED,
            ]),
        ]);
    }

    /**
     * Indicate that the log is security alert
     */
    public function alert(): static
    {
        return $this->state(fn (array $attributes) => [
            'event_type' => SecurityAuditLog::EVENT_SECURITY_ALERT,
            'severity' => SecurityAuditLog::SEVERITY_HIGH,
            'tags' => ['security-alert', 'auto-generated'],
        ]);
    }

    /**
     * Indicate that the log is for a user
     */
    public function forUser(User $user): static
    {
        return $this->state(fn (array $attributes) => [
            'user_id' => $user->id,
            'auditable_type' => User::class,
            'auditable_id' => $user->id,
        ]);
    }
}
