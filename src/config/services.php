<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

    'workos' => [
        'api_key' => env('WORKOS_API_KEY'),
        'client_id' => env('WORKOS_CLIENT_ID'),
        'redirect_uri' => env('WORKOS_REDIRECT_URI', 'http://localhost:8080/auth/workos/callback'),
        'webhook_secret' => env('WORKOS_WEBHOOK_SECRET'),
        'environment' => env('WORKOS_ENVIRONMENT', 'sandbox'),
    ],

    'n8n' => [
        'api_url' => env('N8N_API_URL', 'http://n8n:5678'),
        'api_key' => env('N8N_API_KEY'),
        'webhook_secret' => env('N8N_WEBHOOK_SECRET'),
        'workflows' => [
            'monitoring' => env('N8N_WORKFLOW_MONITORING'),
            'ai_agent' => env('N8N_WORKFLOW_AI_AGENT'),
            'deployment' => env('N8N_WORKFLOW_DEPLOYMENT'),
        ],
    ],

    'ai' => [
        'claude' => [
            'api_key' => env('CLAUDE_API_KEY'),
            'model' => env('CLAUDE_MODEL', 'claude-3-opus-20240229'),
        ],
        'gemini' => [
            'api_key' => env('GEMINI_API_KEY'),
            'model' => env('GEMINI_MODEL', 'gemini-pro'),
        ],
        'openai' => [
            'api_key' => env('OPENAI_API_KEY'),
            'model' => env('OPENAI_MODEL', 'gpt-4-turbo-preview'),
        ],
        'abacusai' => [
            'api_key' => env('ABACUSAI_API_KEY'),
            'endpoint' => env('ABACUSAI_ENDPOINT'),
        ],
        'ollama' => [
            'endpoint' => env('OLLAMA_ENDPOINT', 'http://ollama:11434'),
            'model' => env('OLLAMA_MODEL', 'llama2'),
        ],
    ],

];
