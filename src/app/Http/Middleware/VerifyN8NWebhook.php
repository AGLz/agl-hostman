<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Symfony\Component\HttpFoundation\Response;

/**
 * VerifyN8NWebhook - HMAC signature verification for N8N webhooks
 *
 * Implements security hardening for unauthenticated N8N webhook endpoint
 * Based on CODE-ANALYSIS-REPORT.md critical security issue #2
 */
class VerifyN8NWebhook
{
    /**
     * Handle an incoming request.
     */
    public function handle(Request $request, Closure $next): Response
    {
        $webhookSecret = config('services.n8n.webhook_secret');

        if (empty($webhookSecret)) {
            Log::critical('N8N_WEBHOOK_SECRET not configured - webhook verification disabled');

            // In production, you might want to reject all requests if secret is not set
            if (app()->environment('production')) {
                abort(500, 'Webhook secret not configured');
            }

            return $next($request);
        }

        // Get signature from header
        $signature = $request->header('X-N8N-Signature');

        if (empty($signature)) {
            Log::warning('N8N webhook rejected - missing signature', [
                'ip' => $request->ip(),
                'user_agent' => $request->userAgent(),
            ]);

            abort(401, 'Missing webhook signature');
        }

        // Get raw payload for signature verification
        $payload = $request->getContent();

        // Calculate expected signature
        $expectedSignature = hash_hmac('sha256', $payload, $webhookSecret);

        // Timing-safe comparison to prevent timing attacks
        if (! hash_equals($expectedSignature, $signature)) {
            Log::warning('N8N webhook rejected - invalid signature', [
                'ip' => $request->ip(),
                'user_agent' => $request->userAgent(),
                'received_signature' => substr($signature, 0, 8).'...',
            ]);

            abort(403, 'Invalid webhook signature');
        }

        // Optional: Verify timestamp to prevent replay attacks
        $timestamp = $request->header('X-N8N-Timestamp');

        if ($timestamp) {
            $maxAge = 300; // 5 minutes
            $age = time() - (int) $timestamp;

            if ($age > $maxAge) {
                Log::warning('N8N webhook rejected - timestamp too old', [
                    'age_seconds' => $age,
                    'max_age_seconds' => $maxAge,
                ]);

                abort(403, 'Webhook timestamp expired');
            }
        }

        Log::info('N8N webhook signature verified successfully', [
            'ip' => $request->ip(),
            'event_type' => $request->input('event'),
        ]);

        return $next($request);
    }

    /**
     * Generate signature for testing
     *
     * @param  string  $payload  Request body
     * @return string HMAC signature
     */
    public static function generateSignature(string $payload): string
    {
        return hash_hmac('sha256', $payload, config('services.n8n.webhook_secret'));
    }
}
