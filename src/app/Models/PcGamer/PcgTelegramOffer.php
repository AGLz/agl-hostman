<?php

namespace App\Models\PcGamer;

use App\Enums\PcGamer\OfferStatus;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PcgTelegramOffer extends Model
{
    protected $table = 'pcg_telegram_offers';

    protected $fillable = [
        'source_id',
        'message_id',
        'message_hash',
        'posted_at',
        'raw_text',
        'parsed_json',
        'product_name',
        'price_cents',
        'currency',
        'url',
        'matched_category_slug',
        'matched_component_id',
        'status',
        'last_validated_at',
        'validated_price_cents',
        'validation_notes',
    ];

    protected function casts(): array
    {
        return [
            'posted_at' => 'datetime',
            'parsed_json' => 'array',
            'last_validated_at' => 'datetime',
            'status' => OfferStatus::class,
        ];
    }

    /** @return BelongsTo<PcgTelegramSource, $this> */
    public function source(): BelongsTo
    {
        return $this->belongsTo(PcgTelegramSource::class, 'source_id');
    }

    /**
     * Ofertas que precisam de revalidação periódica.
     *
     * @param  Builder<PcgTelegramOffer>  $query
     * @return Builder<PcgTelegramOffer>
     */
    public function scopeNeedsValidation(Builder $query, int $maxAgeHours, int $revalidateMinutes): Builder
    {
        return $query
            ->whereNotNull('url')
            ->where('url', '!=', '')
            ->whereNotIn('status', [OfferStatus::Unavailable, OfferStatus::Expired])
            ->where('created_at', '>=', now()->subHours($maxAgeHours))
            ->where(function (Builder $q) use ($revalidateMinutes) {
                $q->whereNull('last_validated_at')
                    ->orWhere('last_validated_at', '<=', now()->subMinutes($revalidateMinutes));
            });
    }
}
