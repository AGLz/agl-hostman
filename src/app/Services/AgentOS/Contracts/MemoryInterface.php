<?php

namespace App\Services\AgentOS\Contracts;

use Illuminate\Support\Collection;

interface MemoryInterface
{
    /**
     * Store an embedding in the HNSW index
     */
    public function store(string $key, array $embedding, array $metadata = []): bool;

    /**
     * Search for similar embeddings using HNSW
     */
    public function search(array $query, int $k = 10): Collection;

    /**
     * Search by text query (with automatic embedding)
     */
    public function searchByText(string $query, int $k = 10): Collection;

    /**
     * Retrieve stored value
     */
    public function get(string $key): ?array;

    /**
     * Delete from index
     */
    public function delete(string $key): bool;

    /**
     * Get index statistics
     */
    public function stats(): array;

    /**
     * Clear index
     */
    public function clear(): bool;

    /**
     * Optimize index
     */
    public function optimize(): bool;
}
