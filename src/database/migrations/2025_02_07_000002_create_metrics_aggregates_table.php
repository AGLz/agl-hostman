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
        Schema::create('metrics_aggregates', function (Blueprint $table) {
            $table->id();
            $table->timestamp('timestamp');
            $table->integer('total_servers');
            $table->decimal('avg_cpu_usage', 5, 2);
            $table->decimal('avg_memory_usage', 5, 2);
            $table->decimal('avg_disk_usage', 5, 2);
            $table->integer('containers_running');
            $table->integer('containers_stopped');
            $table->json('details')->nullable();
            $table->timestamps();

            $table->index('timestamp');
        });

        // Create job_performance_metrics table
        Schema::create('job_performance_metrics', function (Blueprint $table) {
            $table->id();
            $table->string('job_type');
            $table->string('queue');
            $table->timestamp('started_at');
            $table->timestamp('completed_at');
            $table->decimal('duration', 10, 2);
            $table->string('status'); // completed, failed, retried
            $table->integer('attempt');
            $table->json('metadata')->nullable();
            $table->timestamps();

            $table->index(['job_type', 'queue']);
            $table->index('started_at');
            $table->index('status');
        });

        // Create queue_health_snapshots table
        Schema::create('queue_health_snapshots', function (Blueprint $table) {
            $table->id();
            $table->string('queue');
            $table->integer('pending_jobs');
            $table->integer('processing_jobs');
            $table->integer('failed_jobs');
            $table->integer('completed_jobs');
            $table->decimal('avg_wait_time', 10, 2)->nullable();
            $table->timestamp('snapshot_at');
            $table->timestamps();

            $table->index('queue');
            $table->index('snapshot_at');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('queue_health_snapshots');
        Schema::dropIfExists('job_performance_metrics');
        Schema::dropIfExists('metrics_aggregates');
    }
};
