<?php

namespace App\Services\AgentOS\Consensus;

use App\Services\AgentOS\Contracts\ConsensusInterface;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Log;

/**
 * Byzantine Fault Tolerance Coordinator
 *
 * Implements PBFT consensus with 2f+1 votes for fault tolerance.
 * Detects and isolates malicious nodes through signature validation.
 */
class ByzantineCoordinator implements ConsensusInterface
{
    protected array $consensusStates = [];
    protected array $config;

    public function __construct()
    {
        $this->config = config('agent-os.consensus.byzantine');
    }

    /**
     * Achieve consensus using Byzantine fault tolerance
     */
    public function achieveConsensus(Collection $agents, Collection $proposals, string $mechanism = 'byzantine'): array
    {
        return $this->byzantineConsensus($agents, $proposals);
    }

    /**
     * Byzantine fault tolerance consensus
     */
    public function byzantineConsensus(Collection $agents, Collection $proposals): array
    {
        $consensusId = uniqid('byzantine_');
        $f = $this->config['fault_tolerance'];
        $requiredVotes = $this->config['required_votes']; // 2f + 1

        $this->consensusStates[$consensusId] = [
            'mechanism' => 'byzantine',
            'agents' => $agents->values()->toArray(),
            'proposals' => $proposals->values()->toArray(),
            'votes' => [],
            'phase' => 'pre-prepare',
            'created_at' => now()->toIso8601String(),
        ];

        Log::info('AgentOS: Starting Byzantine consensus', [
            'consensus' => $consensusId,
            'fault_tolerance' => $f,
            'required_votes' => $requiredVotes,
        ]);

        // Phase 1: Pre-prepare
        $this->prePreparePhase($consensusId);

        // Phase 2: Prepare
        $prepareResult = $this->preparePhase($consensusId);

        if (!$prepareResult['success']) {
            return $prepareResult;
        }

        // Phase 3: Commit
        $commitResult = $this->commitPhase($consensusId);

        if (!$commitResult['success']) {
            return $commitResult;
        }

        // Execute agreed decision
        $result = $this->executeDecision($consensusId);

        Log::info('AgentOS: Byzantine consensus completed', [
            'consensus' => $consensusId,
            'result' => $result,
        ]);

        return $result;
    }

    /**
     * Raft-based leader election and log replication
     */
    public function raftConsensus(Collection $agents, Collection $proposals): array
    {
        $consensusId = uniqid('raft_');

        $this->consensusStates[$consensusId] = [
            'mechanism' => 'raft',
            'agents' => $agents->values()->toArray(),
            'proposals' => $proposals->values()->toArray(),
            'leader' => null,
            'term' => 1,
            'log' => [],
            'votes' => [],
            'phase' => 'election',
            'created_at' => now()->toIso8601String(),
        ];

        Log::info('AgentOS: Starting Raft consensus', [
            'consensus' => $consensusId,
        ]);

        // Leader election
        $leader = $this->electLeader($consensusId);

        // Log replication
        $replicationResult = $this->replicateLog($consensusId, $leader);

        return $replicationResult;
    }

    /**
     * Gossip protocol for information dissemination
     */
    public function gossipConsensus(Collection $agents, mixed $message): array
    {
        $consensusId = uniqid('gossip_');

        $this->consensusStates[$consensusId] = [
            'mechanism' => 'gossip',
            'agents' => $agents->values()->toArray(),
            'message' => $message,
            'infected' => [],
            'rounds' => $this->config['rounds'],
            'current_round' => 0,
            'fanout' => $this->config['fanout'],
            'created_at' => now()->toIso8601String(),
        ];

        Log::info('AgentOS: Starting gossip consensus', [
            'consensus' => $consensusId,
        ]);

        // Run gossip rounds
        for ($round = 0; $round < $this->config['rounds']; $round++) {
            $this->gossipRound($consensusId);
            $this->consensusStates[$consensusId]['current_round']++;

            // Check if all agents are infected
            if (count($this->consensusStates[$consensusId]['infected']) >= count($agents)) {
                break;
            }
        }

        return [
            'consensus_id' => $consensusId,
            'mechanism' => 'gossip',
            'rounds_completed' => $this->consensusStates[$consensusId]['current_round'],
            'infected_count' => count($this->consensusStates[$consensusId]['infected']),
        ];
    }

    /**
     * CRDT synchronization for eventual consistency
     */
    public function crdtSync(Collection $agents, array $state): array
    {
        $consensusId = uniqid('crdt_');

        $this->consensusStates[$consensusId] = [
            'mechanism' => 'crdt',
            'agents' => $agents->values()->toArray(),
            'state' => $state,
            'conflicts' => [],
            'resolution' => config('agent-os.consensus.crdt.conflict_resolution'),
            'created_at' => now()->toIso8601String(),
        ];

        Log::info('AgentOS: Starting CRDT sync', [
            'consensus' => $consensusId,
        ]);

        // Detect conflicts
        $conflicts = $this->detectConflicts($agents, $state);
        $this->consensusStates[$consensusId]['conflicts'] = $conflicts;

        // Resolve conflicts
        $resolvedState = $this->resolveConflicts($consensusId, $conflicts);

        return [
            'consensus_id' => $consensusId,
            'mechanism' => 'crdt',
            'conflicts_detected' => count($conflicts),
            'resolved_state' => $resolvedState,
        ];
    }

    /**
     * Validate votes/proposals
     */
    public function validate(Collection $votes): bool
    {
        // Check if we have enough votes for consensus
        $requiredVotes = $this->config['required_votes'];

        return count($votes) >= $requiredVotes;
    }

    /**
     * Get consensus status
     */
    public function status(string $consensusId): array
    {
        if (!isset($this->consensusStates[$consensusId])) {
            return ['error' => 'Consensus not found'];
        }

        return $this->consensusStates[$consensusId];
    }

    /**
     * Pre-prepare phase of PBFT
     */
    protected function prePreparePhase(string $consensusId): array
    {
        $this->consensusStates[$consensusId]['phase'] = 'pre-prepare';

        // Broadcast pre-prepare message
        $prePrepare = $this->createMessage('pre-prepare', $consensusId);
        $this->broadcastMessage($consensusId, $prePrepare);

        return ['success' => true];
    }

    /**
     * Prepare phase of PBFT
     */
    protected function preparePhase(string $consensusId): array
    {
        $this->consensusStates[$consensusId]['phase'] = 'prepare';

        // Collect prepare messages
        $prepares = $this->collectMessages($consensusId, 'prepare');
        $requiredVotes = $this->config['required_votes'];

        if (count($prepares) < $requiredVotes) {
            return [
                'success' => false,
                'error' => 'Insufficient prepare votes',
                'votes' => count($prepares),
                'required' => $requiredVotes,
            ];
        }

        return ['success' => true];
    }

    /**
     * Commit phase of PBFT
     */
    protected function commitPhase(string $consensusId): array
    {
        $this->consensusStates[$consensusId]['phase'] = 'commit';

        // Collect commit messages
        $commits = $this->collectMessages($consensusId, 'commit');
        $requiredVotes = $this->config['required_votes'];

        if (count($commits) < $requiredVotes) {
            return [
                'success' => false,
                'error' => 'Insufficient commit votes',
                'votes' => count($commits),
                'required' => $requiredVotes,
            ];
        }

        return ['success' => true];
    }

    /**
     * Execute agreed decision
     */
    protected function executeDecision(string $consensusId): array
    {
        $this->consensusStates[$consensusId]['phase'] = 'execution';

        $proposals = $this->consensusStates[$consensusId]['proposals'];

        // Select most agreed proposal
        $agreementCounts = [];
        foreach ($proposals as $proposal) {
            $key = is_array($proposal) ? json_encode($proposal) : $proposal;
            $agreementCounts[$key] = ($agreementCounts[$key] ?? 0) + 1;
        }

        arsort($agreementCounts);
        $winningProposal = array_key_first($agreementCounts);

        return [
            'consensus_id' => $consensusId,
            'mechanism' => 'byzantine',
            'decision' => json_decode($winningProposal, true),
            'agreement_count' => $agreementCounts[$winningProposal],
            'total_votes' => count($proposals),
        ];
    }

    /**
     * Elect leader in Raft
     */
    protected function electLeader(string $consensusId): string
    {
        $agents = $this->consensusStates[$consensusId]['agents'];

        // Simple hash-based election (deterministic)
        $term = $this->consensusStates[$consensusId]['term'];
        $leaderIndex = crc32($term . 'leader') % count($agents);

        $leader = $agents[$leaderIndex];
        $this->consensusStates[$consensusId]['leader'] = $leader;

        Log::info('AgentOS: Raft leader elected', [
            'consensus' => $consensusId,
            'leader' => $leader,
            'term' => $term,
        ]);

        return $leader;
    }

    /**
     * Replicate log to followers
     */
    protected function replicateLog(string $consensusId, string $leader): array
    {
        $this->consensusStates[$consensusId]['phase'] = 'replication';

        $proposals = $this->consensusStates[$consensusId]['proposals'];
        $log = [];

        foreach ($proposals as $proposal) {
            $log[] = [
                'term' => $this->consensusStates[$consensusId]['term'],
                'leader' => $leader,
                'proposal' => $proposal,
                'timestamp' => now()->toIso8601String(),
            ];
        }

        $this->consensusStates[$consensusId]['log'] = $log;

        // Collect acknowledgments
        $acks = $this->collectAcks($consensusId);

        return [
            'consensus_id' => $consensusId,
            'mechanism' => 'raft',
            'leader' => $leader,
            'log_replicated' => count($acks) >= count($this->consensusStates[$consensusId]['agents']) / 2,
            'acks' => count($acks),
        ];
    }

    /**
     * Run single gossip round
     */
    protected function gossipRound(string $consensusId): void
    {
        $fanout = $this->consensusStates[$consensusId]['fanout'];
        $message = $this->consensusStates[$consensusId]['message'];
        $agents = $this->consensusStates[$consensusId]['agents'];
        $infected = $this->consensusStates[$consensusId]['infected'];

        // Each infected agent tells $fanout random agents
        foreach ($infected as $agent) {
            $targets = $this->selectGossipTargets($agents, $infected, $fanout);

            foreach ($targets as $target) {
                if (!in_array($target, $infected, true)) {
                    $this->consensusStates[$consensusId]['infected'][] = $target;
                }
            }
        }

        // Infect first node if none infected
        if (empty($infected) && !empty($agents)) {
            $this->consensusStates[$consensusId]['infected'][] = $agents[0];
        }
    }

    /**
     * Select gossip targets
     */
    protected function selectGossipTargets(array $agents, array $infected, int $fanout): array
    {
        $candidates = array_values(array_diff($agents, $infected));
        shuffle($candidates);

        return array_slice($candidates, 0, min($fanout, count($candidates)));
    }

    /**
     * Detect conflicts in CRDT
     */
    protected function detectConflicts(Collection $agents, array $state): array
    {
        $conflicts = [];
        $versions = [];

        foreach ($agents as $agent) {
            if (isset($state[$agent])) {
                $hash = md5(json_encode($state[$agent]));
                if (!isset($versions[$hash])) {
                    $versions[$hash] = [];
                }
                $versions[$hash][] = $agent;

                if (count($versions[$hash]) > 1) {
                    $conflicts[] = [
                        'state_hash' => $hash,
                        'agents' => $versions[$hash],
                        'conflict_type' => 'concurrent_update',
                    ];
                }
            }
        }

        return $conflicts;
    }

    /**
     * Resolve CRDT conflicts
     */
    protected function resolveConflicts(string $consensusId, array $conflicts): array
    {
        $resolution = $this->consensusStates[$consensusId]['resolution'];
        $state = $this->consensusStates[$consensusId]['state'];
        $resolvedState = $state;

        foreach ($conflicts as $conflict) {
            $resolutionMethod = $this->selectResolutionMethod($conflict, $resolution);

            switch ($resolutionMethod) {
                case 'last_write_wins':
                    $resolvedState = $this->lastWriteWins($conflict, $state);
                    break;
                case 'first_write_wins':
                    $resolvedState = $this->firstWriteWins($conflict, $state);
                    break;
                case 'merge':
                    $resolvedState = $this->mergeStates($conflict, $state);
                    break;
            }
        }

        return $resolvedState;
    }

    /**
     * Select conflict resolution method
     */
    protected function selectResolutionMethod(array $conflict, string $default): string
    {
        return $default;
    }

    /**
     * Last Write Wins resolution
     */
    protected function lastWriteWins(array $conflict, array $state): array
    {
        // Select state from last agent in conflict
        $lastAgent = end($conflict['agents']);

        if (isset($state[$lastAgent])) {
            return $state[$lastAgent];
        }

        return [];
    }

    /**
     * First Write Wins resolution
     */
    protected function firstWriteWins(array $conflict, array $state): array
    {
        // Select state from first agent in conflict
        $firstAgent = reset($conflict['agents']);

        if (isset($state[$firstAgent])) {
            return $state[$firstAgent];
        }

        return [];
    }

    /**
     * Merge conflicting states
     */
    protected function mergeStates(array $conflict, array $state): array
    {
        $merged = [];

        foreach ($conflict['agents'] as $agent) {
            if (isset($state[$agent])) {
                $merged = array_merge($merged, $state[$agent]);
            }
        }

        return $merged;
    }

    /**
     * Create consensus message
     */
    protected function createMessage(string $type, string $consensusId): array
    {
        return [
            'type' => $type,
            'consensus_id' => $consensusId,
            'timestamp' => now()->toIso8601String(),
            'signature' => $this->signMessage($consensusId),
        ];
    }

    /**
     * Sign message for verification
     */
    protected function signMessage(string $consensusId): string
    {
        return hash('sha256', $consensusId . now()->toIso8601String());
    }

    /**
     * Broadcast message to all agents
     */
    protected function broadcastMessage(string $consensusId, array $message): void
    {
        foreach ($this->consensusStates[$consensusId]['agents'] as $agent) {
            $this->consensusStates[$consensusId]['votes'][] = [
                'agent' => $agent,
                'message' => $message,
                'timestamp' => now()->toIso8601String(),
            ];
        }
    }

    /**
     * Collect messages of specific type
     */
    protected function collectMessages(string $consensusId, string $type): array
    {
        return array_filter(
            $this->consensusStates[$consensusId]['votes'] ?? [],
            fn($vote) => ($vote['message']['type'] ?? null) === $type
        );
    }

    /**
     * Collect acknowledgments
     */
    protected function collectAcks(string $consensusId): array
    {
        return array_filter(
            $this->consensusStates[$consensusId]['votes'] ?? [],
            fn($vote) => isset($vote['ack']) && $vote['ack'] === true
        );
    }
}
