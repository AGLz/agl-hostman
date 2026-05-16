<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class CheckPermission
{
    public function handle(Request $request, Closure $next, string $permission, string $mode = 'all'): Response
    {
        $user = $request->user();

        if (! $user) {
            return response('Unauthorized', 401);
        }

        if (($user->is_active ?? true) === false) {
            return response('Forbidden', 403);
        }

        [$permissions, $mode] = $this->parsePermissions($permission, $mode);

        if (! $this->hasRequiredPermissions($user, $permissions, $mode)) {
            return response('Forbidden', 403);
        }

        return $next($request);
    }

    private function parsePermissions(string $permission, string $mode): array
    {
        if (str_contains($permission, '|')) {
            [$permission, $mode] = explode('|', $permission, 2);
        }

        $permissions = array_values(array_filter(array_map('trim', explode(',', $permission))));
        $mode = strtolower(trim($mode)) === 'any' ? 'any' : 'all';

        return [$permissions, $mode];
    }

    private function hasRequiredPermissions(object $user, array $permissions, string $mode): bool
    {
        if ($permissions === []) {
            return false;
        }

        foreach ($permissions as $permission) {
            $hasPermission = $this->hasPermission($user, $permission);

            if ($mode === 'any' && $hasPermission) {
                return true;
            }

            if ($mode === 'all' && ! $hasPermission) {
                return false;
            }
        }

        return $mode === 'all';
    }

    private function hasPermission(object $user, string $permission): bool
    {
        if (method_exists($user, 'hasPermissionTo')) {
            try {
                return $user->hasPermissionTo($permission);
            } catch (\Throwable) {
                return false;
            }
        }

        if (method_exists($user, 'can')) {
            try {
                return $user->can($permission);
            } catch (\Throwable) {
                return false;
            }
        }

        $permissions = $user->permissions ?? collect();

        if (is_iterable($permissions)) {
            foreach ($permissions as $userPermission) {
                $name = is_object($userPermission) ? ($userPermission->name ?? null) : $userPermission;
                if ($name === $permission) {
                    return true;
                }
            }
        }

        return false;
    }
}
