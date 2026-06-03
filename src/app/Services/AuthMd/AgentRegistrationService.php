<?php

namespace App\Services\AuthMd;

use App\Models\AgentRegistration;
use App\Models\ApiKey;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;

class AgentRegistrationService
{
    public function __construct(
        protected IdJagVerifier $idJagVerifier
    ) {}

    /**
     * @param  array<string, mixed>  $payload
     * @return array<string, mixed>
     */
    public function register(array $payload): array
    {
        $type = (string) ($payload['type'] ?? '');

        return match ($type) {
            'anonymous' => $this->registerAnonymous($payload),
            'identity_assertion' => $this->registerIdentityAssertion($payload),
            default => throw new AuthMdException('unsupported_credential_type', "Tipo de registo não suportado: {$type}"),
        };
    }

    /**
     * @param  array<string, mixed>  $payload
     * @return array<string, mixed>
     */
    protected function registerAnonymous(array $payload): array
    {
        if (! config('auth-md.flows.anonymous')) {
            throw new AuthMdException('unsupported_credential_type', 'Fluxo anonymous desactivado.');
        }

        $credentialType = (string) ($payload['requested_credential_type'] ?? 'api_key');
        if ($credentialType !== 'api_key') {
            throw new AuthMdException('unsupported_credential_type', 'Anonymous start suporta apenas api_key.');
        }

        $preScopes = config('auth-md.pre_claim_scopes', ['api.read']);
        $postScopes = config('auth-md.post_claim_scopes', ['api.read', 'api.write']);
        $claimToken = $this->generatePrefixedToken('clm_');
        $expiresAt = now()->addHours((int) config('auth-md.registration_ttl_hours', 168));

        return DB::transaction(function () use ($preScopes, $postScopes, $claimToken, $expiresAt): array {
            $user = $this->createAgentPlaceholderUser();
            $plainKey = 'sk_test_' . Str::random(40);
            $apiKey = ApiKey::query()->create([
                'name' => 'Agent (anonymous) ' . now()->format('Y-m-d H:i'),
                'key' => $plainKey,
                'user_id' => $user->id,
                'permissions' => $this->scopesToPermissions($preScopes),
                'metadata' => ['source' => 'auth-md', 'registration_type' => AgentRegistration::TYPE_ANONYMOUS],
            ]);

            $registration = AgentRegistration::query()->create([
                'registration_id' => $this->generatePrefixedToken('reg_'),
                'registration_type' => AgentRegistration::TYPE_ANONYMOUS,
                'status' => AgentRegistration::STATUS_PENDING_CLAIM,
                'user_id' => $user->id,
                'api_key_id' => $apiKey->id,
                'credential_type' => 'api_key',
                'scopes' => $preScopes,
                'post_claim_scopes' => $postScopes,
                'claim_token_hash' => hash('sha256', $claimToken),
                'expires_at' => $expiresAt,
            ]);

            return [
                'registration_id' => $registration->registration_id,
                'registration_type' => $registration->registration_type,
                'credential_type' => 'api_key',
                'credential' => $plainKey,
                'credential_expires' => null,
                'scopes' => $preScopes,
                'claim_url' => '/agent/auth/claim',
                'claim_token' => $claimToken,
                'claim_token_expires' => $expiresAt->toIso8601String(),
                'post_claim_scopes' => $postScopes,
            ];
        });
    }

    /**
     * @param  array<string, mixed>  $payload
     * @return array<string, mixed>
     */
    protected function registerIdentityAssertion(array $payload): array
    {
        $assertionType = (string) ($payload['assertion_type'] ?? '');
        $assertion = (string) ($payload['assertion'] ?? '');
        $requestedCredential = (string) ($payload['requested_credential_type'] ?? 'access_token');

        if ($assertionType === 'verified_email') {
            return $this->registerEmailRequired($assertion, $requestedCredential);
        }

        if ($assertionType === 'urn:ietf:params:oauth:token-type:id-jag') {
            return $this->registerIdJag($assertion, $requestedCredential);
        }

        throw new AuthMdException('unsupported_credential_type', "assertion_type não suportado: {$assertionType}");
    }

    /**
     * @return array<string, mixed>
     */
    protected function registerIdJag(string $assertion, string $requestedCredential): array
    {
        if (! config('auth-md.flows.id_jag')) {
            throw new AuthMdException('unsupported_credential_type', 'Fluxo ID-JAG desactivado.');
        }

        if (! in_array($requestedCredential, config('auth-md.credential_types', []), true)) {
            throw new AuthMdException('unsupported_credential_type', 'Tipo de credencial não suportado.');
        }

        $verified = $this->idJagVerifier->verify($assertion);
        $claims = $verified['claims'];
        $user = $this->resolveUserFromAssertion($claims);
        $scopes = config('auth-md.post_claim_scopes', ['api.read', 'api.write']);
        $expiresAt = now()->addHours((int) config('auth-md.registration_ttl_hours', 168));

        return DB::transaction(function () use ($user, $claims, $verified, $requestedCredential, $scopes, $expiresAt): array {
            $existing = AgentRegistration::query()
                ->where('provider_iss', $verified['issuer'])
                ->where('provider_sub', (string) ($claims['sub'] ?? ''))
                ->where('status', AgentRegistration::STATUS_CLAIMED)
                ->whereNull('revoked_at')
                ->latest('id')
                ->first();

            if ($existing !== null && $existing->isActive()) {
                return $this->credentialResponseFromRegistration($existing, $scopes);
            }

            $registration = AgentRegistration::query()->create([
                'registration_id' => $this->generatePrefixedToken('reg_'),
                'registration_type' => AgentRegistration::TYPE_AGENT_PROVIDER,
                'status' => AgentRegistration::STATUS_CLAIMED,
                'user_id' => $user->id,
                'credential_type' => $requestedCredential,
                'scopes' => $scopes,
                'provider_iss' => $verified['issuer'],
                'provider_sub' => (string) ($claims['sub'] ?? ''),
                'provider_jti' => (string) ($claims['jti'] ?? ''),
                'claimed_at' => now(),
                'expires_at' => $expiresAt,
            ]);

            $this->attachCredential($registration, $user, $requestedCredential, $scopes);

            return $this->credentialResponseFromRegistration($registration->fresh(), $scopes);
        });
    }

    /**
     * @return array<string, mixed>
     */
    protected function registerEmailRequired(string $email, string $requestedCredential): array
    {
        if (! config('auth-md.flows.email_claim')) {
            throw new AuthMdException('unsupported_credential_type', 'Fluxo email claim desactivado.');
        }

        if (! filter_var($email, FILTER_VALIDATE_EMAIL)) {
            throw new AuthMdException('missing_verified_email', 'Email inválido.');
        }

        if ($requestedCredential !== 'api_key') {
            throw new AuthMdException('unsupported_credential_type', 'Email required suporta api_key nesta implementação.');
        }

        $claimToken = $this->generatePrefixedToken('clm_');
        $viewToken = $this->generatePrefixedToken('clv_');
        $otp = (string) random_int(100000, 999999);
        $expiresAt = now()->addHours((int) config('auth-md.registration_ttl_hours', 168));
        $postScopes = config('auth-md.post_claim_scopes', ['api.read', 'api.write']);

        $registration = AgentRegistration::query()->create([
            'registration_id' => $this->generatePrefixedToken('reg_'),
            'registration_type' => AgentRegistration::TYPE_EMAIL_VERIFICATION,
            'status' => AgentRegistration::STATUS_PENDING_CLAIM,
            'claim_email' => $email,
            'credential_type' => 'api_key',
            'post_claim_scopes' => $postScopes,
            'claim_token_hash' => hash('sha256', $claimToken),
            'claim_view_token_hash' => hash('sha256', $viewToken),
            'otp_hash' => hash('sha256', $otp),
            'otp_expires_at' => now()->addMinutes((int) config('auth-md.otp_ttl_minutes', 15)),
            'expires_at' => $expiresAt,
        ]);

        $this->sendClaimEmail($email, $viewToken, $otp);

        return [
            'registration_id' => $registration->registration_id,
            'registration_type' => $registration->registration_type,
            'claim_token' => $claimToken,
            'claim_token_expires' => $expiresAt->toIso8601String(),
            'post_claim_scopes' => $postScopes,
        ];
    }

    /**
     * @param  array<string, mixed>  $payload
     * @return array<string, mixed>
     */
    public function startClaim(array $payload): array
    {
        $claimToken = (string) ($payload['claim_token'] ?? '');
        $email = (string) ($payload['email'] ?? '');

        $registration = $this->findByClaimToken($claimToken);
        if ($registration->registration_type !== AgentRegistration::TYPE_ANONYMOUS) {
            throw new AuthMdException('invalid_request', 'claim só aplica a registos anonymous.');
        }

        if (! filter_var($email, FILTER_VALIDATE_EMAIL)) {
            throw new AuthMdException('missing_verified_email', 'Email inválido.');
        }

        $otp = (string) random_int(100000, 999999);
        $viewToken = $this->generatePrefixedToken('clv_');

        $registration->update([
            'claim_email' => $email,
            'claim_view_token_hash' => hash('sha256', $viewToken),
            'otp_hash' => hash('sha256', $otp),
            'otp_expires_at' => now()->addMinutes((int) config('auth-md.otp_ttl_minutes', 15)),
        ]);

        $this->sendClaimEmail($email, $viewToken, $otp);

        return ['status' => 'claim_email_sent'];
    }

    /**
     * @param  array<string, mixed>  $payload
     * @return array<string, mixed>
     */
    public function completeClaim(array $payload): array
    {
        $claimToken = (string) ($payload['claim_token'] ?? '');
        $otp = (string) ($payload['otp'] ?? '');

        $registration = $this->findByClaimToken($claimToken);

        if ($registration->otp_hash === null || $registration->otp_expires_at?->isPast()) {
            throw new AuthMdException('expired', 'OTP expirado ou inexistente.');
        }

        if (! hash_equals($registration->otp_hash, hash('sha256', $otp))) {
            throw new AuthMdException('invalid_request', 'OTP inválido.');
        }

        $email = (string) $registration->claim_email;
        $user = User::query()->where('email', $email)->first()
            ?? $this->upgradePlaceholderUser($registration->user, $email, $registration);

        $postScopes = $registration->post_claim_scopes ?? config('auth-md.post_claim_scopes', []);

        return DB::transaction(function () use ($registration, $user, $postScopes): array {
            if ($registration->registration_type === AgentRegistration::TYPE_EMAIL_VERIFICATION) {
                $this->attachCredential($registration, $user, 'api_key', $postScopes);
            } elseif ($registration->api_key_id) {
                $apiKey = ApiKey::query()->find($registration->api_key_id);
                if ($apiKey) {
                    $apiKey->update([
                        'user_id' => $user->id,
                        'permissions' => $this->scopesToPermissions($postScopes),
                        'name' => 'Agent (claimed) ' . $user->email,
                    ]);
                }
            }

            $registration->refresh();
            $registration->update([
                'user_id' => $user->id,
                'status' => AgentRegistration::STATUS_CLAIMED,
                'scopes' => $postScopes,
                'claimed_at' => now(),
                'otp_hash' => null,
            ]);

            $response = ['status' => 'claimed', 'scopes' => $postScopes];

            if ($registration->registration_type === AgentRegistration::TYPE_EMAIL_VERIFICATION) {
                $response['credential_type'] = 'api_key';
                $response['credential'] = $registration->fresh()->metadata['api_key_plain'] ?? null;
                $response['credential_expires'] = null;
            }

            return $response;
        });
    }

    public function revokeLogoutToken(string $rawBody): void
    {
        $claims = $this->idJagVerifier->verifyLogoutToken($rawBody);
        $iss = rtrim((string) ($claims['iss'] ?? ''), '/');
        $sub = (string) ($claims['sub'] ?? '');

        AgentRegistration::query()
            ->where('provider_sub', $sub)
            ->whereNull('revoked_at')
            ->where(function ($query) use ($iss): void {
                $query->where('provider_iss', $iss)
                    ->orWhere('provider_iss', $iss . '/');
            })
            ->each(function (AgentRegistration $registration): void {
                $this->revokeRegistration($registration);
            });
    }

    public function findByClaimViewToken(string $viewToken): AgentRegistration
    {
        $registration = AgentRegistration::query()
            ->where('claim_view_token_hash', hash('sha256', $viewToken))
            ->first();

        if (! $registration || ! $registration->isActive()) {
            throw new AuthMdException('invalid_request', 'Token de visualização inválido ou expirado.');
        }

        return $registration;
    }

    protected function findByClaimToken(string $claimToken): AgentRegistration
    {
        $registration = AgentRegistration::query()
            ->where('claim_token_hash', hash('sha256', $claimToken))
            ->first();

        if (! $registration || ! $registration->isActive()) {
            throw new AuthMdException('invalid_request', 'claim_token inválido ou expirado.');
        }

        return $registration;
    }

    protected function revokeRegistration(AgentRegistration $registration): void
    {
        if ($registration->api_key_id) {
            ApiKey::query()->whereKey($registration->api_key_id)->update(['is_active' => false]);
        }

        if ($registration->personal_access_token_id) {
            DB::table('personal_access_tokens')
                ->where('id', $registration->personal_access_token_id)
                ->delete();
        }

        $registration->update([
            'status' => AgentRegistration::STATUS_REVOKED,
            'revoked_at' => now(),
        ]);
    }

    /**
     * @param  array<string, mixed>  $claims
     */
    protected function resolveUserFromAssertion(array $claims): User
    {
        $iss = rtrim((string) ($claims['iss'] ?? ''), '/');
        $sub = (string) ($claims['sub'] ?? '');
        $email = (string) ($claims['email'] ?? '');

        $delegation = AgentRegistration::query()
            ->where('provider_iss', $iss)
            ->where('provider_sub', $sub)
            ->where('status', AgentRegistration::STATUS_CLAIMED)
            ->whereNotNull('user_id')
            ->latest('id')
            ->first();

        if ($delegation?->user) {
            return $delegation->user;
        }

        if ($email !== '') {
            $user = User::query()->where('email', $email)->first();
            if ($user) {
                return $user;
            }
        }

        $name = (string) ($claims['name'] ?? $email ?: 'Agent User');

        return User::query()->create([
            'name' => $name,
            'email' => $email !== '' ? $email : 'agent+' . Str::uuid() . '@agents.local',
            'email_verified_at' => filter_var($claims['email_verified'] ?? false, FILTER_VALIDATE_BOOLEAN) ? now() : null,
            'password' => Hash::make(Str::password(32)),
            'is_active' => true,
        ]);
    }

    protected function createAgentPlaceholderUser(): User
    {
        return User::query()->create([
            'name' => 'Agent (pending claim)',
            'email' => 'agent+' . Str::uuid() . '@agents.local',
            'password' => Hash::make(Str::password(32)),
            'is_active' => true,
        ]);
    }

    protected function upgradePlaceholderUser(?User $placeholder, string $email, AgentRegistration $registration): User
    {
        if ($placeholder && str_ends_with($placeholder->email, '@agents.local')) {
            $placeholder->update([
                'email' => $email,
                'email_verified_at' => now(),
                'name' => Str::before($email, '@'),
            ]);

            return $placeholder->fresh();
        }

        return User::query()->firstOrCreate(
            ['email' => $email],
            [
                'name' => Str::before($email, '@'),
                'password' => Hash::make(Str::password(32)),
                'email_verified_at' => now(),
                'is_active' => true,
            ]
        );
    }

    /**
     * @param  list<string>  $scopes
     */
    protected function attachCredential(AgentRegistration $registration, User $user, string $type, array $scopes): void
    {
        if ($type === 'access_token') {
            $token = $user->createToken(
                'auth-md-agent',
                $this->scopesToPermissions($scopes),
                now()->addHours((int) config('auth-md.access_token_ttl_hours', 24))
            );
            $registration->update([
                'personal_access_token_id' => $token->accessToken->id,
                'metadata' => array_merge($registration->metadata ?? [], [
                    'access_token_plain' => $token->plainTextToken,
                ]),
            ]);

            return;
        }

        $plainKey = 'sk_live_' . Str::random(40);
        $apiKey = ApiKey::query()->create([
            'name' => 'Agent ID-JAG ' . $user->email,
            'key' => $plainKey,
            'user_id' => $user->id,
            'permissions' => $this->scopesToPermissions($scopes),
            'metadata' => ['source' => 'auth-md', 'registration_id' => $registration->registration_id],
        ]);

        $registration->update([
            'api_key_id' => $apiKey->id,
            'metadata' => array_merge($registration->metadata ?? [], [
                'api_key_plain' => $plainKey,
            ]),
        ]);
    }

    /**
     * @param  list<string>  $scopes
     * @return array<string, mixed>
     */
    protected function credentialResponseFromRegistration(AgentRegistration $registration, array $scopes): array
    {
        $credentialType = $registration->credential_type ?? 'api_key';
        $response = [
            'registration_id' => $registration->registration_id,
            'registration_type' => $registration->registration_type,
            'credential_type' => $credentialType,
            'scopes' => $scopes,
        ];

        $meta = $registration->metadata ?? [];
        if ($credentialType === 'access_token') {
            $response['credential'] = $meta['access_token_plain'] ?? null;
            $response['credential_expires'] = $registration->expires_at?->toIso8601String();
        } elseif ($registration->api_key_id) {
            $response['credential'] = $meta['api_key_plain'] ?? ApiKey::query()->find($registration->api_key_id)?->key;
            $response['credential_expires'] = null;
        }

        return $response;
    }

    /**
     * @param  list<string>  $scopes
     * @return list<string>
     */
    protected function scopesToPermissions(array $scopes): array
    {
        $map = [
            'api.read' => 'view-dashboard',
            'api.write' => 'manage-infrastructure',
        ];

        $permissions = [];
        foreach ($scopes as $scope) {
            if (isset($map[$scope])) {
                $permissions[] = $map[$scope];
            }
        }

        return $permissions !== [] ? array_values(array_unique($permissions)) : ['view-dashboard'];
    }

    protected function generatePrefixedToken(string $prefix): string
    {
        return $prefix . Str::lower(Str::random(25));
    }

    protected function sendClaimEmail(string $email, string $viewToken, string $otp): void
    {
        $url = config('auth-md.auth_server_url') . '/agent/auth/claim/view?token=' . $viewToken;

        try {
            Mail::raw(
                "Código de verificação auth.md: {$otp}\n\nOu abra: {$url}\n",
                fn($message) => $message->to($email)->subject('Código auth.md — ' . config('auth-md.app_name'))
            );
        } catch (\Throwable $e) {
            Log::warning('auth.md: falha ao enviar email de claim', ['email' => $email, 'error' => $e->getMessage()]);
        }
    }
}
