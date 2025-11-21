<?php

declare(strict_types=1);

use App\Services\CacheService;
use Illuminate\Support\Facades\Cache;

describe('CacheService', function () {
    beforeEach(function () {
        Cache::flush();
        $this->service = new CacheService();
    });

    afterEach(function () {
        Cache::flush();
    });

    it('stores and retrieves values correctly', function () {
        // Act
        $this->service->put('test-key', 'test-value', 'short');
        $value = $this->service->get('test-key');

        // Assert
        expect($value)->toBe('test-value');
    });

    it('prevents cache stampede with distributed lock', function () {
        // Arrange: Simulate concurrent requests
        $hitCount = 0;
        $callback = function () use (&$hitCount) {
            $hitCount++;
            usleep(100000); // 100ms simulated database query
            return 'expensive-result';
        };

        // Act: Execute 10 concurrent requests
        $promises = [];
        for ($i = 0; $i < 10; $i++) {
            $promises[] = async(fn () => $this->service->remember('stampede-test', $callback, 'medium'));
        }

        $results = await($promises);

        // Assert: Callback should only execute once due to lock
        expect($hitCount)->toBe(1)
            ->and($results)->each->toBe('expensive-result');
    });

    it('supports different TTL strategies', function () {
        // Act
        $this->service->put('short-key', 'value', 'short'); // 5 min
        $this->service->put('medium-key', 'value', 'medium'); // 1 hour
        $this->service->put('long-key', 'value', 'long'); // 6 hours
        $this->service->put('day-key', 'value', 'day'); // 24 hours

        // Assert: All should exist immediately
        expect($this->service->get('short-key'))->toBe('value')
            ->and($this->service->get('medium-key'))->toBe('value')
            ->and($this->service->get('long-key'))->toBe('value')
            ->and($this->service->get('day-key'))->toBe('value');
    });

    it('invalidates cache by tags', function () {
        // Arrange
        $this->service->put('user:1:profile', 'profile-data', 'medium', ['user:1']);
        $this->service->put('user:1:settings', 'settings-data', 'medium', ['user:1']);
        $this->service->put('user:2:profile', 'profile2-data', 'medium', ['user:2']);

        // Act: Flush user:1 tag
        $this->service->flushTags(['user:1']);

        // Assert: Only user:1 cache should be cleared
        expect($this->service->get('user:1:profile'))->toBeNull()
            ->and($this->service->get('user:1:settings'))->toBeNull()
            ->and($this->service->get('user:2:profile'))->toBe('profile2-data');
    });

    it('handles null values correctly', function () {
        // Act
        $this->service->put('null-key', null, 'short');

        // Assert: Should distinguish between null and missing
        expect($this->service->has('null-key'))->toBeTrue()
            ->and($this->service->get('null-key'))->toBeNull()
            ->and($this->service->get('missing-key'))->toBeNull()
            ->and($this->service->has('missing-key'))->toBeFalse();
    });

    it('tracks cache hit rate', function () {
        // Arrange
        $this->service->put('key1', 'value1', 'short');

        // Act: Mix hits and misses
        $this->service->get('key1'); // hit
        $this->service->get('key1'); // hit
        $this->service->get('key2'); // miss
        $this->service->get('key3'); // miss

        $stats = $this->service->getStats();

        // Assert
        expect($stats['hits'])->toBe(2)
            ->and($stats['misses'])->toBe(2)
            ->and($stats['hit_rate'])->toBe(0.5);
    });
});
