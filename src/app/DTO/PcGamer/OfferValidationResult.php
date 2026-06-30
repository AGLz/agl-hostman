<?php

declare(strict_types=1);

namespace App\DTO\PcGamer;

final readonly class OfferValidationResult
{
    public function __construct(
        public string $status,
        public ?int $validatedPriceCents,
        public string $notes,
        public ?string $finalUrl = null,
        public ?int $httpStatus = null,
    ) {}
}
