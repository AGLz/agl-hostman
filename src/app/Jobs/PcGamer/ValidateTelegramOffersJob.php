<?php

declare(strict_types=1);

namespace App\Jobs\PcGamer;

use App\Services\PcGamer\Telegram\TelegramOfferValidationService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class ValidateTelegramOffersJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $timeout = 900;

    public int $tries = 2;

    public function __construct(
        public readonly ?int $batch = null,
    ) {
        $this->onQueue('pc-gamer');
    }

    public function handle(TelegramOfferValidationService $validationService): void
    {
        $validationService->validateBatch($this->batch);
    }

    /** @return list<int> */
    public function backoff(): array
    {
        return [60, 300];
    }
}
