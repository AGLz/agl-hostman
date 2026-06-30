<?php

declare(strict_types=1);

namespace App\DTO\PcGamer;

final readonly class SyncChannelResult
{
    public function __construct(
        public string $chatKey,
        public int $imported,
        public int $skipped,
        public int $errors = 0,
    ) {}
}
