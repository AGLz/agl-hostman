<?php

declare(strict_types=1);

use App\Services\Hermes\HermesAgentCatalog;

it('includes curator and orion in agency catalog', function () {
    expect(HermesAgentCatalog::CATALOG)->toHaveKeys(['jarvis', 'elon', 'satya', 'werner', 'curator', 'orion']);
});

it('returns curator metadata', function () {
    $meta = HermesAgentCatalog::metadata('curator');

    expect($meta['name'])->toBe('Curator')
        ->and($meta['group'])->toBe('Knowledge');
});

it('returns orion metadata', function () {
    $meta = HermesAgentCatalog::metadata('orion');

    expect($meta['name'])->toBe('Orion')
        ->and($meta['group'])->toBe('Media');
});
