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
        Schema::create('container_migrations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('container_id')
                ->constrained('lxc_containers')
                ->onDelete('cascade')
                ->comment('Reference to LXC container being migrated');

            $table->foreignId('source_server_id')
                ->constrained('proxmox_servers')
                ->comment('Source Proxmox server');

            $table->foreignId('target_server_id')
                ->constrained('proxmox_servers')
                ->comment('Target Proxmox server');

            $table->enum('status', [
                'pending',
                'preparing',
                'syncing',
                'migrating',
                'completing',
                'completed',
                'failed',
            ])->default('pending')
                ->comment('Migration status');

            $table->unsignedTinyInteger('progress')
                ->default(0)
                ->comment('Migration progress (0-100)');

            $table->boolean('online')
                ->default(false)
                ->comment('Online (live) migration flag');

            $table->string('task_id', 100)
                ->nullable()
                ->comment('Proxmox task UPID');

            $table->unsignedInteger('transferred_mb')
                ->nullable()
                ->comment('Data transferred in MB');

            $table->unsignedInteger('total_mb')
                ->nullable()
                ->comment('Total data size in MB');

            $table->unsignedInteger('estimated_seconds')
                ->nullable()
                ->comment('Estimated time remaining in seconds');

            $table->text('error_message')
                ->nullable()
                ->comment('Error message if migration failed');

            $table->json('metadata')
                ->nullable()
                ->comment('Additional migration metadata');

            $table->timestamp('started_at')
                ->nullable()
                ->comment('Migration start timestamp');

            $table->timestamp('completed_at')
                ->nullable()
                ->comment('Migration completion timestamp');

            $table->timestamps();

            // Indexes for performance
            $table->index('container_id');
            $table->index('status');
            $table->index('started_at');
            $table->index(['container_id', 'started_at']);
            $table->index(['source_server_id', 'target_server_id']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('container_migrations');
    }
};
