<?php

namespace App\Http\Controllers\AuthMd;

use App\Http\Controllers\Controller;
use App\Services\AuthMd\AuthMdDiscoveryService;
use Symfony\Component\HttpFoundation\Response;

class AuthMdDocumentController extends Controller
{
    public function __invoke(AuthMdDiscoveryService $discovery): Response
    {
        if (! $discovery->isEnabled()) {
            abort(404);
        }

        return response($discovery->markdownDocument(), Response::HTTP_OK, [
            'Content-Type' => 'text/markdown; charset=utf-8',
        ]);
    }
}
