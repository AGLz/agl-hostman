<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Add RBAC Fields to Audit Logs Table
 * AGL Infrastructure Admin Platform - Phase 5
 *
 * Adds:
 * - event_type: Type of event (authentication, authorization, user_management, etc.)
 * - event_category: Specific category within event type
 * - description: Human-readable description of the event
 * - severity: Event severity (info, warning, error, critical)
 * - status: Event status (success, failed, pending)
 */
return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('audit_logs', function (Blueprint $table) {
            // Event classification
            $table->string('event_type', 50)->nullable()->after('action');
            $table->string('event_category', 100)->nullable()->after('event_type');
            $table->text('description')->nullable()->after('event_category');

            // Severity and status tracking
            $table->enum('severity', ['info', 'warning', 'error', 'critical'])
                  ->default('info')
                  ->after('description');

            $table->enum('status', ['success', 'failed', 'pending'])
                  ->default('success')
                  ->after('severity');

            // Indexes for faster querying
            $table->index('event_type');
            $table->index('event_category');
            $table->index('severity');
            $table->index('status');
            $table->index(['event_type', 'status']);
            $table->index(['user_id', 'event_type']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('audit_logs', function (Blueprint $table) {
            // Drop indexes first
            $table->dropIndex(['event_type']);
            $table->dropIndex(['event_category']);
            $table->dropIndex(['severity']);
            $table->dropIndex(['status']);
            $table->dropIndex(['event_type', 'status']);
            $table->dropIndex(['user_id', 'event_type']);

            // Drop columns
            $table->dropColumn([
                'event_type',
                'event_category',
                'description',
                'severity',
                'status',
            ]);
        });
    }
};
