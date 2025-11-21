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
        Schema::create('performance_trends', function (Blueprint $table) {
            $table->id();
            $table->string('metric_type')->comment('cluster_health, container_performance, resource_usage');
            $table->string('metric_name');
            $table->string('node_code')->nullable();
            $table->string('vmid')->nullable();
            $table->decimal('value', 10, 2);
            $table->json('metadata')->nullable()->comment('Additional context data');
            $table->timestamp('recorded_at');
            $table->timestamps();

            // Indexes for time-series queries
            $table->index('metric_type', 'performance_trends_metric_type_index');
            $table->index(['metric_type', 'metric_name'], 'performance_trends_metric_index');
            $table->index('recorded_at', 'performance_trends_recorded_at_index');
            $table->index(['node_code', 'vmid', 'recorded_at'], 'performance_trends_container_timeseries_index');
            $table->index(['metric_type', 'recorded_at'], 'performance_trends_type_timeseries_index');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('performance_trends');
    }
};
