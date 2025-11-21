<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * Create lxc_containers table for Proxmox LXC container tracking
     * Based on IMPLEMENTATION-SUMMARY.md Phase 2 recommendations
     */
    public function up(): void
    {
        Schema::create('lxc_containers', function (Blueprint $table) {
            $table->id();

            // Server relationship
            $table->foreignId('proxmox_server_id')
                ->constrained('proxmox_servers')
                ->cascadeOnDelete()
                ->comment('Parent Proxmox server');

            // Container identification
            $table->string('vmid')->comment('Proxmox VMID (e.g., 179, 180, 183)');
            $table->string('name')->comment('Container name (e.g., agldv03, archon)');
            $table->string('hostname')->nullable()->comment('Container hostname/FQDN');

            // Container configuration
            $table->enum('status', ['running', 'stopped', 'paused', 'suspended'])
                ->default('stopped')
                ->comment('Current container status');
            $table->string('os_template')->nullable()->comment('OS template used (e.g., ubuntu-22.04)');
            $table->integer('cores')->default(1)->comment('CPU cores allocated');
            $table->integer('memory_mb')->default(512)->comment('Memory in megabytes');
            $table->integer('disk_gb')->default(8)->comment('Disk size in gigabytes');

            // Network configuration
            $table->json('network_config')->nullable()->comment('Network interfaces configuration');

            // Container metadata
            $table->json('metadata')->nullable()->comment('Additional container metadata (tags, notes, etc.)');
            $table->text('description')->nullable()->comment('Container description');

            // Container flags
            $table->boolean('is_template')->default(false)->comment('Is this a template container');
            $table->boolean('auto_start')->default(false)->comment('Auto-start on host boot');

            // Status tracking
            $table->timestamp('started_at')->nullable()->comment('Last start timestamp');
            $table->timestamp('stopped_at')->nullable()->comment('Last stop timestamp');

            // Timestamps
            $table->timestamps();
            $table->softDeletes();

            // Indexes
            $table->unique(['proxmox_server_id', 'vmid'], 'lxc_containers_server_vmid_unique');
            $table->index('name', 'lxc_containers_name_index');
            $table->index('status', 'lxc_containers_status_index');
            $table->index('is_template', 'lxc_containers_template_index');
            $table->index('started_at', 'lxc_containers_started_index');

            // Combined index for common queries
            $table->index(['proxmox_server_id', 'status'], 'lxc_containers_server_status_index');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('lxc_containers');
    }
};
