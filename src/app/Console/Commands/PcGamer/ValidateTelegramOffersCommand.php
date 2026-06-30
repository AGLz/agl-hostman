<?php

declare(strict_types=1);

namespace App\Console\Commands\PcGamer;

use App\Jobs\PcGamer\ValidateTelegramOffersJob;
use App\Services\PcGamer\Telegram\TelegramOfferValidationService;
use Illuminate\Console\Command;

class ValidateTelegramOffersCommand extends Command
{
    protected $signature = 'pcg:validate-offers
                            {--batch= : Máximo de ofertas a validar}
                            {--sync : Executar inline em vez de enfileirar}';

    protected $description = 'Valida links de ofertas Telegram (estoque/preço best-effort)';

    public function handle(TelegramOfferValidationService $validationService): int
    {
        $batch = $this->option('batch');
        $batchInt = is_numeric($batch) ? max(1, (int) $batch) : null;

        if (! $this->option('sync')) {
            ValidateTelegramOffersJob::dispatch($batchInt);
            $this->info('Job ValidateTelegramOffersJob enfileirado (fila pc-gamer).');

            return self::SUCCESS;
        }

        $summary = $validationService->validateBatch($batchInt);

        $this->table(
            ['Métrica', 'Valor'],
            [
                ['validated', (string) $summary['validated']],
                ['skipped', (string) $summary['skipped']],
                ['errors', (string) count($summary['errors'])],
            ],
        );

        foreach ($summary['errors'] as $error) {
            $this->warn($error);
        }

        return self::SUCCESS;
    }
}
