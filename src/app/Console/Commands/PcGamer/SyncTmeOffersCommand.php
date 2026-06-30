<?php

declare(strict_types=1);

namespace App\Console\Commands\PcGamer;

use App\Jobs\PcGamer\SyncTmeOffersJob;
use App\Services\PcGamer\Telegram\TmeSyncService;
use Illuminate\Console\Command;

class SyncTmeOffersCommand extends Command
{
    protected $signature = 'pcg:sync-tme
                            {--chat= : Canal único (@nome ou t.me/...)}
                            {--limit= : Máximo de posts por canal}
                            {--sync : Executar inline em vez de enfileirar}';

    protected $description = 'Sincroniza ofertas dos canais Telegram via feed público t.me/s/';

    public function handle(TmeSyncService $syncService): int
    {
        $limit = $this->option('limit');
        $limitInt = is_numeric($limit) ? max(1, (int) $limit) : null;

        $chat = $this->option('chat');
        $chatKeys = is_string($chat) && trim($chat) !== '' ? [trim($chat)] : null;

        if (! $this->option('sync')) {
            SyncTmeOffersJob::dispatch($chatKeys, $limitInt);
            $this->info('Job SyncTmeOffersJob enfileirado (fila pc-gamer).');

            return self::SUCCESS;
        }

        $results = $syncService->syncAll($chatKeys, $limitInt);

        $rows = [];
        foreach ($results as $result) {
            $rows[] = [$result->chatKey, (string) $result->imported, (string) $result->skipped, (string) $result->errors];
        }

        $this->table(['Canal', 'Importadas', 'Ignoradas', 'Erros'], $rows);

        return self::SUCCESS;
    }
}
