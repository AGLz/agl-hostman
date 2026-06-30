<?php

declare(strict_types=1);

use App\Services\Hermes\HermesAgentCatalog;

it('includes curator and orion in agency catalog', function () {
    expect(HermesAgentCatalog::CATALOG)->toHaveKeys(['jarvis', 'elon', 'satya', 'werner', 'curator', 'orion']);
});

it('includes argus quota steward in agency catalog', function () {
    expect(HermesAgentCatalog::CATALOG)->toHaveKey('argus');

    $meta = HermesAgentCatalog::metadata('argus');

    expect($meta['name'])->toBe('Argus')
        ->and($meta['group'])->toBe('FinOps');
});

it('returns curator metadata', function () {
    $meta = HermesAgentCatalog::metadata('curator');

    expect($meta['name'])->toBe('Curator')
        ->and($meta['group'])->toBe('Knowledge');
});

it('includes composio integrations operator in agency catalog', function () {
    expect(HermesAgentCatalog::CATALOG)->toHaveKey('composio');

    $meta = HermesAgentCatalog::metadata('composio');

    expect($meta['name'])->toBe('Composio')
        ->and($meta['group'])->toBe('Integrations');
});

it('includes verifier qa gate in agency catalog', function () {
    expect(HermesAgentCatalog::CATALOG)->toHaveKey('verifier');

    $meta = HermesAgentCatalog::metadata('verifier');

    expect($meta['name'])->toBe('Verifier')
        ->and($meta['group'])->toBe('Quality');
});
