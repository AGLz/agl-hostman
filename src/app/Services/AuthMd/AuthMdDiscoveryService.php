<?php

namespace App\Services\AuthMd;

class AuthMdDiscoveryService
{
    public function isEnabled(): bool
    {
        return (bool) config('auth-md.enabled');
    }

    public function resourceMetadata(): array
    {
        return [
            'resource' => config('auth-md.resource_url'),
            'resource_name' => config('auth-md.app_name'),
            'authorization_servers' => [config('auth-md.auth_server_url')],
            'scopes_supported' => array_keys(config('auth-md.scopes', [])),
            'bearer_methods_supported' => ['header'],
        ];
    }

    public function authorizationServerMetadata(): array
    {
        $base = config('auth-md.auth_server_url');
        $flows = config('auth-md.flows', []);
        $identityTypes = [];

        if ($flows['anonymous'] ?? false) {
            $identityTypes[] = 'anonymous';
        }
        if (($flows['id_jag'] ?? false) || ($flows['email_claim'] ?? false)) {
            $identityTypes[] = 'identity_assertion';
        }

        $assertionTypes = [];
        if ($flows['id_jag'] ?? false) {
            $assertionTypes[] = 'urn:ietf:params:oauth:token-type:id-jag';
        }
        if ($flows['email_claim'] ?? false) {
            $assertionTypes[] = 'verified_email';
        }

        return [
            'issuer' => $base,
            'authorization_servers' => [$base],
            'scopes_supported' => array_keys(config('auth-md.scopes', [])),
            'bearer_methods_supported' => ['header'],
            'agent_auth' => [
                'skill' => config('auth-md.skill_url'),
                'register_uri' => $base . '/agent/auth',
                'claim_uri' => $base . '/agent/auth/claim',
                'revocation_uri' => $base . '/agent/auth/revoke',
                'identity_types_supported' => array_values(array_unique($identityTypes)),
                'anonymous' => [
                    'credential_types_supported' => ['api_key'],
                ],
                'identity_assertion' => [
                    'assertion_types_supported' => $assertionTypes,
                    'credential_types_supported' => config('auth-md.credential_types', ['api_key', 'access_token']),
                ],
                'events_supported' => [
                    'https://schemas.workos.com/events/agent/auth/identity/assertion/revoked',
                ],
            ],
        ];
    }

    public function markdownDocument(): string
    {
        $meta = $this->authorizationServerMetadata();
        $agentAuth = $meta['agent_auth'];
        $scopeLines = collect(config('auth-md.scopes', []))
            ->map(fn(string $desc, string $scope) => "- `{$scope}` — {$desc}")
            ->implode("\n");

        $flows = [];
        if (config('auth-md.flows.id_jag')) {
            $flows[] = '- **Agent verified** (`identity_assertion` + ID-JAG)';
        }
        if (config('auth-md.flows.anonymous')) {
            $flows[] = '- **User claimed · anonymous start** — credencial imediata com scopes pré-claim; OTP opcional';
        }
        if (config('auth-md.flows.email_claim')) {
            $flows[] = '- **User claimed · email required** — OTP obrigatório antes da credencial';
        }

        $flowList = implode("\n", $flows);
        $workosClient = config('auth-md.workos.client_id');
        $workosNote = $workosClient
            ? "\n\nIntegração humana (AuthKit): `GET {$meta['issuer']}/auth/workos/redirect` (WorkOS Client ID configurado)."
            : '';

        return <<<MD
# auth.md — {config('auth-md.app_name')}

Registo de agentes conforme [auth.md](https://workos.com/auth-md) (protocolo aberto WorkOS).

## Discovery

- Protected Resource Metadata: `{config('auth-md.auth_server_url')}/.well-known/oauth-protected-resource`
- Authorization Server: `{config('auth-md.auth_server_url')}/.well-known/oauth-authorization-server`
- Registo: `POST {$agentAuth['register_uri']}`
- Claim: `POST {$agentAuth['claim_uri']}` · concluir: `POST {$agentAuth['claim_uri']}/complete`
- Revogação: `POST {$agentAuth['revocation_uri']}`

## Fluxos suportados

{$flowList}

## Scopes

{$scopeLines}

## Contacto

- Integração: {config('auth-md.contact_email')}
{$workosNote}
MD;
    }

    public function wwwAuthenticateHeader(): string
    {
        $prm = config('auth-md.auth_server_url') . '/.well-known/oauth-protected-resource';

        return 'Bearer resource_metadata="' . $prm . '"';
    }
}
