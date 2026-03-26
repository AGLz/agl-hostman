<?php

namespace App\Http\Middleware;

use App\Models\AuditLog;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Check Permission Middleware
 * AGL Infrastructure Admin Platform - Phase 5
 *
 * Validates user has required permission(s) before allowing access.
 * Supports multiple permission checks with 'any' or 'all' logic.
 *
 * Usage:
 * - Route::middleware('permission:view-dashboard')
 * - Route::middleware('permission:manage-users,edit-users|any')
 * - Route::middleware('permission:create-users,assign-roles|all')
 */
class CheckPermission
{
    /**
     * Handle an incoming request.
     *
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     * @param  string  $permissions  Comma-separated permissions, optionally followed by |any or |all
     */
    public function handle(Request $request, Closure $next, string $permissions): Response
    {
        // Check authentication
        if (! auth()->check()) {
            if ($request->expectsJson()) {
                return response()->json([
                    'error' => 'Unauthenticated',
                    'message' => 'Authentication required',
                ], 401);
            }

            return redirect()->route('login');
        }

        $user = auth()->user();

        // Check if user is active
        if (! $user->isActive()) {
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
                    'message' => 'Your account has been deactivated. Please contact an administrator.',
                ], 403);
            }

            abort(403, 'Your account has been deactivated. Please contact an administrator.');
        }

        // Parse permissions and logic
        [$permissionList, $logic] = $this->parsePermissions($permissions);

        // Check permissions based on logic
        $hasPermission = $logic === 'any'
            ? $user->hasAnyPermission($permissionList)
            : $user->hasAllPermissions($permissionList);

        if (! $hasPermission) {
            // Log unauthorized access attempt
            AuditLog::logSecurityEvent(
                $user,
                'unauthorized_access',
                "User attempted to access protected resource: {$request->path()}",
                [
                    'required_permissions' => $permissionList,
                    'logic' => $logic,
                    'user_permissions' => $user->getAllPermissions()->pluck('name')->toArray(),
                    'ip' => $request->ip(),
                    'url' => $request->fullUrl(),
                    'method' => $request->method(),
                ]
            );

            if ($request->expectsJson()) {
                return response()->json([
                    'error' => 'Forbidden',
                    'message' => 'You do not have permission to perform this action.',
                    'required_permissions' => $permissionList,
                ], 403);
            }

            abort(403, 'You do not have permission to perform this action.');
        }

        return $next($request);
    }

    /**
     * Parse permission string into array and logic type
     *
     * @return array [permissions_array, logic_type]
     */
    private function parsePermissions(string $permissions): array
    {
        // Check for logic modifier (|any or |all)
        if (str_contains($permissions, '|')) {
            [$permissionString, $logic] = explode('|', $permissions, 2);
            $logic = in_array($logic, ['any', 'all']) ? $logic : 'all';
        } else {
            $permissionString = $permissions;
            $logic = 'all';
        }

        // Split permissions by comma
        $permissionList = array_map('trim', explode(',', $permissionString));

        return [$permissionList, $logic];
    }
}
