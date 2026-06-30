<?php

declare(strict_types=1);

namespace App\Services\PcGamer\Telegram;

use App\DTO\PcGamer\SyncChannelResult;
use App\Services\PcGamer\TelegramOfferIngestService;
use Illuminate\Support\Facades\Log;
use Throwable;

class TmeSyncService
{
    public function __construct(
        private readonly TmeFeedScraper $scraper,
        private readonly OfferParser $parser,
        private readonly TelegramOfferIngestService $ingest,
    ) {}

    /**
     * @param  list<string>|null  $chatKeys
     * @return list<SyncChannelResult>
     */
    public function syncAll(?array $chatKeys = null, ?int $limit = null): array
    {
        /** @var list<string> $keys */
        $keys = $chatKeys ?? config('pcgamer.telegram.monitor_chats', []);
        $limit = $limit ?? (int) config('pcgamer.telegram.tme_sync_limit', 20);

        $results = [];
        foreach ($keys as $chatKey) {
            $results[] = $this->syncChannel($chatKey, $limit);
        }

        return $results;
    }

    public function syncChannel(string $chatKey, int $limit = 20): SyncChannelResult
    {
        $imported = 0;
        $skipped = 0;
        $errors = 0;

        try {
            $posts = $this->scraper->fetchChannelPosts($chatKey, $limit);
        } catch (Throwable $e) {
            Log::warning('TmeSyncService: falha no canal', ['chat' => $chatKey, 'error' => $e->getMessage()]);

            return new SyncChannelResult($chatKey, 0, 0, 1);
        }

        foreach ($posts as $post) {
            try {
                $parsed = $this->parser->parse($post->text);
                $hash = $this->parser->messageHash($post->text, $post->chatKey, $post->messageId);
                $result = $this->ingest->ingest(
                    chatKey: $post->chatKey,
                    messageId: $post->messageId,
                    messageHash: $hash,
                    rawText: $post->text,
                    parsed: $parsed,
                );
                if ($result['created']) {
                    $imported++;
                } else {
                    $skipped++;
                }
            } catch (Throwable $e) {
                Log::warning('TmeSyncService: erro ao ingerir post', [
                    'chat' => $chatKey,
                    'message_id' => $post->messageId,
                    'error' => $e->getMessage(),
                ]);
                $errors++;
            }
        }

        return new SyncChannelResult($chatKey, $imported, $skipped, $errors);
    }
}
