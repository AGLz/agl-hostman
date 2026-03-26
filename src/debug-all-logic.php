#!/usr/bin/env php
<?php

require __DIR__.'/vendor/autoload.php';

$app = require_once __DIR__.'/bootstrap/app.php';
$app->make(\Illuminate\Contracts\Console\Kernel::class)->bootstrap();

use App\Models\User;

echo "=== Debugging ALL Logic Issue ===\n\n";

// Find test user
$user = User::where('email', 'locationtest@example.com')->first();

if (! $user) {
    echo "❌ Test user not found!\n";
    exit(1);
}

echo "✅ User found: {$user->name} ({$user->email})\n";
echo '   Is active: '.($user->isActive() ? 'YES' : 'NO')."\n";
echo '   Is super admin: '.($user->isSuperAdmin() ? 'YES' : 'NO')."\n";
echo '   Roles: '.$user->roles->pluck('name')->join(', ')."\n\n";

// Get user's locations
$userLocations = $user->physicalLocations;
echo "📍 User's Locations:\n";
foreach ($userLocations as $location) {
    echo "   - {$location->code} ({$location->pivot->access_level}".
         ($location->pivot->is_primary ? ', PRIMARY' : '').")\n";
}
echo "\n";

// Test individual location access
echo "🔍 Testing hasAccessToLocation():\n";
$testCodes = ['AGLSRV1', 'AGLSRV6', 'CT179', 'CT183'];
foreach ($testCodes as $code) {
    $hasAccess = $user->hasAccessToLocation($code);
    echo "   - {$code}: ".($hasAccess ? '✅ YES' : '❌ NO')."\n";
}
echo "\n";

// Simulate ALL logic check
echo "🧪 Simulating ALL logic for AGLSRV1,AGLSRV6:\n";
$locationList = ['AGLSRV1', 'AGLSRV6'];
$logic = 'all';
$accessLevel = 'view';

echo '   Required locations: '.implode(', ', $locationList)."\n";
echo "   Logic: {$logic}\n";
echo "   Access level: {$accessLevel}\n\n";

$hasAccessToAll = true;
foreach ($locationList as $locationCode) {
    $hasAccess = $user->hasAccessToLocation($locationCode, $accessLevel);
    echo "   Checking {$locationCode}: ".($hasAccess ? '✅ PASS' : '❌ FAIL')."\n";

    if (! $hasAccess) {
        $hasAccessToAll = false;
    }
}

echo "\n   Final result: ".($hasAccessToAll ? '✅ ACCESS GRANTED' : '❌ ACCESS DENIED')."\n";
echo "   Expected: ❌ ACCESS DENIED (user missing AGLSRV6)\n\n";

if ($hasAccessToAll) {
    echo "🐛 BUG DETECTED: ALL logic should have denied access!\n";
} else {
    echo "✅ ALL logic working correctly!\n";
}
