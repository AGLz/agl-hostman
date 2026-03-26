<?php

declare(strict_types=1);

namespace App\DTOs\Dokploy;

/**
 * Dokploy Domain Data Transfer Object
 *
 * Represents domain/routing configuration for applications
 */
readonly class DomainDTO
{
    public function __construct(
        public ?string $domainId = null,
        public string $host = '',
        public bool $https = false,
        public string $certificateType = 'none', // letsencrypt, none, custom
        public bool $stripPath = false,
        public ?string $applicationId = null,
        public ?string $composeId = null,
        public ?string $previewDeploymentId = null,
        public ?string $path = null,
        public ?int $port = null,
        public ?string $serviceName = null,
        public ?string $customCertResolver = null,
        public ?string $internalPath = null,
        public string $domainType = 'application', // compose, application, preview
    ) {}

    public static function fromArray(array $data): self
    {
        return new self(
            domainId: $data['domainId'] ?? null,
            host: $data['host'] ?? '',
            https: $data['https'] ?? false,
            certificateType: $data['certificateType'] ?? 'none',
            stripPath: $data['stripPath'] ?? false,
            applicationId: $data['applicationId'] ?? null,
            composeId: $data['composeId'] ?? null,
            previewDeploymentId: $data['previewDeploymentId'] ?? null,
            path: $data['path'] ?? null,
            port: $data['port'] ?? null,
            serviceName: $data['serviceName'] ?? null,
            customCertResolver: $data['customCertResolver'] ?? null,
            internalPath: $data['internalPath'] ?? null,
            domainType: $data['domainType'] ?? 'application',
        );
    }

    public function toArray(): array
    {
        return array_filter([
            'domainId' => $this->domainId,
            'host' => $this->host,
            'https' => $this->https,
            'certificateType' => $this->certificateType,
            'stripPath' => $this->stripPath,
            'applicationId' => $this->applicationId,
            'composeId' => $this->composeId,
            'previewDeploymentId' => $this->previewDeploymentId,
            'path' => $this->path,
            'port' => $this->port,
            'serviceName' => $this->serviceName,
            'customCertResolver' => $this->customCertResolver,
            'internalPath' => $this->internalPath,
            'domainType' => $this->domainType,
        ], fn ($value) => $value !== null && $value !== '');
    }

    public static function forCreate(
        string $host,
        bool $https = false,
        string $certificateType = 'none',
        ?string $applicationId = null,
        ?int $port = null
    ): self {
        return new self(
            host: $host,
            https: $https,
            certificateType: $certificateType,
            applicationId: $applicationId,
            port: $port,
            stripPath: false,
        );
    }
}
