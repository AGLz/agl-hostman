<?php

namespace App\Policies;

use App\Models\DailySessionLog;
use App\Models\User;

class DailySessionLogPolicy
{
    public function viewAny(User $user): bool
    {
        return true;
    }

    public function view(User $user, DailySessionLog $dailySessionLog): bool
    {
        return $user->id === $dailySessionLog->user_id;
    }

    public function create(User $user): bool
    {
        return true;
    }

    public function update(User $user, DailySessionLog $dailySessionLog): bool
    {
        return $user->id === $dailySessionLog->user_id;
    }

    public function delete(User $user, DailySessionLog $dailySessionLog): bool
    {
        return $user->id === $dailySessionLog->user_id;
    }
}
