<?php

namespace App\Http\Controllers\AuthMd;

use App\Http\Controllers\Controller;
use App\Services\AuthMd\AgentRegistrationService;
use App\Services\AuthMd\AuthMdDiscoveryService;
use App\Services\AuthMd\AuthMdException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\View\View;

class AgentAuthController extends Controller
{
    public function register(Request $request, AgentRegistrationService $service): JsonResponse
    {
        $this->ensureEnabled();
        $this->rateLimit('auth-md-register', (int) config('auth-md.rate_limits.register', 30));

        try {
            $payload = $request->validate([
                'type' => ['required', 'string'],
                'assertion_type' => ['sometimes', 'string'],
                'assertion' => ['sometimes', 'string'],
                'requested_credential_type' => ['sometimes', 'string', 'in:api_key,access_token'],
            ]);

            return response()->json($service->register($payload));
        } catch (AuthMdException $e) {
            return $this->errorResponse($e);
        }
    }

    public function claim(Request $request, AgentRegistrationService $service): JsonResponse
    {
        $this->ensureEnabled();
        $this->rateLimit('auth-md-claim', (int) config('auth-md.rate_limits.claim', 20));

        try {
            $payload = $request->validate([
                'claim_token' => ['required', 'string'],
                'email' => ['required', 'email'],
            ]);

            return response()->json($service->startClaim($payload));
        } catch (AuthMdException $e) {
            return $this->errorResponse($e);
        }
    }

    public function completeClaim(Request $request, AgentRegistrationService $service): JsonResponse
    {
        $this->ensureEnabled();
        $this->rateLimit('auth-md-claim', (int) config('auth-md.rate_limits.claim', 20));

        try {
            $payload = $request->validate([
                'claim_token' => ['required', 'string'],
                'otp' => ['required', 'string', 'size:6'],
            ]);

            return response()->json($service->completeClaim($payload));
        } catch (AuthMdException $e) {
            return $this->errorResponse($e);
        }
    }

    public function claimView(Request $request, AgentRegistrationService $service): View
    {
        $this->ensureEnabled();
        $token = (string) $request->query('token', '');
        $registration = $service->findByClaimViewToken($token);

        return view('auth-md.claim-otp', [
            'appName' => config('auth-md.app_name'),
            'email' => $registration->claim_email,
        ]);
    }

    public function revoke(Request $request, AgentRegistrationService $service): JsonResponse
    {
        $this->ensureEnabled();

        try {
            $body = $request->getContent();
            if ($body === '') {
                throw new AuthMdException('invalid_request', 'Corpo logout+jwt em falta.');
            }

            $service->revokeLogoutToken($body);

            return response()->json(['status' => 'revoked']);
        } catch (AuthMdException $e) {
            return $this->errorResponse($e);
        }
    }

    protected function ensureEnabled(): void
    {
        if (! app(AuthMdDiscoveryService::class)->isEnabled()) {
            abort(404);
        }
    }

    protected function rateLimit(string $key, int $maxAttempts): void
    {
        $rateKey = $key . ':' . request()->ip();
        if (! RateLimiter::attempt($rateKey, $maxAttempts, fn() => true, 60)) {
            abort(429, 'Rate limit exceeded');
        }
    }

    protected function errorResponse(AuthMdException $e): JsonResponse
    {
        $status = match ($e->errorCode) {
            'invalid_issuer', 'invalid_signature', 'expired', 'replay_detected',
            'invalid_audience', 'invalid_client_id', 'missing_verified_email' => 400,
            'unsupported_credential_type' => 422,
            default => 400,
        };

        return response()->json([
            'error' => $e->errorCode,
            'message' => $e->getMessage(),
        ], $status);
    }
}
