<?php

declare(strict_types=1);

use App\Models\PcGamer\PcgTelegramOffer;
use App\Services\PcGamer\Telegram\TmeSyncService;
use Database\Seeders\PcgCatalogSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;

uses(RefreshDatabase::class);

const TME_SYNC_SAMPLE_HTML = <<<'HTML'
<div class="tgme_widget_message" data-post="mmpromo/12345">
  <div class="tgme_widget_message_text js-message_text" dir="auto">
    Placa RTX 4060 8GB<br/>R$ 1.899,90<br/>https://kabum.com.br/produto/123
  </div>
</div>
HTML;

beforeEach(function () {
    $this->seed(PcgCatalogSeeder::class);
});

it('sync tme importa ofertas novas via HTTP fake', function () {
    Http::fake([
        't.me/s/mmpromo' => Http::response(
            '<html><body>' . TME_SYNC_SAMPLE_HTML . '<span class="tgme_widget_message"></span></body></html>',
            200,
        ),
    ]);

    config(['pcgamer.telegram.monitor_chats' => ['@mmpromo']]);

    $results = app(TmeSyncService::class)->syncAll(['@mmpromo'], 5);

    expect($results)->toHaveCount(1)
        ->and($results[0]->imported)->toBe(1)
        ->and($results[0]->errors)->toBe(0);

    expect(PcgTelegramOffer::query()->count())->toBe(1);
    $offer = PcgTelegramOffer::query()->first();
    expect($offer->message_id)->toBe(12345)
        ->and($offer->matched_category_slug)->toBe('placa_video');
});

it('sync tme ignora duplicados', function () {
    Http::fake([
        't.me/s/mmpromo' => Http::response(
            '<html>' . TME_SYNC_SAMPLE_HTML . 'tgme_widget_message</html>',
            200,
        ),
    ]);

    $service = app(TmeSyncService::class);
    $service->syncAll(['@mmpromo'], 5);
    $second = $service->syncAll(['@mmpromo'], 5);

    expect($second[0]->imported)->toBe(0)
        ->and($second[0]->skipped)->toBe(1)
        ->and(PcgTelegramOffer::query()->count())->toBe(1);
});
