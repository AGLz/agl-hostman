<?php

declare(strict_types=1);

namespace App\DTO\PcGamer;

/** Post extraído do feed público t.me/s/. */
final readonly class TmePost
{
    public function __construct(
        public string $chatKey,
        public int $messageId,
        public string $text,
        public string $postUrl,
    ) {}
}
