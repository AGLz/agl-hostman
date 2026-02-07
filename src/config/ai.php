<?php

declare(strict_types=1);

/**
 * AI Configuration
 *
 * Configuration for AI model integrations including:
 * - OpenAI (GPT-4, GPT-3.5)
 * - Claude (Anthropic)
 * - Ollama (Local LLMs)
 */

return [

    /*
    |--------------------------------------------------------------------------
    | Default AI Model
    |--------------------------------------------------------------------------
    |
    | The default model to use when no specific model is requested.
    | Options: gpt-4-turbo, claude-3-opus-20240229, llama2, etc.
    |
    */

    'default_model' => env('AI_DEFAULT_MODEL', 'gpt-4-turbo'),

    /*
    |--------------------------------------------------------------------------
    | AI Provider Configurations
    |--------------------------------------------------------------------------
    |
    | Configuration for each AI provider including API keys, endpoints,
    | and model-specific settings.
    |
    */

    'providers' => [

        /*
        |--------------------------------------------------------------------------
        | OpenAI Configuration
        |--------------------------------------------------------------------------
        |
        | API Key: Get from https://platform.openai.com/api-keys
        | Organization: Optional organization ID
        | Base URL: Override the default API base URL if using a proxy
        |
        */

        'openai' => [
            'api_key' => env('OPENAI_API_KEY'),
            'organization' => env('OPENAI_ORGANIZATION'),
            'base_url' => env('OPENAI_BASE_URL', 'https://api.openai.com/v1'),

            // Model defaults
            'model' => env('OPENAI_MODEL', 'gpt-4-turbo'),
            'temperature' => (float) env('OPENAI_TEMPERATURE', 0.7),
            'max_tokens' => (int) env('OPENAI_MAX_TOKENS', 4096),

            // Rate limiting
            'requests_per_minute' => (int) env('OPENAI_RPM', 500),
            'tokens_per_minute' => (int) env('OPENAI_TPM', 150000),
        ],

        /*
        |--------------------------------------------------------------------------
        | Claude (Anthropic) Configuration
        |--------------------------------------------------------------------------
        |
        | API Key: Get from https://console.anthropic.com/
        | Version: API version to use
        |
        */

        'claude' => [
            'api_key' => env('CLAUDE_API_KEY'),
            'version' => env('CLAUDE_API_VERSION', '2023-06-01'),
            'base_url' => env('CLAUDE_BASE_URL', 'https://api.anthropic.com/v1'),

            // Model defaults
            'model' => env('CLAUDE_MODEL', 'claude-3-opus-20240229'),
            'temperature' => (float) env('CLAUDE_TEMPERATURE', 0.7),
            'max_tokens' => (int) env('CLAUDE_MAX_TOKENS', 4096),

            // Rate limiting
            'requests_per_minute' => (int) env('CLAUDE_RPM', 50),
            'tokens_per_minute' => (int) env('CLAUDE_TPM', 100000),
        ],

        /*
        |--------------------------------------------------------------------------
        | Ollama Configuration
        |--------------------------------------------------------------------------
        |
        | Ollama is a local LLM runner. Download from https://ollama.com
        | Default endpoint: http://localhost:11434
        |
        | Available models: llama2, mistral, codellama, neural-chat, etc.
        | Pull models with: ollama pull <model-name>
        |
        */

        'ollama' => [
            'endpoint' => env('OLLAMA_ENDPOINT', 'http://localhost:11434'),
            'model' => env('OLLAMA_MODEL', 'llama2'),
            'temperature' => (float) env('OLLAMA_TEMPERATURE', 0.7),
            'num_predict' => (int) env('OLLAMA_NUM_PREDICT', 2048),
            'timeout' => (int) env('OLLAMA_TIMEOUT', 120),

            // Connection retry settings
            'retry_attempts' => 3,
            'retry_delay' => 1000, // milliseconds
        ],

        /*
        |--------------------------------------------------------------------------
        | Additional Provider Examples
        |--------------------------------------------------------------------------
        |
        | These are placeholders for other AI providers you might want to integrate.
        |
        */

        // 'gemini' => [
        //     'api_key' => env('GEMINI_API_KEY'),
        //     'model' => 'gemini-pro',
        // ],

        // 'cohere' => [
        //     'api_key' => env('COHERE_API_KEY'),
        //     'model' => 'command',
        // ],

    ],

    /*
    |--------------------------------------------------------------------------
    | Model Capabilities
    |--------------------------------------------------------------------------
    |
    | Define which models support which capabilities for intelligent routing.
    |
    */

    'capabilities' => [
        'prediction' => ['claude-3-opus-20240229', 'gpt-4-turbo'],
        'analysis' => ['claude-3-sonnet-20240229', 'gpt-4-turbo'],
        'code_generation' => ['claude-3-opus-20240229', 'gpt-4-turbo', 'codellama'],
        'chat' => ['claude-3-opus-20240229', 'gpt-4-turbo', 'llama2'],
        'streaming' => ['claude-3-opus-20240229', 'claude-3-sonnet-20240229', 'gpt-4-turbo', 'gpt-3.5-turbo'],
    ],

    /*
    |--------------------------------------------------------------------------
    | Usage Tracking
    |--------------------------------------------------------------------------
    |
    | Configure usage tracking for AI models.
    |
    */

    'usage_tracking' => [
        'enabled' => env('AI_USAGE_TRACKING', true),
        'retention_days' => (int) env('AI_USAGE_RETENTION_DAYS', 90),
    ],

    /*
    |--------------------------------------------------------------------------
    | Fallback Configuration
    |--------------------------------------------------------------------------
    |
    | Configure automatic fallback behavior when primary providers fail.
    |
    */

    'fallback' => [
        'enabled' => env('AI_FALLBACK_ENABLED', true),
        'max_attempts' => (int) env('AI_FALLBACK_MAX_ATTEMPTS', 3),
        'retry_delay' => (int) env('AI_FALLBACK_RETRY_DELAY', 1000),
    ],

    /*
    |--------------------------------------------------------------------------
    | Cost Tracking
    |--------------------------------------------------------------------------
    |
    | Pricing per 1K tokens (as of 2024). Update these as pricing changes.
    |
    */

    'pricing' => [
        'gpt-4-turbo' => [
            'input' => 0.01,
            'output' => 0.03,
        ],
        'gpt-4' => [
            'input' => 0.03,
            'output' => 0.06,
        ],
        'gpt-3.5-turbo' => [
            'input' => 0.0005,
            'output' => 0.0015,
        ],
        'claude-3-opus-20240229' => [
            'input' => 0.015,
            'output' => 0.075,
        ],
        'claude-3-sonnet-20240229' => [
            'input' => 0.003,
            'output' => 0.015,
        ],
        'claude-3-haiku-20240307' => [
            'input' => 0.00025,
            'output' => 0.00125,
        ],
        // Ollama is free (local)
    ],

    /*
    |--------------------------------------------------------------------------
    | Caching
    |--------------------------------------------------------------------------
    |
    | Cache AI responses to reduce API calls and costs.
    |
    */

    'cache' => [
        'enabled' => env('AI_CACHE_ENABLED', true),
        'ttl' => (int) env('AI_CACHE_TTL', 3600), // seconds
        'prefix' => 'ai:',
    ],

    /*
    |--------------------------------------------------------------------------
    | Streaming Configuration
    |--------------------------------------------------------------------------
    |
    | Configure streaming response behavior.
    |
    */

    'streaming' => [
        'enabled' => true,
        'chunk_size' => 1024, // bytes
        'timeout' => 30, // seconds
    ],

];
