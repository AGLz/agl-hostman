<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Add performance indexes to alerts table
     */
    public function up(): void
    {
        Schema::table('alerts', function (Blueprint $table) {
            // Status and resolution indexes (most common queries)
            $table->index(['status', 'resolved_at'], 'idx_alerts_status_resolved');
            $table->index('status', 'idx_alerts_status');
            $table->index('is_resolved', 'idx_alerts_is_resolved');

            // Severity index (filtering by priority)
            $table->index('severity', 'idx_alerts_severity');

            // Timestamp indexes (sorting and recent queries)
            $table->index('created_at', 'idx_alerts_created_at');
            $table->index('resolved_at', 'idx_alerts_resolved_at');
            $table->index('acknowledged_at', 'idx_alerts_acknowledged_at');

            // Source indexes (filtering by source)
            $table->index('source', 'idx_alerts_source');

            // Composite index for active alerts (common query)
            $table->index(['status', 'muted_until'], 'idx_alerts_status_muted');

            // Alert type index
            $table->index('alert_type', 'idx_alerts_type');
        });
    }

    /**
     * Reverse the migration
     */
    public function down(): void
    {
        Schema::table('alerts', function (Blueprint $table) {
            $table->dropIndex('idx_alerts_status_resolved');
            $table->dropIndex('idx_alerts_status');
            $table->dropIndex('idx_alerts_is_resolved');
            $table->dropIndex('idx_alerts_severity');
            $table->dropIndex('idx_alerts_created_at');
            $table->dropIndex('idx_alerts_resolved_at');
            $table->dropIndex('idx_alerts_acknowledged_at');
            $table->dropIndex('idx_alerts_source');
            $table->dropIndex('idx_alerts_status_muted');
            $table->dropIndex('idx_alerts_type');
        });
    }
};
