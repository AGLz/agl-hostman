<?php

namespace App\Http\Middleware;

use App\Models\AuditLog;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Ensure User Is Active Middleware
 * AGL Infrastructure Admin Platform - Phase 5
 *
 * Validates that authenticated user has active status.
 * Can be applied globally or to specific route groups.
 *
 * Usage:
 * - Route::middleware('active')
 * - Apply to route groups that require active users
 */
class EnsureUserIsActive
{
    /**
     * Handle an incoming request.
     *
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        if (! auth()->check()) {
            return $next($request);
        }

        $user = auth()->user();

        // Check if user is active
        if (! $user->isActive()) {
            // Log the inactive access attempt
            AuditLog::logSecurityEvent(
                $user,
                'inactive_user_access',
                "Inactive user attempted to access: {$request->path()}",
                [
                    'ip' => $request->ip(),
                    'url' => $request->fullUrl(),
                    'method' => $request->method(),
                    'user_agent' => $request->userAgent(),
                ]
            );

            // Logout the user
            auth()->logout();

            if ($request->expectsJson()) {
                return response()->json([
                    'error' => 'Account Inactive',
                    'message' => 'Your account has been deactivated. Please contact an administrator.',
                ], 403);
            }

            // Redirect to login with error message
            return redirect()->route('login')
                ->with('error', 'Your account has been deactivated. Please contact an administrator.');
        }

        return $next($request);
    }
}
