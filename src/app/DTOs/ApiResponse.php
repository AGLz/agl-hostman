<?php

namespace App\DTOs;

/**
 * ApiResponse - Generic Data Transfer Object for API responses
 *
 * Provides type-safe API response handling for any external API
 * Can be used with Proxmox, Dokploy, Harbor, etc.
 */
class ApiResponse
{
    /**
     * Create API response DTO
     *
     * @param  bool  $success  Whether request was successful
     * @param  array  $data  Response data
     * @param  string|null  $error  Error message if failed
     * @param  int  $statusCode  HTTP status code
     */
    public function __construct(
        public readonly bool $success,
        public readonly array $data,
        public readonly ?string $error = null,
        public readonly int $statusCode = 200
    ) {}

    /**
     * Check if response was successful
     */
    public function isSuccess(): bool
    {
        return $this->success;
    }

    /**
     * Check if response failed
     */
    public function isFailed(): bool
    {
        return ! $this->success;
    }

    /**
     * Get response data
     */
    public function getData(): array
    {
        return $this->data;
    }

    /**
     * Get first data item
     */
    public function getFirstData(): ?array
    {
        return $this->data[0] ?? null;
    }

    /**
     * Get error message
     */
    public function getError(): ?string
    {
        return $this->error;
    }

    /**
     * Get HTTP status code
     */
    public function getStatusCode(): int
    {
        return $this->statusCode;
    }

    /**
     * Convert to array
     */
    public function toArray(): array
    {
        return [
            'success' => $this->success,
            'data' => $this->data,
            'error' => $this->error,
            'status_code' => $this->statusCode,
        ];
    }

    /**
     * Convert to JSON
     */
    public function toJson(): string
    {
        return json_encode($this->toArray(), JSON_PRETTY_PRINT);
    }

    /**
     * Throw exception if failed
     *
     * @throws \Exception
     */
    public function throwIfFailed(): self
    {
        if ($this->isFailed()) {
            throw new \Exception($this->error ?? 'API request failed', $this->statusCode);
        }

        return $this;
    }
}
