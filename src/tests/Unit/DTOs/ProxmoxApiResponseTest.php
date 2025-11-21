<?php

declare(strict_types=1);

use App\DTO\ProxmoxApiResponse;

describe('ProxmoxApiResponse DTO', function () {
    it('creates DTO from valid response data', function () {
        $data = [
            'success' => true,
            'data' => ['vmid' => 100, 'status' => 'running'],
            'timestamp' => time(),
        ];

        $dto = ProxmoxApiResponse::fromArray($data);

        expect($dto->success)->toBeTrue()
            ->and($dto->data)->toBeArray()
            ->and($dto->data['vmid'])->toBe(100)
            ->and($dto->timestamp)->toBeInt();
    });

    it('handles error responses', function () {
        $data = [
            'success' => false,
            'errors' => 'Server error',
            'data' => null,
        ];

        $dto = ProxmoxApiResponse::fromArray($data);

        expect($dto->success)->toBeFalse()
            ->and($dto->hasErrors())->toBeTrue()
            ->and($dto->getErrors())->toBe('Server error');
    });

    it('converts to array correctly', function () {
        $dto = new ProxmoxApiResponse(
            success: true,
            data: ['test' => 'value'],
            timestamp: 1234567890
        );

        $array = $dto->toArray();

        expect($array)
            ->toHaveKey('success', true)
            ->toHaveKey('data')
            ->toHaveKey('timestamp', 1234567890);
    });

    it('converts to JSON correctly', function () {
        $dto = new ProxmoxApiResponse(
            success: true,
            data: ['vmid' => 100]
        );

        $json = $dto->toJson();

        expect($json)->toBeString()
            ->json()
            ->toHaveKey('success', true)
            ->toHaveKey('data.vmid', 100);
    });

    it('validates required fields on creation', function () {
        expect(fn () => new ProxmoxApiResponse(success: null, data: []))
            ->toThrow(\TypeError::class);
    });

    it('handles nested data structures', function () {
        $complexData = [
            'success' => true,
            'data' => [
                'containers' => [
                    ['vmid' => 100, 'status' => 'running'],
                    ['vmid' => 101, 'status' => 'stopped'],
                ],
                'metadata' => [
                    'total' => 2,
                    'node' => 'pve-node1',
                ],
            ],
        ];

        $dto = ProxmoxApiResponse::fromArray($complexData);

        expect($dto->data['containers'])->toHaveCount(2)
            ->and($dto->data['metadata']['total'])->toBe(2);
    });
});
