<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class CheckRole
{
    public function handle(Request $request, Closure $next, string $roles): Response
    {
        $user = $request->user();

        if (! $user) {
            return response('Unauthorized', 401);
        }

        if (($user->is_active ?? true) === false) {
            return response('Forbidden', 403);
        }

        [$roleList, $mode] = $this->parseRoles($roles);

        if (! $this->matchesRoles($user, $roleList, $mode)) {
            return response('Forbidden', 403);
        }

        return $next($request);
    }

    private function parseRoles(string $roles): array
    {
        [$rolePart, $mode] = array_pad(explode('|', $roles, 2), 2, 'any');

        $roleList = array_values(array_filter(array_map('trim', explode(',', $rolePart))));
        $mode = strtolower(trim($mode)) === 'all' ? 'all' : 'any';

        return [$roleList, $mode];
    }

    private function matchesRoles(object $user, array $roles, string $mode): bool
    {
        if ($roles === []) {
            return true;
        }

        if ($mode === 'all') {
            foreach ($roles as $role) {
                if (! $this->hasRole($user, $role)) {
                    return false;
                }
            }

            return true;
        }

        foreach ($roles as $role) {
            if ($this->hasRole($user, $role)) {
                return true;
            }
        }

        return false;
    }

    private function hasRole(object $user, string $role): bool
    {
        if (method_exists($user, 'hasRole')) {
            return $user->hasRole($role);
        }

        $roles = $user->roles ?? collect();

        if (is_iterable($roles)) {
            foreach ($roles as $userRole) {
                $name = is_object($userRole) ? ($userRole->name ?? null) : $userRole;
                if ($name === $role) {
                    return true;
                }
            }
        }

        return false;
    }
}
