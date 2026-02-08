<?php

namespace App\Services\AgentOS\Contracts;

use Illuminate\Support\Collection;

interface CoordinatorInterface
{
    /**
     * Initialize coordination session
     */
    public function initialize(string $sessionId, array $config = []): string;

    /**
     * Coordinate agents based on topology
     */
    public function coordinate(Collection $agents, string $topology = 'adaptive'): array;

    /**
     * Apply attention mechanism to agent outputs
     */
    public function attend(array $outputs, string $mechanism = 'flash'): array;

    /**
     * Get coordination status
     */
    public function status(string $sessionId): array;

    /**
     * End coordination session
     */
    public function terminate(string $sessionId): bool;

    /**
     * Get available topologies
     */
    public function topologies(): array;

    /**
     * Get available attention mechanisms
     */
    public function mechanisms(): array;
}
