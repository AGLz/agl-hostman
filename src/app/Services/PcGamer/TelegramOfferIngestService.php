<?php

declare(strict_types=1);

namespace App\Services\PcGamer;

use App\Enums\PcGamer\OfferStatus;
use App\Models\PcGamer\PcgTelegramOffer;
use App\Models\PcGamer\PcgTelegramSource;

class TelegramOfferIngestService
{
    /**
     * @param  array<string, mixed>  $parsed
     * @return array{created: bool, offer_id: int|null}
     */
    public function ingest(
        string $chatKey,
        int $messageId,
        string $messageHash,
        string $rawText,
        array $parsed,
        ?string $postedAt = null,
        ?string $sourceTitle = null,
    ): array {
        $source = PcgTelegramSource::query()->updateOrCreate(
            ['chat_key' => $chatKey],
            ['title' => $sourceTitle ?? ltrim($chatKey, '@'), 'enabled' => true],
        );

        if (PcgTelegramOffer::query()->where('message_hash', $messageHash)->exists()) {
            return ['created' => false, 'offer_id' => null];
        }

        $offer = PcgTelegramOffer::query()->create([
            'source_id' => $source->id,
            'message_id' => $messageId,
            'message_hash' => $messageHash,
            'posted_at' => $postedAt,
            'raw_text' => $rawText,
            'parsed_json' => $parsed,
            'product_name' => $parsed['product_name'] ?? null,
            'price_cents' => $parsed['price_cents'] ?? null,
            'currency' => $parsed['currency'] ?? 'BRL',
            'url' => $parsed['url'] ?? null,
            'matched_category_slug' => $parsed['matched_category_slug'] ?? null,
            'status' => OfferStatus::New,
        ]);

        if ($messageId > (int) ($source->last_synced_message_id ?? 0)) {
            $source->update(['last_synced_message_id' => $messageId]);
        }

        return ['created' => true, 'offer_id' => $offer->id];
    }
}
