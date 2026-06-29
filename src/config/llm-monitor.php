<?php

declare(strict_types=1);

return [
    'governor_state_path' => env(
        'LLM_MONITOR_GOVERNOR_STATE_PATH',
        config('harness.governor_state_path'),
    ),
    'governor_state_fallback' => env(
        'LLM_MONITOR_GOVERNOR_STATE_FALLBACK',
        config('harness.governor_state_fallback'),
    ),
    'litellm_gateway_url' => config('harness.litellm_gateway_url'),
    'litellm_master_key' => env('LITELLM_MASTER_KEY'),
    'default_probe_model' => env('LLM_MONITOR_PROBE_MODEL', 'glm-4.7-flash'),
    'spend_warn_usd' => (float) env('LLM_MONITOR_SPEND_WARN_USD', 80),
    'ingest_cache_ttl' => (int) env('LLM_MONITOR_INGEST_CACHE_TTL', 60),
    'tier_b_delegate_webhook' => env('LLM_MONITOR_TIER_B_DELEGATE_WEBHOOK'),

    /**
     * Mapeamento provider → modelo canónico (alinhado com scripts/agl/llm-monitor.sh).
     *
     * @var array<string, string>
     */
    'provider_models' => [
        'anthropic' => 'claude-haiku',
        'claude' => 'claude-haiku',
        'openai' => 'gpt-5.4-mini',
        'gpt' => 'gpt-5.4-mini',
        'codex' => 'gpt-5.4-mini',
        'zai' => 'zai-glm-5',
        'glm' => 'zai-glm-5',
        'groq' => 'groq-llama-31-8b',
        'free' => 'glm-4.7-flash',
        'flash' => 'glm-4.7-flash',
        'ollama' => 'agl-primary-vm110',
        'local-free' => 'agl-primary-vm110',
        'ollama-primary' => 'agl-primary',
        'primary' => 'agl-primary',
        'local' => 'agl-primary',
        'moonshot' => 'moonshot-v1-8k',
        'kimi' => 'moonshot-v1-8k',
        'gemini' => 'gemini-2.5-flash',
        'openrouter' => 'glm-4.7-flash',
        'or' => 'glm-4.7-flash',
        'cursor' => 'cursor-composer',
        'verdent' => 'verdent-default',
    ],
];
