<?php

namespace App\Http\Middleware;

use App\Models\AuditLog;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Check Role Middleware
 * AGL Infrastructure Admin Platform - Phase 5
 *
 * Validates user has required role(s) before allowing access.
 * Supports multiple role checks with 'any' or 'all' logic.
 *
 * Usage:
 * - Route::middleware('role:admin')
 * - Route::middleware('role:admin,super-admin|any')
 * - Route::middleware('role:admin,operator|all')
 */
class CheckRole
{
    /**
     * Handle an incoming request.
     *
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     * @param  string  $roles Comma-separated roles, optionally followed by |any or |all
     * @return \Symfony\Component\HttpFoundation\Response
     */
    public function handle(Request $request, Closure $next, string $roles): Response
    {
        // Check authentication
        if (!auth()->check()) {
            if ($request->expectsJson()) {
                return response()->json([
                    'error' => 'Unauthenticated',
                    'message' => 'Authentication required'
                ], 401);
            }
            return redirect()->route('login');
        }

        $user = auth()->user();

        // Check if user is active
        if (!$user->isActive()) {
            AuditLog::logSecurityEvent(
                $user,
                'inactive_user_access',
                "Inactive user attempted to access: {$request->path()}",
                [
                    'ip' => $request->ip(),
                    'url' => $request->fullUrl(),
                    'method' => $request->method(),
                ]
            );

            if ($request->expectsJson()) {
                return response()->json([
                    'error' => 'Account Inactive',
                    'message' => 'Your account has been deactivated. Please contact an administrator.'
                ], 403);
            }

            abort(403, 'Your account has been deactivated. Please contact an administrator.');
        }

        // Parse roles and logic
        [$roleList, $logic] = $this->parseRoles($roles);

        // Check roles based on logic
        $hasRole = $logic === 'any'
            ? $user->hasAnyRole($roleList)
            : $user->hasAllRoles($roleList);

        if (!$hasRole) {
            // Log unauthorized access attempt
            AuditLog::logSecurityEvent(
                $user,
                'unauthorized_access',
                "User attempted to access role-protected resource: {$request->path()}",
                [
                    'required_roles' => $roleList,
                    'logic' => $logic,
                    'user_roles' => $user->roles->pluck('name')->toArray(),
                    'ip' => $request->ip(),
                    'url' => $request->fullUrl(),
                    'method' => $request->method(),
                ]
            );

            if ($request->expectsJson()) {
                return response()->json([
                    'error' => 'Forbidden',
                    'message' => 'You do not have the required role to perform this action.',
                    'required_roles' => $roleList,
                ], 403);
            }

            abort(403, 'You do not have the required role to perform this action.');
        }

        return $next($request);
    }

    /**
     * Parse role string into array and logic type
     *
     * @param string $roles
     * @return array [roles_array, logic_type]
     */
    private function parseRoles(string $roles): array
    {
        // Check for logic modifier (|any or |all)
        if (str_contains($roles, '|')) {
            [$roleString, $logic] = explode('|', $roles, 2);
            $logic = in_array($logic, ['any', 'all']) ? $logic : 'all';
        } else {
            $roleString = $roles;
            $logic = 'all';
        }

        // Split roles by comma
        $roleList = array_map('trim', explode(',', $roleString));

        return [$roleList, $logic];
    }
}
