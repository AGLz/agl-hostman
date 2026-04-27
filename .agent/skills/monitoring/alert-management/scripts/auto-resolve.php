#!/usr/bin/env php
<?php
/**
 * Auto-Resolve Alerts Script
 *
 * Automatically resolves alerts that have exceeded their TTL
 * Should be run periodically via cron or scheduler
 *
 * Usage: ./auto-resolve.php [options]
 *   --dry-run    Show what would be resolved without actually resolving
 *   --hours=N    Only process alerts older than N hours (default: auto_resolve_after_hours)
 */

$baseDir = dirname(__DIR__, 5);
require_once $baseDir . '/vendor/autoload.php';

use App\Models\Alert;
use Illuminate\Support\Facades\DB;

$options = getopt('', ['dry-run', 'hours:']);
$dryRun = isset($options['dry-run']);
$customHours = isset($options['hours']) ? (int) $options['hours'] : null;

echo "Alert Auto-Resolve Script\n";
echo "========================\n";
echo "Dry run: " . ($dryRun ? 'Yes' : 'No') . "\n";

if ($customHours) {
    echo "Custom hours: {$customHours}\n";
}

try {
    // Find alerts that should be auto-resolved
    $query = Alert::where('status', '!=', 'resolved')
        ->whereNotNull('auto_resolve_after_hours');

    // Filter by custom hours if specified
    if ($customHours) {
        $query->where('created_at', '<=', now()->subHours($customHours));
    }

    $alerts = $query->get();

    echo "\nFound {$alerts->count()} alerts to check\n\n";

    $resolved = 0;
    $skipped = 0;

    foreach ($alerts as $alert) {
        if ($alert->shouldAutoResolve()) {
            $resolutionNotes = "Auto-resolved after TTL expired";

            if ($dryRun) {
                echo "[DRY-RUN] Would resolve alert {$alert->id}\n";
                echo "  Title: {$alert->title}\n";
                echo "  Type: {$alert->type}, Severity: {$alert->severity}\n";
                echo "  Created: {$alert->created_at}\n";
                echo "  TTL: {$alert->auto_resolve_after_hours} hours\n";
            } else {
                $alert->resolve($resolutionNotes);
                echo "Resolved alert {$alert->id}: {$alert->title}\n";
            }

            $resolved++;
        } else {
            $skipped++;
        }
    }

    echo "\nSummary:\n";
    echo "  Resolved: {$resolved}\n";
    echo "  Skipped: {$skipped}\n";
    echo "  Total checked: {$alerts->count()}\n";

    if (!$dryRun && $resolved > 0) {
        echo "\nNotifications: Would send browser notifications for resolved alerts\n";
    }

    exit(0);
} catch (\Exception $e) {
    fwrite(STDERR, "Error: {$e->getMessage()}\n");
    exit(1);
}
