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
        Schema::create('production_deployments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('environment_id')->constrained('environments')->cascadeOnDelete();
            $table->enum('deployment_type', ['blue_green', 'rolling', 'canary'])->default('blue_green');
            $table->enum('active_slot', ['blue', 'green'])->default('blue');
            $table->string('blue_version')->nullable();
            $table->string('green_version')->nullable();
            $table->integer('active_replicas')->default(2);
            $table->integer('desired_replicas')->default(2);
            $table->json('health_status')->nullable();
            $table->json('performance_metrics')->nullable();
            $table->json('load_balancer_config')->nullable();
            $table->timestamp('last_deployment_at')->nullable();
            $table->timestamp('last_rollback_at')->nullable();
            $table->timestamp('last_traffic_switch_at')->nullable();
            $table->timestamps();

            $table->index(['environment_id', 'active_slot']);
            $table->index('last_deployment_at');
        });

        Schema::create('production_approvals', function (Blueprint $table) {
            $table->id();
            $table->foreignId('environment_id')->constrained('environments')->cascadeOnDelete();
            $table->string('deployment_version');
            $table->enum('approval_level', ['first', 'second'])->default('first');
            $table->string('approver_role')->comment('lead-developer or admin');
            $table->foreignId('approved_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('approved_at')->nullable();
            $table->text('approval_notes')->nullable();
            $table->enum('status', ['pending', 'approved', 'rejected', 'expired'])->default('pending');
            $table->timestamp('expires_at')->nullable();
            $table->timestamps();

            $table->index(['environment_id', 'status']);
            $table->index('approved_at');
        });

        Schema::create('production_backup_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('environment_id')->constrained('environments')->cascadeOnDelete();
            $table->enum('backup_type', ['full', 'incremental', 'differential'])->default('full');
            $table->string('backup_file')->nullable();
            $table->string('storage_location')->nullable();
            $table->bigInteger('file_size_bytes')->nullable();
            $table->enum('status', ['pending', 'running', 'completed', 'failed'])->default('pending');
            $table->integer('duration_seconds')->nullable();
            $table->timestamp('started_at')->nullable();
            $table->timestamp('completed_at')->nullable();
            $table->text('error_message')->nullable();
            $table->json('backup_metadata')->nullable();
            $table->timestamps();

            $table->index(['environment_id', 'status']);
            $table->index('completed_at');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('production_backup_logs');
        Schema::dropIfExists('production_approvals');
        Schema::dropIfExists('production_deployments');
    }
};
