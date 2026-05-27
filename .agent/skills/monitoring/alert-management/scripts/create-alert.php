#!/usr/bin/env php
<?php
/**
 * Alert Creation Script
 *
 * Creates alerts programmatically with deduplication
 * Can be used in monitoring pipelines and automation
 *
 * Usage: ./create-alert.php [options]
 *   --type=TYPE         Alert type (critical, warning, info)
 *   --title=TITLE       Alert title
 *   --message=MESSAGE   Alert message
 *   --source=SOURCE     Alert source (server, container, etc.)
 *   --source-id=ID      Source resource ID
 *   --severity=N        Severity level (0-100)
 *   --resource-type=TYPE Resource type for polymorphic relation
 *   --resource-id=ID    Resource ID for polymorphic relation
 *   --alert-type=TYPE   Alert type (availability, performance, etc.)
 *   --metadata=JSON     Additional metadata as JSON string
 */

$baseDir = dirname(__DIR__, 5);
require_once $baseDir . '/vendor/autoload.php';

use App\Models\Alert;
use Illuminate\Support\Facades\DB;

// Parse arguments
$options = getopt('', [
    'type:',
    'title:',
    'message:',
    'source:',
    'source-id:',
    'severity:',
    'resource-type:',
    'resource-id:',
    'alert-type:',
    'metadata:',
]);

// Validate required options
$required = ['type', 'title', 'message'];
foreach ($required as $opt) {
    if (!isset($options[$opt])) {
        fwrite(STDERR, "Error: Missing required option --$opt\n");
        exit(1);
    }
}

// Extract options
$type = $options['type'];
$title = $options['title'];
$message = $options['message'];
$source = $options['source'] ?? 'system';
$sourceId = $options['source-id'] ?? null;
$severity = (int) ($options['severity'] ?? 50);
$resourceType = $options['resource-type'] ?? null;
$resourceId = $options['resource-id'] ?? null;
$alertType = $options['alert-type'] ?? 'general';
$metadata = isset($options['metadata'])
    ? json_decode($options['metadata'], true)
    : [];

// Validate severity
if ($severity < 0 || $severity > 100) {
    fwrite(STDERR, "Error: Severity must be between 0 and 100\n");
    exit(1);
}

// Calculate severity from type if not provided
if (!isset($options['severity'])) {
    $severity = match($type) {
        'critical' => 90,
        'warning' => 70,
        'info' => 30,
        default => 50,
    };
}

// Deduplication check
$existingAlert = null;
if ($resourceType && $resourceId && $alertType) {
    $existingAlert = Alert::where('alert_type', $alertType)
        ->where('resource_type', $resourceType)
        ->where('resource_id', $resourceId)
        ->where('created_at', '>', now()->subMinutes(15))
        ->where('status', '!=', 'resolved')
        ->first();
}

try {
    DB::beginTransaction();

    if ($existingAlert) {
        // Update existing alert instead of creating new
        $existingAlert->update([
            'title' => $title,
            'message' => $message,
            'severity' => max($existingAlert->severity, $severity),
            'metadata' => array_merge($existingAlert->metadata ?? [], $metadata),
            'created_at' => now(),  // Reset timestamp
        ]);

        echo "Updated existing alert: {$existingAlert->id}\n";
        echo "Type: {$existingAlert->type}, Severity: {$existingAlert->severity}\n";

        // Check if should notify
        if ($existingAlert->shouldNotify()) {
            echo "Notification: Would send browser notification\n";
        }
    } else {
        // Create new alert
        $alert = Alert::create([
            'type' => $type,
            'title' => $title,
            'message' => $message,
            'source' => $source,
            'source_id' => $sourceId,
            'severity' => $severity,
            'status' => 'active',
            'resource_type' => $resourceType,
            'resource_id' => $resourceId,
            'alert_type' => $alertType,
            'metadata' => $metadata,
            'auto_resolve_after_hours' => match($alertType) {
                'availability' => 4,
                'performance' => 24,
                'capacity' => 48,
                'deployment' => 24,
                'network' => 4,
                default => 24,
            },
        ]);

        echo "Created alert: {$alert->id}\n";
        echo "Type: {$alert->type}, Severity: {$alert->severity}\n";
        echo "Status: {$alert->status}\n";

        // Check if should notify
        if ($alert->shouldNotify()) {
            echo "Notification: Would send browser notification\n";
        }
    }

    DB::commit();
    exit(0);
} catch (\Exception $e) {
    DB::rollBack();
    fwrite(STDERR, "Error creating alert: {$e->getMessage()}\n");
    exit(1);
}
