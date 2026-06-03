<?php

namespace App\Http\Middleware;

use App\Services\AuthMd\AuthMdDiscoveryService;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class AuthMdUnauthorizedHint
{
    public function handle(Request $request, Closure $next): Response
    {
        $response = $next($request);

        if ($response->getStatusCode() !== 401) {
            return $response;
        }

        $discovery = app(AuthMdDiscoveryService::class);
        if (! $discovery->isEnabled() || ! $request->is('api/*')) {
            return $response;
        }

        if (! $response->headers->has('WWW-Authenticate')) {
            $response->headers->set('WWW-Authenticate', $discovery->wwwAuthenticateHeader());
        }

        return $response;
    }
}
