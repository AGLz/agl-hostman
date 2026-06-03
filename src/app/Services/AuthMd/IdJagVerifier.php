<?php

namespace App\Services\AuthMd;

use Firebase\JWT\JWK;
use Firebase\JWT\JWT;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use stdClass;
use Throwable;

class IdJagVerifier
{
    /**
     * @return array{claims: array<string, mixed>, issuer: string}
     */
    public function verify(string $assertion): array
    {
        $trusted = collect(config('auth-md.trusted_issuers', []));
        if ($trusted->isEmpty()) {
            throw new AuthMdException('invalid_issuer', 'Nenhum emissor ID-JAG confiável configurado (AUTH_MD_TRUSTED_ISSUERS).');
        }

        try {
            $headers = new stdClass;
            $payload = JWT::decode($assertion, JWK::parseKeySet($this->jwksForAssertion($assertion, $trusted)), $headers);
        } catch (Throwable $e) {
            throw new AuthMdException('invalid_signature', 'Assinatura ID-JAG inválida: ' . $e->getMessage());
        }

        $claims = (array) json_decode(json_encode($payload), true);
        $issuer = rtrim((string) ($claims['iss'] ?? ''), '/');
        $audience = config('auth-md.auth_server_url');

        if (! $this->issuerIsTrusted($issuer, $trusted)) {
            throw new AuthMdException('invalid_issuer', "Emissor não confiável: {$issuer}");
        }

        $aud = $claims['aud'] ?? null;
        $audMatches = is_array($aud)
            ? in_array($audience, $aud, true) || in_array(rtrim($audience, '/') . '/', $aud, true)
            : rtrim((string) $aud, '/') === rtrim($audience, '/');

        if (! $audMatches) {
            throw new AuthMdException('invalid_audience', 'Audience ID-JAG não corresponde a este serviço.');
        }

        if (($claims['typ'] ?? null) !== null && ($headers->typ ?? '') !== 'oauth-id-jag+jwt') {
            // Header typ pode vir no payload em alguns emissores; validar exp/iat é prioritário.
        }

        $exp = (int) ($claims['exp'] ?? 0);
        if ($exp < time()) {
            throw new AuthMdException('expired', 'ID-JAG expirado.');
        }

        $iat = (int) ($claims['iat'] ?? 0);
        if ($iat > time() + 120) {
            throw new AuthMdException('expired', 'ID-JAG com iat no futuro.');
        }

        $jti = (string) ($claims['jti'] ?? '');
        if ($jti === '') {
            throw new AuthMdException('invalid_signature', 'ID-JAG sem jti.');
        }

        $replayKey = 'auth_md:jti:' . $jti;
        if (! Cache::add($replayKey, true, max(60, $exp - time() + 60))) {
            throw new AuthMdException('replay_detected', 'ID-JAG já utilizado (jti).');
        }

        $emailVerified = filter_var($claims['email_verified'] ?? false, FILTER_VALIDATE_BOOLEAN);
        $phoneVerified = filter_var($claims['phone_number_verified'] ?? false, FILTER_VALIDATE_BOOLEAN);
        if (! $emailVerified && ! $phoneVerified) {
            throw new AuthMdException('missing_verified_email', 'É necessário email_verified ou phone_number_verified.');
        }

        return ['claims' => $claims, 'issuer' => $issuer];
    }

    /**
     * @param  \Illuminate\Support\Collection<int, array<string, string>>  $trusted
     * @return array<string, array<string, mixed>>
     */
    private function jwksForAssertion(string $assertion, $trusted): array
    {
        $parts = explode('.', $assertion);
        if (count($parts) < 2) {
            throw new AuthMdException('invalid_signature', 'JWT malformado.');
        }

        $header = json_decode((string) base64_decode(strtr($parts[0], '-_', '+/')), true);
        $payload = json_decode((string) base64_decode(strtr($parts[1], '-_', '+/')), true);
        $issuer = rtrim((string) ($payload['iss'] ?? ''), '/');

        $entry = $trusted->first(function (array $row) use ($issuer): bool {
            $configured = rtrim((string) ($row['issuer'] ?? ''), '/');

            return $configured === $issuer || $configured === $issuer . '/';
        });

        if (! $entry) {
            throw new AuthMdException('invalid_issuer', "Emissor não confiável: {$issuer}");
        }

        $jwksUri = $entry['jwks_uri'] ?? rtrim($issuer, '/') . '/.well-known/jwks.json';
        $cacheKey = 'auth_md:jwks:' . md5($jwksUri);

        return Cache::remember($cacheKey, 600, function () use ($jwksUri): array {
            $response = Http::timeout(10)->get($jwksUri);
            if (! $response->successful()) {
                throw new AuthMdException('invalid_signature', 'Falha ao obter JWKS do emissor.');
            }

            $set = $response->json();
            if (! is_array($set) || ! isset($set['keys'])) {
                throw new AuthMdException('invalid_signature', 'JWKS inválido.');
            }

            return $set;
        });
    }

    /**
     * @param  \Illuminate\Support\Collection<int, array<string, string>>  $trusted
     */
    private function issuerIsTrusted(string $issuer, $trusted): bool
    {
        return $trusted->contains(function (array $row) use ($issuer): bool {
            $configured = rtrim((string) ($row['issuer'] ?? ''), '/');

            return $configured === $issuer || $configured . '/' === $issuer . '/';
        });
    }

    /**
     * @param  array<string, mixed>  $claims
     */
    public function verifyLogoutToken(string $token): array
    {
        $trusted = collect(config('auth-md.trusted_issuers', []));

        try {
            $payload = JWT::decode($token, JWK::parseKeySet($this->jwksForAssertion($token, $trusted)));
        } catch (Throwable $e) {
            throw new AuthMdException('invalid_signature', 'Logout token inválido: ' . $e->getMessage());
        }

        $claims = (array) json_decode(json_encode($payload), true);
        $audience = config('auth-md.auth_server_url');
        $aud = $claims['aud'] ?? null;
        $audMatches = is_array($aud)
            ? in_array($audience, $aud, true)
            : rtrim((string) $aud, '/') === rtrim((string) $audience, '/');

        if (! $audMatches) {
            throw new AuthMdException('invalid_audience', 'Audience do logout token inválida.');
        }

        $jti = (string) ($claims['jti'] ?? '');
        if ($jti !== '' && ! Cache::add('auth_md:logout_jti:' . $jti, true, 3600)) {
            throw new AuthMdException('replay_detected', 'Logout token já processado.');
        }

        return $claims;
    }
}
