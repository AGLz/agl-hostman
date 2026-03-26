<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * CheckLocationAccess Middleware
 *
 * Validates that the authenticated user has access to a specific physical location.
 * Supports multiple locations with 'any' or 'all' logic.
 *
 * Usage:
 *   Route::get('/...')->middleware('location:AGLSRV1');
 *   Route::get('/...')->middleware('location:AGLSRV1,CT179|any');
 *   Route::get('/...')->middleware('location:AGLSRV1,CT179|all');
 *   Route::get('/...')->middleware('location:AGLSRV1|admin'); // Require admin access level
 */
class CheckLocationAccess
{
    /**
     * Handle an incoming request.
     *
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     * @param  string  ...$params  Middleware parameters (Laravel splits by comma, so we use variadic to catch all)
     */
    public function handle(Request $request, Closure $next, string ...$params): Response
    {
        // Laravel splits middleware params by comma, so we need to join them back
        // Example: 'location:AGLSRV1,AGLSRV6|all' becomes ['AGLSRV1', 'AGLSRV6|all']
        $locations = implode(',', $params);

        // Check authentication
        if (! auth()->check()) {
            if ($request->expectsJson()) {
                return response()->json([
                    'error' => 'Unauthenticated',
                    'message' => 'Authentication required for location-based access control',
                ], 401);
            }

            return redirect()->route('login');
        }

        $user = auth()->user();

        // Check if user is active
        if (! $user->isActive()) {
            abort(403, 'Your account has been deactivated.');
        }

        // Parse locations parameter
        [$locationList, $logic, $accessLevel] = $this->parseLocations($locations);

        // Super admin bypasses location restrictions
        if ($user->isSuperAdmin()) {
            return $next($request);
        }

        // Check location access
        $hasAccess = $this->checkLocationAccess($user, $locationList, $logic, $accessLevel);

        if (! $hasAccess) {
            if ($request->expectsJson()) {
                return response()->json([
                    'error' => 'Forbidden',
                    'message' => 'You do not have access to the required location(s).',
                    'required_locations' => $locationList,
                    'logic' => $logic,
                    'required_level' => $accessLevel,
                    'your_locations' => $user->physicalLocations->pluck('code')->toArray(),
                ], 403);
            }

            abort(403, 'You do not have access to the required location(s).');
        }

        return $next($request);
    }

    /**
     * Parse locations parameter into components
     *
     * Examples:
     *   "AGLSRV1" → [["AGLSRV1"], "any", "view"]
     *   "AGLSRV1,CT179|any" → [["AGLSRV1", "CT179"], "any", "view"]
     *   "AGLSRV1,CT179|all" → [["AGLSRV1", "CT179"], "all", "view"]
     *   "AGLSRV1|admin" → [["AGLSRV1"], "any", "admin"]
     *   "AGLSRV1,CT179|all|admin" → [["AGLSRV1", "CT179"], "all", "admin"]
     *
     * @return array [locationList, logic, accessLevel]
     */
    protected function parseLocations(string $locations): array
    {
        $logic = 'any';
        $accessLevel = 'view';
        $parts = explode('|', $locations);

        // First part is always location codes
        $locationList = explode(',', $parts[0]);

        // Check for logic modifier (any/all)
        if (isset($parts[1]) && in_array($parts[1], ['any', 'all'])) {
            $logic = $parts[1];
            // Check for access level in third part
            if (isset($parts[2])) {
                $accessLevel = $parts[2];
            }
        } elseif (isset($parts[1])) {
            // If second part is not any/all, it's the access level
            $accessLevel = $parts[1];
        }

        return [$locationList, $logic, $accessLevel];
    }

    /**
     * Check if user has access to locations based on logic and access level
     *
     * @param  User  $user
     */
    protected function checkLocationAccess($user, array $locationList, string $logic, string $accessLevel): bool
    {
        if ($logic === 'all') {
            // User must have access to ALL specified locations
            foreach ($locationList as $locationCode) {
                if (! $user->hasAccessToLocation($locationCode, $accessLevel)) {
                    return false;
                }
            }

            return true;
        } else {
            // User must have access to ANY of the specified locations (default)
            foreach ($locationList as $locationCode) {
                if ($user->hasAccessToLocation($locationCode, $accessLevel)) {
                    return true;
                }
            }

            return false;
        }
    }

    /**
     * Get location access levels
     *
     * Access levels in order of privilege:
     * - view: Read-only access
     * - manage: Modify and configure
     * - admin: Full administrative access
     */
    public static function getAccessLevels(): array
    {
        return [
            'view' => 'View Only',
            'manage' => 'Manage Resources',
            'admin' => 'Full Administrative Access',
        ];
    }
}
