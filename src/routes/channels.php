<?php

use Illuminate\Support\Facades\Broadcast;

/**
 * User Private Channel
 */
Broadcast::channel('App.Models.User.{id}', function ($user, $id) {
    return (int) $user->id === (int) $id;
});

/**
 * Infrastructure Public Channels
 *
 * These channels broadcast real-time infrastructure updates
 * to authenticated users with appropriate permissions
 */
Broadcast::channel('infrastructure.server.{serverCode}', function ($user) {
    // Check if user has permission to view infrastructure
    return in_array($user->role, ['admin', 'advanced', 'common']);
});

Broadcast::channel('infrastructure.container.{vmid}', function ($user) {
    return in_array($user->role, ['admin', 'advanced', 'common']);
});

Broadcast::channel('infrastructure.alerts', function ($user) {
    return in_array($user->role, ['admin', 'advanced', 'common']);
});

Broadcast::channel('infrastructure.alerts.{severity}', function ($user, $severity) {
    // Critical alerts only for admin/advanced
    if ($severity === 'critical') {
        return in_array($user->role, ['admin', 'advanced']);
    }

    return in_array($user->role, ['admin', 'advanced', 'common']);
});
