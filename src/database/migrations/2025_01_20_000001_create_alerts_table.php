<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('alerts', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->enum('type', ['critical', 'warning', 'info'])->default('info');
            $table->string('title');
            $table->text('message');
            $table->enum('source', ['server', 'container', 'network', 'storage', 'system'])->default('system');
            $table->string('source_id')->nullable(); // VMID, server code, network peer, etc.
            $table->integer('severity')->default(0); // 0-100 scale
            $table->enum('status', ['active', 'acknowledged', 'resolved'])->default('active');
            $table->uuid('acknowledged_by')->nullable(); // User ID who acknowledged
            $table->timestamp('acknowledged_at')->nullable();
            $table->uuid('resolved_by')->nullable(); // User ID who resolved
            $table->timestamp('resolved_at')->nullable();
            $table->json('metadata')->nullable(); // Additional context (metrics, thresholds, etc.)
            $table->timestamp('muted_until')->nullable(); // Temporary mute

            // Polymorphic relationship fields
            $table->string('resource_type')->nullable();
            $table->string('resource_id')->nullable();

            // Additional fields for test compatibility
            $table->string('alert_type')->nullable();
            $table->boolean('is_resolved')->default(false);
            $table->text('resolution_notes')->nullable();
            $table->integer('auto_resolve_after_hours')->nullable();

            $table->timestamps();

            // Indexes for efficient querying
            $table->index(['status', 'type', 'created_at']); // Most common query pattern
            $table->index(['source', 'source_id']);
            $table->index(['resource_type', 'resource_id']); // Polymorphic index
            $table->index('created_at');
            $table->index('severity');
            $table->index('is_resolved');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('alerts');
    }
};
