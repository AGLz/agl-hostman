<?php

declare(strict_types=1);

use App\Services\N8NService;
use Illuminate\Support\Facades\Http;

describe('N8NService', function () {
    beforeEach(function () {
        $this->service = new N8NService();
    });

    it('sends webhook successfully', function () {
        Http::fake([
            'http://test.n8n.local/webhook/*' => Http::response([
                'success' => true,
                'message' => 'Webhook received',
            ], 200),
        ]);

        $result = $this->service->sendWebhook('test-webhook', [
            'event' => 'container.created',
            'vmid' => 100,
        ]);

        expect($result)->toBeTrue();

        Http::assertSent(function ($request) {
            return str_contains($request->url(), 'webhook')
                && $request->data()['event'] === 'container.created';
        });
    });

    it('handles webhook timeout gracefully', function () {
        Http::fake([
            'http://test.n8n.local/webhook/*' => function () {
                throw new \Illuminate\Http\Client\ConnectionException('Timeout');
            },
        ]);

        $result = $this->service->sendWebhook('test-webhook', ['event' => 'test']);

        expect($result)->toBeFalse();
    });

    it('includes authentication header when API key is set', function () {
        Http::fake();

        config(['services.n8n.api_key' => 'secret-key']);

        $this->service->sendWebhook('test-webhook', ['test' => 'data']);

        Http::assertSent(function ($request) {
            return $request->hasHeader('X-N8N-API-KEY', 'secret-key');
        });
    });

    it('batches multiple webhook calls', function () {
        Http::fake();

        $webhooks = [
            ['webhook' => 'hook1', 'data' => ['event' => 'event1']],
            ['webhook' => 'hook2', 'data' => ['event' => 'event2']],
            ['webhook' => 'hook3', 'data' => ['event' => 'event3']],
        ];

        $this->service->batchSendWebhooks($webhooks);

        Http::assertSentCount(3);
    });

    it('validates webhook data before sending', function () {
        expect(fn () => $this->service->sendWebhook('', []))
            ->toThrow(\InvalidArgumentException::class, 'Webhook name is required');

        expect(fn () => $this->service->sendWebhook('test', null))
            ->toThrow(\InvalidArgumentException::class, 'Webhook data must be an array');
    });
});
