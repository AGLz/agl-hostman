<?php

declare(strict_types=1);

namespace App\Exceptions;

use Exception;
use Throwable;

/**
 * Exception thrown when Archon MCP operations fail
 */
class ArchonMcpException extends Exception
{
    private mixed $data;

    public function __construct(
        string $message = '',
        int $code = 0,
        ?Throwable $previous = null,
        mixed $data = null
    ) {
        parent::__construct($message, $code, $previous);
        $this->data = $data;
    }

    /**
     * Get additional error data from MCP response
     */
    public function getData(): mixed
    {
        return $this->data;
    }

    /**
     * Check if this is a connection error
     */
    public function isConnectionError(): bool
    {
        return $this->code >= 500;
    }

    /**
     * Check if this is a validation error
     */
    public function isValidationError(): bool
    {
        return $this->code === 400;
    }

    /**
     * Get error context for logging
     */
    public function getContext(): array
    {
        return [
            'message' => $this->getMessage(),
            'code' => $this->getCode(),
            'data' => $this->data,
            'file' => $this->getFile(),
            'line' => $this->getLine(),
        ];
    }
}
