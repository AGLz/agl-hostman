<?php

declare(strict_types=1);

namespace App\DTO;

use JsonSerializable;

/**
 * Proxmox API Response Data Transfer Object
 *
 * Standardized response wrapper for all Proxmox API interactions.
 * Provides consistent error handling and data extraction.
 *
 * @package App\DTO
 */
final readonly class ProxmoxApiResponse implements JsonSerializable
{
    /**
     * @param bool $success Request success status
     * @param mixed $data Response data
     * @param string|null $error Error message if failed
     * @param int $statusCode HTTP status code
     * @param array<string, mixed> $metadata Additional response metadata
     * @param \DateTimeImmutable $timestamp Response timestamp
     */
    public function __construct(
        public bool $success,
        public mixed $data = null,
        public ?string $error = null,
        public int $statusCode = 200,
        public array $metadata = [],
        public \DateTimeImmutable $timestamp = new \DateTimeImmutable(),
    ) {
    }

    /**
     * Create success response
     *
     * @param mixed $data
     * @param array<string, mixed> $metadata
     * @return self
     */
    public static function success(mixed $data, array $metadata = []): self
    {
        return new self(
            success: true,
            data: $data,
            statusCode: 200,
            metadata: $metadata,
        );
    }

    /**
     * Create error response
     *
     * @param string $error
     * @param int $statusCode
     * @param array<string, mixed> $metadata
     * @return self
     */
    public static function error(string $error, int $statusCode = 500, array $metadata = []): self
    {
        return new self(
            success: false,
            error: $error,
            statusCode: $statusCode,
            metadata: $metadata,
        );
    }

    /**
     * Create from HTTP response
     *
     * @param \Illuminate\Http\Client\Response $response
     * @return self
     */
    public static function fromHttpResponse(\Illuminate\Http\Client\Response $response): self
    {
        $data = $response->json();

        if ($response->successful()) {
            return self::success(
                data: $data['data'] ?? $data,
                metadata: [
                    'raw_response' => $data,
                    'headers' => $response->headers(),
                ]
            );
        }

        return self::error(
            error: $data['message'] ?? $response->body(),
            statusCode: $response->status(),
            metadata: [
                'raw_response' => $data,
                'headers' => $response->headers(),
            ]
        );
    }

    /**
     * Check if response has data
     */
    public function hasData(): bool
    {
        return $this->data !== null;
    }

    /**
     * Get data or throw exception
     *
     * @throws \RuntimeException
     */
    public function getDataOrFail(): mixed
    {
        if (!$this->success) {
            throw new \RuntimeException($this->error ?? 'Request failed');
        }

        if (!$this->hasData()) {
            throw new \RuntimeException('No data in response');
        }

        return $this->data;
    }

    /**
     * Get data with default
     *
     * @param mixed $default
     * @return mixed
     */
    public function getDataOrDefault(mixed $default = null): mixed
    {
        return $this->hasData() ? $this->data : $default;
    }

    /**
     * Check if response indicates client error (4xx)
     */
    public function isClientError(): bool
    {
        return $this->statusCode >= 400 && $this->statusCode < 500;
    }

    /**
     * Check if response indicates server error (5xx)
     */
    public function isServerError(): bool
    {
        return $this->statusCode >= 500;
    }

    /**
     * Check if response is successful
     */
    public function isSuccess(): bool
    {
        return $this->success && $this->statusCode >= 200 && $this->statusCode < 300;
    }

    /**
     * Get metadata value
     *
     * @param string $key
     * @param mixed $default
     * @return mixed
     */
    public function getMetadata(string $key, mixed $default = null): mixed
    {
        return $this->metadata[$key] ?? $default;
    }

    /**
     * Convert to array
     *
     * @return array<string, mixed>
     */
    public function toArray(): array
    {
        return [
            'success' => $this->success,
            'data' => $this->data,
            'error' => $this->error,
            'status_code' => $this->statusCode,
            'metadata' => $this->metadata,
            'timestamp' => $this->timestamp->format(\DateTimeInterface::ATOM),
        ];
    }

    /**
     * Convert to JSON array (excludes metadata for cleaner output)
     *
     * @return array<string, mixed>
     */
    public function jsonSerialize(): array
    {
        $result = [
            'success' => $this->success,
            'data' => $this->data,
            'timestamp' => $this->timestamp->format(\DateTimeInterface::ATOM),
        ];

        if (!$this->success) {
            $result['error'] = $this->error;
            $result['status_code'] = $this->statusCode;
        }

        return $result;
    }
}
