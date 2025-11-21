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
        Schema::create('container_health_logs', function (Blueprint $table) {
            $table->id();
            $table->string('node_code')->comment('Proxmox node code');
            $table->string('vmid')->comment('Container VMID');
            $table->string('container_name');
            $table->enum('health_status', ['healthy', 'warning', 'critical', 'stopped'])->default('healthy');
            $table->decimal('cpu_usage_percent', 5, 2)->default(0);
            $table->decimal('memory_usage_percent', 5, 2)->default(0);
            $table->decimal('disk_usage_percent', 5, 2)->default(0);
            $table->integer('uptime_seconds')->nullable();
            $table->json('issues')->nullable()->comment('Array of detected issues');
            $table->json('metrics')->nullable()->comment('Additional metrics snapshot');
            $table->timestamps();

            // Indexes for efficient querying
            $table->index(['node_code', 'vmid'], 'container_health_logs_node_vmid_index');
            $table->index('health_status', 'container_health_logs_health_status_index');
            $table->index('created_at', 'container_health_logs_created_at_index');
            $table->index(['node_code', 'vmid', 'created_at'], 'container_health_logs_timeseries_index');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('container_health_logs');
    }
};
