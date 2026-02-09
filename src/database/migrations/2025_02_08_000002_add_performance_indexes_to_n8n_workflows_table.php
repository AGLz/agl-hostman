<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Add performance indexes to n8n_workflows table
     */
    public function up(): void
    {
        Schema::table('n8n_workflows', function (Blueprint $table) {
            // Active status index
            $table->index('active', 'idx_n8n_workflows_active');

            // Category index (filtering)
            $table->index('category', 'idx_n8n_workflows_category');

            // Execution tracking indexes
            $table->index('last_executed_at', 'idx_n8n_workflows_last_executed');

            // Composite index for active workflows by category
            $table->index(['active', 'category'], 'idx_n8n_active_category');

            // Slug lookup index (URL-based lookups)
            $table->index('slug', 'idx_n8n_workflows_slug');
        });
    }

    /**
     * Reverse the migration
     */
    public function down(): void
    {
        Schema::table('n8n_workflows', function (Blueprint $table) {
            $table->dropIndex('idx_n8n_workflows_active');
            $table->dropIndex('idx_n8n_workflows_category');
            $table->dropIndex('idx_n8n_workflows_last_executed');
            $table->dropIndex('idx_n8n_active_category');
            $table->dropIndex('idx_n8n_workflows_slug');
        });
    }
};
