<?php

declare(strict_types=1);

use Illuminate\Foundation\Testing\RefreshDatabase;

/*
|--------------------------------------------------------------------------
| Test Case
|--------------------------------------------------------------------------
|
| The closure you provide to your test functions is always bound to a specific PHPUnit test
| case class. By default, that class is "PHPUnit\Framework\TestCase". Of course, you may
| need to change it using the "uses()" function to bind a different classes or traits.
|
*/

uses(Tests\TestCase::class)->in('Feature', 'Integration', 'Performance', 'Unit');
uses(Tests\TestCase::class, RefreshDatabase::class)->in('Feature/Database');

/*
|--------------------------------------------------------------------------
| Expectations
|--------------------------------------------------------------------------
|
| When you're writing tests, you often need to check that values meet certain conditions. The
| "expect()" function gives you access to a set of "expectations" methods that you can use
| to assert different things. Of course, you may extend the Expectation API at any time.
|
*/

expect()->extend('toBeOne', function () {
    return $this->toBe(1);
});

/*
|--------------------------------------------------------------------------
| Functions
|--------------------------------------------------------------------------
|
| While Pest is very powerful out-of-the-box, you may have some testing code specific to your
| project that you don't want to repeat in every file. Here you can also expose helpers as
| global functions to help you to reduce the number of lines of code in your test files.
|
*/

/**
 * Create a mock Proxmox API response
 */
function mockProxmoxResponse(array $data = [], int $status = 200): array
{
    return [
        'data' => $data,
        'status' => $status,
    ];
}

/**
 * Create a mock AI model response
 */
function mockAIResponse(string $model = 'claude', string $content = 'test response'): array
{
    return [
        'model' => $model,
        'content' => $content,
        'tokens' => strlen($content),
        'latency_ms' => rand(100, 500),
    ];
}

/**
 * Assert response time is within threshold
 */
function assertPerformance(float $actualMs, float $thresholdMs = 200): void
{
    expect($actualMs)
        ->toBeLessThan($thresholdMs)
        ->and($actualMs)
        ->toBeGreaterThan(0);
}

/**
 * Assert memory usage is within limit
 */
function assertMemoryUsage(int $actualMb, int $limitMb = 128): void
{
    expect($actualMb)
        ->toBeLessThan($limitMb)
        ->and($actualMb)
        ->toBeGreaterThan(0);
}
