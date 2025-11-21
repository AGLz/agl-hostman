<?php

declare(strict_types=1);

namespace App\DTOs\Dokploy;

use Illuminate\Support\Collection;

/**
 * Dokploy Application Data Transfer Object
 *
 * Represents an application deployment configuration
 */
readonly class ApplicationDTO
{
    public function __construct(
        public ?string $applicationId = null,
        public string $name = '',
        public string $appName = '',
        public ?string $description = null,
        public ?string $environmentId = null,
        public ?string $serverId = null,
        public ?string $dockerImage = null,
        public ?string $sourceType = null, // github, docker, git, gitlab, bitbucket, gitea, drop
        public ?string $buildType = null, // dockerfile, heroku_buildpacks, paketo_buildpacks, nixpacks, static, railpack
        public ?string $applicationStatus = null, // idle, running, done, error
        public ?string $env = null,
        public ?string $buildArgs = null,
        public ?int $cpuLimit = null,
        public ?int $memoryLimit = null,
        public ?int $cpuReservation = null,
        public ?int $memoryReservation = null,
        public ?string $command = null,
        public ?int $replicas = null,
        public bool $autoDeploy = false,
        public ?Collection $domains = null,
        public ?string $createdAt = null,
    ) {}

    public static function fromArray(array $data): self
    {
        return new self(
            applicationId: $data['applicationId'] ?? null,
            name: $data['name'] ?? '',
            appName: $data['appName'] ?? '',
            description: $data['description'] ?? null,
            environmentId: $data['environmentId'] ?? null,
            serverId: $data['serverId'] ?? null,
            dockerImage: $data['dockerImage'] ?? null,
            sourceType: $data['sourceType'] ?? null,
            buildType: $data['buildType'] ?? null,
            applicationStatus: $data['applicationStatus'] ?? null,
            env: $data['env'] ?? null,
            buildArgs: $data['buildArgs'] ?? null,
            cpuLimit: $data['cpuLimit'] ?? null,
            memoryLimit: $data['memoryLimit'] ?? null,
            cpuReservation: $data['cpuReservation'] ?? null,
            memoryReservation: $data['memoryReservation'] ?? null,
            command: $data['command'] ?? null,
            replicas: $data['replicas'] ?? null,
            autoDeploy: $data['autoDeploy'] ?? false,
            domains: isset($data['domains']) ? collect($data['domains']) : null,
            createdAt: $data['createdAt'] ?? null,
        );
    }

    public function toArray(): array
    {
        return array_filter([
            'applicationId' => $this->applicationId,
            'name' => $this->name,
            'appName' => $this->appName,
            'description' => $this->description,
            'environmentId' => $this->environmentId,
            'serverId' => $this->serverId,
            'dockerImage' => $this->dockerImage,
            'sourceType' => $this->sourceType,
            'buildType' => $this->buildType,
            'applicationStatus' => $this->applicationStatus,
            'env' => $this->env,
            'buildArgs' => $this->buildArgs,
            'cpuLimit' => $this->cpuLimit,
            'memoryLimit' => $this->memoryLimit,
            'cpuReservation' => $this->cpuReservation,
            'memoryReservation' => $this->memoryReservation,
            'command' => $this->command,
            'replicas' => $this->replicas,
            'autoDeploy' => $this->autoDeploy,
            'domains' => $this->domains?->toArray(),
            'createdAt' => $this->createdAt,
        ], fn($value) => $value !== null && $value !== '');
    }

    public static function forCreate(
        string $name,
        string $appName,
        string $environmentId,
        ?string $description = null,
        ?string $dockerImage = null,
        ?string $serverId = null
    ): self {
        return new self(
            name: $name,
            appName: $appName,
            environmentId: $environmentId,
            description: $description,
            dockerImage: $dockerImage,
            serverId: $serverId,
        );
    }
}
