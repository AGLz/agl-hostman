<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class CheckPermission
{
    public function handle(Request $request, Closure $next, string $permission): Response
    {
        $user = $request->user();

        if (! $user) {
            return response('Unauthorized', 401);
        }

        if (($user->is_active ?? true) === false) {
            return response('Forbidden', 403);
        }

        if (! $this->hasPermission($user, $permission)) {
            return response('Forbidden', 403);
        }

        return $next($request);
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
