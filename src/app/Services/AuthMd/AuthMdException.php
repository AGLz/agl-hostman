<?php

namespace App\Services\AuthMd;

use RuntimeException;

class AuthMdException extends RuntimeException
{
    public function __construct(
        public readonly string $errorCode,
        string $message
    ) {
        parent::__construct($message);
    }
}
