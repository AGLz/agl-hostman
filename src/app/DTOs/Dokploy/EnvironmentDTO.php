<?php

declare(strict_types=1);

namespace App\DTOs\Dokploy;

use Illuminate\Support\Collection;

/**
 * Dokploy Environment Variables Data Transfer Object
 *
 * Represents environment variables for applications
 */
readonly class EnvironmentDTO
{
    public function __construct(
        public ?string $applicationId = null,
        public ?string $env = null, // Environment variables as string (KEY=VALUE\nKEY2=VALUE2)
        public ?string $buildArgs = null, // Build arguments as string
        public ?Collection $envArray = null, // Environment variables as array
        public ?Collection $buildArgsArray = null, // Build arguments as array
    ) {}

    public static function fromArray(array $data): self
    {
        return new self(
            applicationId: $data['applicationId'] ?? null,
            env: $data['env'] ?? null,
            buildArgs: $data['buildArgs'] ?? null,
            envArray: isset($data['envArray']) ? collect($data['envArray']) : null,
            buildArgsArray: isset($data['buildArgsArray']) ? collect($data['buildArgsArray']) : null,
        );
    }

    public function toArray(): array
    {
        return array_filter([
            'applicationId' => $this->applicationId,
            'env' => $this->env,
            'buildArgs' => $this->buildArgs,
        ], fn($value) => $value !== null);
    }

    /**
     * Create from key-value pairs
     */
    public static function fromKeyValue(
        string $applicationId,
        array $env = [],
        array $buildArgs = []
    ): self {
        $envString = collect($env)
            ->map(fn($value, $key) => "$key=$value")
            ->implode("\n");

        $buildArgsString = collect($buildArgs)
            ->map(fn($value, $key) => "$key=$value")
            ->implode("\n");

        return new self(
            applicationId: $applicationId,
            env: $envString ?: null,
            buildArgs: $buildArgsString ?: null,
            envArray: collect($env),
            buildArgsArray: collect($buildArgs),
        );
    }

    /**
     * Parse environment string to array
     */
    public function parseEnv(): Collection
    {
        if (!$this->env) {
            return collect();
        }

        return collect(explode("\n", $this->env))
            ->filter()
            ->mapWithKeys(function ($line) {
                $parts = explode('=', $line, 2);
                return count($parts) === 2 ? [$parts[0] => $parts[1]] : [];
            });
    }

    /**
     * Parse build args string to array
     */
    public function parseBuildArgs(): Collection
    {
        if (!$this->buildArgs) {
            return collect();
        }

        return collect(explode("\n", $this->buildArgs))
            ->filter()
            ->mapWithKeys(function ($line) {
                $parts = explode('=', $line, 2);
                return count($parts) === 2 ? [$parts[0] => $parts[1]] : [];
            });
    }
}
