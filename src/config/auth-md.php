<?php

$appUrl = rtrim((string) env('APP_URL', 'http://localhost'), '/');
$authServerUrl = rtrim((string) env('AUTH_MD_AUTH_SERVER_URL', $appUrl), '/');
$resourceUrl = rtrim((string) env('AUTH_MD_RESOURCE_URL', $appUrl . '/api'), '/') . '/';

$workosConfigured = filled(env('WORKOS_API_KEY')) && filled(env('WORKOS_CLIENT_ID'));

return [

    /*
    |--------------------------------------------------------------------------
    | auth.md — registo de agentes (WorkOS / protocolo aberto)
    |--------------------------------------------------------------------------
    | https://workos.com/auth-md
    */

    'enabled' => (bool) env('AUTH_MD_ENABLED', $workosConfigured),

    'app_name' => env('APP_NAME', 'agl-hostman'),

    'contact_email' => env('AUTH_MD_CONTACT_EMAIL', 'authmd@workos.com'),

    'resource_url' => $resourceUrl,

    'auth_server_url' => $authServerUrl,

    'skill_url' => env('AUTH_MD_SKILL_URL', 'https://workos.com/auth-md'),

    'scopes' => [
        'api.read' => 'Leitura de recursos da API (infra, métricas, memória).',
        'api.write' => 'Escrita e acções destrutivas na API.',
    ],

    'pre_claim_scopes' => array_values(array_filter(array_map(
        'trim',
        explode(',', (string) env('AUTH_MD_PRE_CLAIM_SCOPES', 'api.read'))
    ))),

    'post_claim_scopes' => array_values(array_filter(array_map(
        'trim',
        explode(',', (string) env('AUTH_MD_POST_CLAIM_SCOPES', 'api.read,api.write'))
    ))),

    'registration_ttl_hours' => (int) env('AUTH_MD_REGISTRATION_TTL_HOURS', 168),

    'otp_ttl_minutes' => (int) env('AUTH_MD_OTP_TTL_MINUTES', 15),

    'access_token_ttl_hours' => (int) env('AUTH_MD_ACCESS_TOKEN_TTL_HOURS', 24),

    'flows' => [
        'anonymous' => (bool) env('AUTH_MD_FLOW_ANONYMOUS', true),
        'email_claim' => (bool) env('AUTH_MD_FLOW_EMAIL_CLAIM', true),
        'id_jag' => (bool) env('AUTH_MD_FLOW_ID_JAG', true),
    ],

    'credential_types' => [
        'api_key',
        'access_token',
    ],

    /*
    | Provedores de identidade confiáveis (ID-JAG). JSON em AUTH_MD_TRUSTED_ISSUERS
    | ou lista por defeito orientada a WorkOS / Cursor quando WORKOS_* está definido.
    */
    'trusted_issuers' => (function () use ($workosConfigured): array {
        $raw = env('AUTH_MD_TRUSTED_ISSUERS');
        if (is_string($raw) && $raw !== '') {
            $decoded = json_decode($raw, true);

            return is_array($decoded) ? $decoded : [];
        }
        if (! $workosConfigured) {
            return [];
        }

        return [
            ['issuer' => 'https://api.workos.com', 'jwks_uri' => 'https://api.workos.com/sso/jwks'],
            ['issuer' => 'https://api.workos.com/', 'jwks_uri' => 'https://api.workos.com/sso/jwks'],
        ];
    })(),

    'workos' => [
        'client_id' => env('WORKOS_CLIENT_ID'),
        'redirect_uri' => env('WORKOS_REDIRECT_URI'),
    ],

    'rate_limits' => [
        'register' => (int) env('AUTH_MD_RATE_REGISTER', 30),
        'claim' => (int) env('AUTH_MD_RATE_CLAIM', 20),
    ],

];
