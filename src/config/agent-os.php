<?php

return [
    /*
    |--------------------------------------------------------------------------
    | Agent OS v3 Configuration
    |--------------------------------------------------------------------------
    |
    | Configuration for the Agent OS v3 multi-agent orchestration system
    | with HNSW memory indexing, coordination patterns, and neural integration.
    |
    */

    'memory' => [
        /*
         |--------------------------------------------------------------------------
         | HNSW Vector Indexing
         |--------------------------------------------------------------------------
         */
        'hnsw' => [
            'enabled' => env('AGENT_OS_HNSW_ENABLED', true),
            'dimensions' => env('AGENT_OS_HNSW_DIMENSIONS', 1536),
            'max_elements' => env('AGENT_OS_HNSW_MAX_ELEMENTS', 1000000),
            'ef_construction' => env('AGENT_OS_HNSW_EF_CONSTRUCTION', 200),
            'ef_search' => env('AGENT_OS_HNSW_EF_SEARCH', 50),
            'm' => env('AGENT_OS_HNSW_M', 16),
            'index_path' => env('AGENT_OS_HNSW_INDEX_PATH', storage_path('agent_os/hnsw')),
        ],

        /*
         |--------------------------------------------------------------------------
         | Vector Quantization
         |--------------------------------------------------------------------------
         */
        'quantization' => [
            'enabled' => env('AGENT_OS_QUANTIZATION_ENABLED', true),
            'compression_ratio' => env('AGENT_OS_COMPRESSION_RATIO', 0.5), // 50% reduction
            'product_quantization' => env('AGENT_OS_PQ_ENABLED', true),
            'codebook_size' => env('AGENT_OS_CODEBOOK_SIZE', 256),
        ],

        /*
         |--------------------------------------------------------------------------
         | ReasoningBank
         |--------------------------------------------------------------------------
         */
        'reasoning_bank' => [
            'enabled' => env('AGENT_OS_REASONING_BANK_ENABLED', true),
            'storage_path' => env('AGENT_OS_REASONING_PATH', storage_path('agent_os/reasoning')),
            'min_reward' => env('AGENT_OS_MIN_REWARD', 0.7),
            'max_patterns' => env('AGENT_OS_MAX_PATTERNS', 10000),
            'learning_rate' => env('AGENT_OS_LEARNING_RATE', 0.01),
        ],
    ],

    'coordination' => [
        /*
         |--------------------------------------------------------------------------
         | Topology Configuration
         |--------------------------------------------------------------------------
         */
        'default_topology' => env('AGENT_OS_DEFAULT_TOPOLOGY', 'adaptive'),
        'topologies' => [
            'hierarchical' => [
                'queen_count' => env('AGENT_OS_QUEEN_COUNT', 3),
                'worker_count' => env('AGENT_OS_WORKER_COUNT', 10),
                'curvature' => env('AGENT_OS_HYPERBOLIC_CURVATURE', -1.0),
            ],
            'mesh' => [
                'max_agents' => env('AGENT_OS_MESH_MAX_AGENTS', 50),
                'connection_threshold' => env('AGENT_OS_MESH_THRESHOLD', 0.8),
            ],
            'adaptive' => [
                'selection_threshold' => env('AGENT_OS_ADAPTIVE_THRESHOLD', 0.75),
                'switch_cooldown' => env('AGENT_OS_ADAPTIVE_COOLDOWN', 5), // seconds
            ],
        ],

        /*
         |--------------------------------------------------------------------------
         | Attention Mechanisms
         |--------------------------------------------------------------------------
         */
        'attention' => [
            'default_mechanism' => env('AGENT_OS_ATTENTION_DEFAULT', 'flash'),
            'available' => ['flash', 'multi_head', 'linear', 'hyperbolic', 'moe'],
            'flash' => [
                'speedup' => 2.49,
                'memory_reduction' => 0.5,
            ],
            'multi_head' => [
                'num_heads' => env('AGENT_OS_MH_HEADS', 8),
            ],
            'moe' => [
                'num_experts' => env('AGENT_OS_MOE_EXPERTS', 4),
                'top_k' => env('AGENT_OS_MOE_TOP_K', 2),
            ],
        ],
    ],

    'consensus' => [
        /*
         |--------------------------------------------------------------------------
         | Consensus Mechanisms
         |--------------------------------------------------------------------------
         */
        'default_mechanism' => env('AGENT_OS_CONSENSUS_DEFAULT', 'byzantine'),
        'byzantine' => [
            'fault_tolerance' => env('AGENT_OS_BYZANTINE_FT', 3), // f = 3
            'required_votes' => env('AGENT_OS_BYZANTINE_VOTES', 7), // 2f + 1
            'timeout' => env('AGENT_OS_BYZANTINE_TIMEOUT', 30), // seconds
        ],
        'raft' => [
            'election_timeout' => env('AGENT_OS_RAFT_ELECTION_TIMEOUT', 5000), // ms
            'heartbeat_interval' => env('AGENT_OS_RAFT_HEARTBEAT', 1000), // ms
            'log_replication' => env('AGENT_OS_RAFT_LOG_REPLICATION', true),
        ],
        'gossip' => [
            'fanout' => env('AGENT_OS_GOSSIP_FANOUT', 3),
            'rounds' => env('AGENT_OS_GOSSIP_ROUNDS', 5),
            'interval' => env('AGENT_OS_GOSSIP_INTERVAL', 100), // ms
        ],
        'crdt' => [
            'conflict_resolution' => env('AGENT_OS_CRDT_RESOLUTION', 'last_write_wins'),
            'sync_interval' => env('AGENT_OS_CRDT_SYNC', 1000), // ms
        ],
    ],

    'neural' => [
        /*
         |--------------------------------------------------------------------------
         | SONA (Self-Optimizing Neural Architecture)
         |--------------------------------------------------------------------------
         */
        'sona' => [
            'enabled' => env('AGENT_OS_SONA_ENABLED', true),
            'model_path' => env('AGENT_OS_SONA_MODEL_PATH', storage_path('agent_os/models')),
            'latency_target' => env('AGENT_OS_SONA_LATENCY', 1), // < 1ms
            'continual_learning' => env('AGENT_OS_CONTINUOUS_LEARNING', true),
        ],

        /*
         |--------------------------------------------------------------------------
         | LoRA Fine-tuning
         |--------------------------------------------------------------------------
         */
        'lora' => [
            'enabled' => env('AGENT_OS_LORA_ENABLED', true),
            'rank' => env('AGENT_OS_LORA_RANK', 2), // Rank-2 for micro-LoRA
            'alpha' => env('AGENT_OS_LORA_ALPHA', 32),
            'dropout' => env('AGENT_OS_LORA_DROPOUT', 0.05),
            'target_modules' => ['q_proj', 'v_proj', 'k_proj', 'o_proj'],
        ],

        /*
         |--------------------------------------------------------------------------
         | Elastic Weight Consolidation (EWC++)
         |--------------------------------------------------------------------------
         */
        'ewc' => [
            'enabled' => env('AGENT_OS_EWC_ENABLED', true),
            'lambda' => env('AGENT_OS_EWC_LAMBDA', 5000),
            'fisher_samples' => env('AGENT_OS_EWC_FISHER_SAMPLES', 100),
        ],

        /*
         |--------------------------------------------------------------------------
         | GNN Integration
         |--------------------------------------------------------------------------
         */
        'gnn' => [
            'enabled' => env('AGENT_OS_GNN_ENABLED', true),
            'layers' => env('AGENT_OS_GNN_LAYERS', 3),
            'hidden_dim' => env('AGENT_OS_GNN_HIDDEN', 256),
            'recall_improvement' => 0.124, // +12.4%
        ],
    ],

    'performance' => [
        /*
         |--------------------------------------------------------------------------
         | Performance Optimization
         |--------------------------------------------------------------------------
         */
        'cache_enabled' => env('AGENT_OS_CACHE_ENABLED', true),
        'cache_ttl' => env('AGENT_OS_CACHE_TTL', 3600), // 1 hour
        'parallel_execution' => env('AGENT_OS_PARALLEL', true),
        'max_parallel_agents' => env('AGENT_OS_MAX_PARALLEL', 10),
        'batch_size' => env('AGENT_OS_BATCH_SIZE', 32),
    ],

    'monitoring' => [
        /*
         |--------------------------------------------------------------------------
         | Metrics and Monitoring
         |--------------------------------------------------------------------------
         */
        'enabled' => env('AGENT_OS_MONITORING_ENABLED', true),
        'metrics_path' => env('AGENT_OS_METRICS_PATH', storage_path('agent_os/metrics')),
        'log_performance' => env('AGENT_OS_LOG_PERFORMANCE', true),
        'track_tokens' => env('AGENT_OS_TRACK_TOKENS', true),
    ],

    'security' => [
        /*
         |--------------------------------------------------------------------------
         | Security Settings
         |--------------------------------------------------------------------------
         */
        'encryption_enabled' => env('AGENT_OS_ENCRYPTION', true),
        'signature_required' => env('AGENT_OS_SIGNATURES', true),
        'malicious_detection' => env('AGENT_OS_MALICIOUS_DETECTION', true),
        'quorum_required' => env('AGENT_OS_QUORUM', true),
    ],

    'api' => [
        /*
         |--------------------------------------------------------------------------
         | API Configuration
         |--------------------------------------------------------------------------
         */
        'prefix' => env('AGENT_OS_API_PREFIX', 'api/agent-os'),
        'middleware' => ['auth:sanctum', 'throttle:60,1'],
        'pagination' => [
            'default_per_page' => 20,
            'max_per_page' => 100,
        ],
    ],

];
