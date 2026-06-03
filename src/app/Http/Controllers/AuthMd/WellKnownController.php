<?php

namespace App\Http\Controllers\AuthMd;

use App\Http\Controllers\Controller;
use App\Services\AuthMd\AuthMdDiscoveryService;
use Illuminate\Http\JsonResponse;

class WellKnownController extends Controller
{
    public function protectedResource(AuthMdDiscoveryService $discovery): JsonResponse
    {
        if (! $discovery->isEnabled()) {
            abort(404);
        }

        return response()->json($discovery->resourceMetadata());
    }

    public function authorizationServer(AuthMdDiscoveryService $discovery): JsonResponse
    {
        if (! $discovery->isEnabled()) {
            abort(404);
        }

        return response()->json($discovery->authorizationServerMetadata());
    }
}
