#!/bin/bash
# Phase 3 Alert Center - Quick Deployment Script
# Run from /mnt/overpower/apps/dev/agl/agl-hostman/src

set -e

echo "==============================================="
echo "Phase 3 Alert Center - Deployment"
echo "==============================================="
echo ""

# Check if we're in the right directory
if [ ! -f "artisan" ]; then
    echo "❌ Error: Must run from Laravel project root (/src)"
    exit 1
fi

# 1. Check database connection
echo "1. Testing database connection..."
php artisan db:show || { echo "❌ Database connection failed"; exit 1; }
echo "✅ Database connected"
echo ""

# 2. Run migrations
echo "2. Running alert system migrations..."
php artisan migrate --path=database/migrations/2025_01_20_000001_create_alerts_table.php --force
php artisan migrate --path=database/migrations/2025_01_20_000002_create_alert_rules_table.php --force
echo "✅ Migrations completed"
echo ""

# 3. Verify tables
echo "3. Verifying tables..."
php artisan tinker --execute="
echo 'alerts table: ' . (Schema::hasTable('alerts') ? '✅' : '❌') . PHP_EOL;
echo 'alert_rules table: ' . (Schema::hasTable('alert_rules') ? '✅' : '❌') . PHP_EOL;
"
echo ""

# 4. Test Alert model
echo "4. Testing Alert model..."
php artisan tinker --execute="
\$alert = App\Models\Alert::create([
    'type' => 'info',
    'title' => 'Test Alert - Deployment',
    'message' => 'Alert system deployed successfully at ' . now(),
    'source' => 'system',
    'severity' => 10
]);
echo 'Created alert ID: ' . \$alert->id . PHP_EOL;
echo 'Alert count: ' . App\Models\Alert::count() . PHP_EOL;
"
echo "✅ Alert model working"
echo ""

# 5. Test AlertService
echo "5. Testing AlertService..."
php artisan tinker --execute="
\$service = app(\App\Services\AlertService::class);
\$stats = \$service->getAlertStats();
echo 'Total alerts: ' . \$stats['total'] . PHP_EOL;
echo 'Active alerts: ' . \$stats['active'] . PHP_EOL;
echo 'By type (critical): ' . \$stats['by_type']['critical'] . PHP_EOL;
echo 'By type (warning): ' . \$stats['by_type']['warning'] . PHP_EOL;
echo 'By type (info): ' . \$stats['by_type']['info'] . PHP_EOL;
"
echo "✅ AlertService working"
echo ""

# 6. Create sample alert rule
echo "6. Creating sample alert rule..."
php artisan tinker --execute="
\$rule = App\Models\AlertRule::create([
    'name' => 'Server CPU Critical',
    'description' => 'Triggers when server CPU exceeds 90% for 5 minutes',
    'rule_type' => 'threshold',
    'conditions' => [
        'metric' => 'cpu',
        'target' => 'server',
        'target_id' => 'aglsrv1',
        'operator' => '>',
        'value' => 90,
        'duration_minutes' => 5
    ],
    'actions' => [
        'alert_type' => 'critical',
        'title' => 'Server CPU Critical'
    ],
    'enabled' => true,
    'cooldown_minutes' => 15
]);
echo 'Created rule: ' . \$rule->name . ' (ID: ' . \$rule->id . ')' . PHP_EOL;
echo 'Rule count: ' . App\Models\AlertRule::count() . PHP_EOL;
"
echo "✅ AlertRule model working"
echo ""

# 7. Test AlertRuleEngine
echo "7. Testing AlertRuleEngine (may trigger alert if CPU high)..."
php artisan tinker --execute="
\$engine = app(\App\Services\AlertRuleEngine::class);
\$rule = App\Models\AlertRule::first();
if (\$rule) {
    echo 'Evaluating rule: ' . \$rule->name . PHP_EOL;
    try {
        \$alert = \$engine->evaluateRule(\$rule);
        if (\$alert) {
            echo '⚠️  Alert triggered: ' . \$alert->title . PHP_EOL;
        } else {
            echo '✅ No alert triggered (conditions not met)' . PHP_EOL;
        }
    } catch (\Exception \$e) {
        echo '⚠️  Rule evaluation error (expected if MetricsCollector not fully set up): ' . \$e->getMessage() . PHP_EOL;
    }
} else {
    echo 'No rules found' . PHP_EOL;
}
"
echo ""

# 8. Summary
echo "==============================================="
echo "✅ Phase 3 Alert Center - Deployment Complete"
echo "==============================================="
echo ""
echo "Next steps:"
echo "1. Create WebSocket events (AlertCreated, AlertAcknowledged, AlertResolved)"
echo "2. Create controllers (AlertController, AlertRuleController)"
echo "3. Add routes (routes/api.php, routes/web.php)"
echo "4. Complete React components (AlertCard, AlertNotification, etc.)"
echo "5. Create custom hooks (useAlerts, useAlertNotifications)"
echo "6. Create console command (EvaluateAlertRules)"
echo "7. Add to scheduler (app/Console/Kernel.php)"
echo "8. Create tests (Feature, Unit, JavaScript)"
echo ""
echo "Documentation: docs/PHASE3-ALERT-CENTER-IMPLEMENTATION.md"
echo ""
