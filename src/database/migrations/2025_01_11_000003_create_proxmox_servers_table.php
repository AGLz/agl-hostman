<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * Create proxmox_servers table for Proxmox VE host server tracking
     * Based on IMPLEMENTATION-SUMMARY.md Phase 2 recommendations
     */
    public function up(): void
    {
        Schema::create('proxmox_servers', function (Blueprint $table) {
            $table->id();

            // Server identification
            $table->string('name')->comment('Server hostname (e.g., AGLSRV1)');
            $table->string('code')->unique()->comment('Unique server code (e.g., AGLSRV1)');

            // Connection details
            $table->string('ip_address')->comment('Primary IP address for API connection');
            $table->integer('port')->default(8006)->comment('Proxmox API port');
            $table->string('username')->default('root@pam')->comment('API authentication username');
            $table->text('password')->nullable()->comment('Encrypted API password');
            $table->string('realm')->default('pam')->comment('Authentication realm (pam, pve, etc.)');
            $table->boolean('verify_ssl')->default(false)->comment('SSL certificate verification');

            // Relationships
            $table->foreignId('physical_location_id')
                ->nullable()
                ->constrained('physical_locations')
                ->nullOnDelete()
                ->comment('Physical datacenter location');

            // Status tracking
            $table->enum('status', ['online', 'offline', 'maintenance', 'degraded'])
                ->default('offline')
                ->comment('Current server status');
            $table->timestamp('last_seen_at')->nullable()->comment('Last successful API connection');

            // Metadata
            $table->json('metadata')->nullable()->comment('Additional server metadata (versions, capabilities, etc.)');

            // Timestamps
            $table->timestamps();
            $table->softDeletes();

            // Indexes
            $table->index('code', 'proxmox_servers_code_index');
            $table->index('ip_address', 'proxmox_servers_ip_index');
            $table->index('status', 'proxmox_servers_status_index');
            $table->index('physical_location_id', 'proxmox_servers_location_index');
            $table->index('last_seen_at', 'proxmox_servers_last_seen_index');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('proxmox_servers');
    }
};
