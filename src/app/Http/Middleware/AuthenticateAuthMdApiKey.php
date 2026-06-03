<?php

namespace App\Http\Middleware;

use App\Http\Concerns\ExtractsApiKeyFromRequest;
use App\Models\ApiKey;
use App\Services\AuthMd\AuthMdDiscoveryService;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Cache;
use Symfony\Component\HttpFoundation\Response;

/**
 * Autentica credenciais api_key emitidas via auth.md (sk_*, ak_*) antes do Sanctum,
 * definindo o utilizador no guard web para o Guard do Sanctum resolver o pedido.
 */
class AuthenticateAuthMdApiKey
{
    use ExtractsApiKeyFromRequest;

    public function handle(Request $request, Closure $next): Response
    {
        if (! app(AuthMdDiscoveryService::class)->isEnabled()) {
            return $next($request);
        }

        if (Auth::guard('web')->check()) {
            return $next($request);
        }

        $rawKey = $this->extractApiKeyFromRequest($request);
        if ($rawKey === null || ! $this->isAuthMdApiKeyFormat($rawKey)) {
            return $next($request);
        }

        $apiKey = Cache::remember(
            'auth_md_api_key:' . substr(hash('sha256', $rawKey), 0, 16),
            300,
            fn() => ApiKey::query()->where('key', $rawKey)->first()
        );

        if (! $apiKey instanceof ApiKey || ! $apiKey->isValid() || ! $apiKey->user) {
            return $next($request);
        }

        Auth::guard('web')->setUser($apiKey->user);
        $request->attributes->set('api_key', $apiKey);
        $apiKey->recordUsage($request->ip());

        return $next($request);
    }

    protected function isAuthMdApiKeyFormat(string $key): bool
    {
        return (bool) preg_match('/^(sk_(test|live)_[A-Za-z0-9]+|ak_[A-Za-z0-9]+)$/', $key);
    }
}
