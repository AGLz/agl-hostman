<?php

declare(strict_types=1);

use App\Services\PcGamer\Telegram\TmeFeedScraper;

const TME_SAMPLE_HTML = <<<'HTML'
<div class="tgme_widget_message_wrap">
  <div class="tgme_widget_message" data-post="mmpromo/12345">
    <div class="tgme_widget_message_text js-message_text" dir="auto">
      Placa RTX 4060 8GB<br/>
      &#036; R&#036; 1.899,90<br/>
      https://kabum.com.br/produto/123
    </div>
  </div>
</div>
HTML;

it('parse feed html extrai mensagem e decodifica entidades', function () {
  $scraper = new TmeFeedScraper;
  $posts = $scraper->parseFeedHtml('@mmpromo', TME_SAMPLE_HTML, 5);

  expect($posts)->toHaveCount(1)
    ->and($posts[0]->messageId)->toBe(12345)
    ->and($posts[0]->chatKey)->toBe('@mmpromo')
    ->and($posts[0]->text)->toContain('R$ 1.899,90')
    ->and($posts[0]->text)->toContain('kabum.com.br');
});

it('username from chat key aceita @ e URL', function () {
  $scraper = new TmeFeedScraper;
  expect($scraper->usernameFromChatKey('@mmpromo'))->toBe('mmpromo')
    ->and($scraper->usernameFromChatKey('https://t.me/pcdofafapromo'))->toBe('pcdofafapromo');
});
