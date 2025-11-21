<?php

declare(strict_types=1);

use App\Services\AIModelService;
use Illuminate\Support\Facades\Http;
use Illuminate\Http\Client\Pool;

describe('AIModelService', function () {
    beforeEach(function () {
        $this->service = new AIModelService();
    });

    it('executes multi-agent queries concurrently', function () {
        // Arrange: Mock HTTP responses
        Http::fake([
            'api.anthropic.com/*' => Http::response(mockAIResponse('claude'), 200),
            'generativelanguage.googleapis.com/*' => Http::response(mockAIResponse('gemini'), 200),
            'api.openai.com/*' => Http::response(mockAIResponse('gpt-4'), 200),
        ]);

        $startTime = microtime(true);

        // Act: Query multiple models
        $responses = $this->service->multiAgentQuery(
            ['claude', 'gemini', 'gpt-4'],
            'Test prompt'
        );

        $elapsedTime = (microtime(true) - $startTime) * 1000;

        // Assert: Should complete in parallel (< 2 seconds for 3 requests)
        expect($responses)->toHaveCount(3)
            ->and($responses['claude'])->toHaveKey('content')
            ->and($responses['gemini'])->toHaveKey('content')
            ->and($responses['gpt-4'])->toHaveKey('content')
            ->and($elapsedTime)->toBeLessThan(2000); // Should be concurrent

        // Verify HTTP pool was used (parallel execution)
        Http::assertSentCount(3);
    });

    it('handles individual model failures gracefully', function () {
        // Arrange: Mock one failure
        Http::fake([
            'api.anthropic.com/*' => Http::response(mockAIResponse('claude'), 200),
            'generativelanguage.googleapis.com/*' => Http::response(['error' => 'Rate limit'], 429),
            'api.openai.com/*' => Http::response(mockAIResponse('gpt-4'), 200),
        ]);

        // Act
        $responses = $this->service->multiAgentQuery(
            ['claude', 'gemini', 'gpt-4'],
            'Test prompt'
        );

        // Assert: Should have 2 successful responses
        expect($responses)->toHaveKey('claude')
            ->and($responses)->toHaveKey('gpt-4')
            ->and($responses)->not->toHaveKey('gemini');
    });

    it('respects timeout configuration', function () {
        // Arrange: Mock slow response
        Http::fake([
            'api.anthropic.com/*' => Http::response(fn () => sleep(5), 200),
        ]);

        // Act & Assert: Should timeout
        expect(fn () => $this->service->query('claude', 'Test', ['timeout' => 1]))
            ->toThrow(\Illuminate\Http\Client\ConnectionException::class);
    });

    it('caches identical queries', function () {
        // Arrange
        Http::fake([
            'api.anthropic.com/*' => Http::response(mockAIResponse('claude'), 200),
        ]);

        // Act: Execute same query twice
        $response1 = $this->service->query('claude', 'Test prompt', ['cache' => true]);
        $response2 = $this->service->query('claude', 'Test prompt', ['cache' => true]);

        // Assert: Should only make 1 HTTP request (second is cached)
        Http::assertSentCount(1);
        expect($response1)->toBe($response2);
    });
});
