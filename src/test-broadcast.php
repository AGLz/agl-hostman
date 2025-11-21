#!/usr/bin/env php
<?php

/**
 * Laravel Reverb Broadcast Testing Script
 *
 * This script tests real-time event broadcasting via Laravel Reverb
 * Usage: php test-broadcast.php
 */

require __DIR__.'/vendor/autoload.php';

use App\Events\ServerMetricsUpdated;
use App\Events\ContainerStatusChanged;
use App\Events\AlertTriggered;
use Illuminate\Support\Facades\Artisan;

$app = require_once __DIR__.'/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

echo "\n";
echo "===========================================\n";
echo "  Laravel Reverb Broadcast Test\n";
echo "===========================================\n\n";

// Test 1: Server Metrics Event
echo "1. Broadcasting Server Metrics Update...\n";
$serverEvent = new ServerMetricsUpdated(
    serverCode: 'AGLSRV1',
    cpuUsage: 45.7,
    memoryUsage: 62.3,
    containerCount: 68,
    status: 'online',
    uptime: 7200,
    networkStats: [
        'tx_bytes' => 1024000,
        'rx_bytes' => 2048000,
    ]
);
broadcast($serverEvent);
echo "   ✓ Broadcasted to: infrastructure.server.AGLSRV1\n";
echo "   ✓ Event: server.metrics.updated\n\n";

// Wait a bit
sleep(1);

// Test 2: Container Status Change Event
echo "2. Broadcasting Container Status Change...\n";
$containerEvent = new ContainerStatusChanged(
    vmid: '179',
    name: 'agldv03',
    status: 'running',
    previousStatus: 'stopped',
    serverCode: 'AGLSRV1',
    metrics: [
        'cpu' => 23.5,
        'memory' => 4096,
        'disk' => 15000,
    ]
);
broadcast($containerEvent);
echo "   ✓ Broadcasted to: infrastructure.container.179\n";
echo "   ✓ Broadcasted to: infrastructure.server.AGLSRV1\n";
echo "   ✓ Event: container.status.changed\n\n";

// Wait a bit
sleep(1);

// Test 3: Alert Event
echo "3. Broadcasting Infrastructure Alert...\n";
$alertEvent = new AlertTriggered(
    severity: 'warning',
    title: 'High CPU Usage Detected',
    message: 'AGLSRV1 CPU usage has exceeded 80%',
    resourceType: 'server',
    resourceId: 'AGLSRV1',
    metadata: [
        'cpu_usage' => 85.2,
        'threshold' => 80.0,
        'duration' => '5 minutes',
    ]
);
broadcast($alertEvent);
echo "   ✓ Broadcasted to: infrastructure.alerts\n";
echo "   ✓ Broadcasted to: infrastructure.alerts.warning\n";
echo "   ✓ Event: alert.triggered\n\n";

// Test 4: Critical Alert
echo "4. Broadcasting Critical Alert...\n";
$criticalAlert = new AlertTriggered(
    severity: 'critical',
    title: 'Container Failure',
    message: 'Container CT180 has stopped unexpectedly',
    resourceType: 'container',
    resourceId: '180',
    metadata: [
        'exit_code' => 1,
        'last_status' => 'running',
        'error' => 'Out of memory',
    ]
);
broadcast($criticalAlert);
echo "   ✓ Broadcasted to: infrastructure.alerts\n";
echo "   ✓ Broadcasted to: infrastructure.alerts.critical\n";
echo "   ✓ Event: alert.triggered\n\n";

echo "===========================================\n";
echo "  Test Complete!\n";
echo "===========================================\n\n";
echo "Next Steps:\n";
echo "1. Check Reverb server logs for broadcast confirmations\n";
echo "2. Open browser console to see WebSocket connections\n";
echo "3. Verify events are received in frontend\n\n";
echo "Expected Frontend Console Output:\n";
echo "  [Echo] Connected to Reverb WebSocket server\n";
echo "  [useServerMetrics] Metrics update for AGLSRV1: {...}\n";
echo "  [useContainerStatus] Status change for 179: {...}\n";
echo "  [useInfrastructureAlerts] Alert received: {...}\n\n";
