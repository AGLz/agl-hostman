<?php

declare(strict_types=1);

namespace App\Http\Concerns;

use Symfony\Component\HttpFoundation\Request;

trait ExtractsApiKeyFromRequest
{
    protected function extractApiKeyFromRequest(Request $request): ?string
    {
        if ($request->hasHeader('X-API-Key')) {
            return $request->header('X-API-Key');
        }

        if ($request->hasHeader('Authorization')) {
            $auth = $request->header('Authorization');
            if (is_string($auth) && str_starts_with($auth, 'Bearer ')) {
                return substr($auth, 7);
            }
        }

        if (config('security.allow_query_api_key', false) && $request->has('api_key')) {
            return $request->input('api_key');
        }

        return null;
    }
}
