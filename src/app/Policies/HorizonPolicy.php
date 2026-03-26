<?php

namespace App\Policies;

use App\Models\User;
use Illuminate\Auth\Access\Response;

class HorizonPolicy
{
    /**
     * Determine if the user can view Horizon.
     */
    public function viewHorizon(User $user): Response
    {
        // Only users with admin role or with permission to view horizon
        return $user->hasRole('admin') || $user->hasPermissionTo('view horizon')
            ? Response::allow()
            : Response::deny('You do not have permission to access Horizon.');
    }
}
