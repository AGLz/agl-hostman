<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('promotions', function (Blueprint $table) {
            // Workflow fields
            $table->json('approved_by')->nullable()->after('approved_at');
            $table->timestamp('rolled_back_at')->nullable()->after('completed_at');
            $table->text('rollback_reason')->nullable()->after('rolled_back_at');
            $table->boolean('is_automatic')->default(false)->after('rollback_reason');
            $table->integer('requires_approvals')->default(1)->after('is_automatic');
            $table->json('deployment_logs')->nullable()->after('smoke_test_results');
            $table->timestamp('approval_deadline')->nullable()->after('approved_at');
            
            // Update status enum to include new statuses
            $table->string('status')->default('pending_approval')->change();
        });
        
        // Add indexes for performance
        Schema::table('promotions', function (Blueprint $table) {
            $table->index('status');
            $table->index('is_automatic');
            $table->index(['source_environment_id', 'status']);
            $table->index(['target_environment_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::table('promotions', function (Blueprint $table) {
            $table->dropColumn([
                'approved_by',
                'rolled_back_at',
                'rollback_reason',
                'is_automatic',
                'requires_approvals',
                'deployment_logs',
                'approval_deadline',
            ]);
        });
    }
};
