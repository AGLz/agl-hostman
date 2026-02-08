<?php

namespace App\Services\AgentOS\Contracts;

use Illuminate\Support\Collection;

interface ConsensusInterface
{
    /**
     * Achieve consensus among agents
     */
    public function achieveConsensus(Collection $agents, Collection $proposals, string $mechanism = 'byzantine'): array;

    /**
     * Byzantine fault tolerance consensus
     */
    public function byzantineConsensus(Collection $agents, Collection $proposals): array;

    /**
     * Raft-based leader election and log replication
     */
    public function raftConsensus(Collection $agents, Collection $proposals): array;

    /**
     * Gossip protocol for information dissemination
     */
    public function gossipConsensus(Collection $agents, mixed $message): array;

    /**
     * CRDT synchronization for eventual consistency
     */
    public function crdtSync(Collection $agents, array $state): array;

    /**
     * Validate votes/proposals
     */
    public function validate(Collection $votes): bool;

    /**
     * Get consensus status
     */
    public function status(string $consensusId): array;
}
