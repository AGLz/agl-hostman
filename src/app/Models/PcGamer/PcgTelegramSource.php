<?php

namespace App\Models\PcGamer;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class PcgTelegramSource extends Model
{
    protected $table = 'pcg_telegram_sources';

    protected $fillable = [
        'chat_key',
        'title',
        'enabled',
        'last_synced_message_id',
    ];

    protected function casts(): array
    {
        return [
            'enabled' => 'boolean',
        ];
    }

    /** @return HasMany<PcgTelegramOffer, $this> */
    public function offers(): HasMany
    {
        return $this->hasMany(PcgTelegramOffer::class, 'source_id');
    }
}
