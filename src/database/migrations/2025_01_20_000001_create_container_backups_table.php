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
        Schema::create('container_backups', function (Blueprint $table) {
            $table->id();
            $table->foreignId('container_id')
                ->constrained('lxc_containers')
                ->onDelete('cascade')
                ->comment('Reference to LXC container');

            $table->string('storage', 100)
                ->comment('Proxmox storage name (e.g., local, fgsrv6-wg)');

            $table->string('filename')
                ->unique()
                ->comment('Backup filename (e.g., vzdump-lxc-179-2025_01_20-10_30_45.tar.zst)');

            $table->unsignedInteger('size_mb')
                ->nullable()
                ->comment('Backup file size in MB');

            $table->enum('mode', ['snapshot', 'suspend', 'stop'])
                ->default('snapshot')
                ->comment('Backup mode used');

            $table->enum('compress', ['0', 'lzo', 'gzip', 'zstd'])
                ->default('zstd')
                ->comment('Compression algorithm used');

            $table->enum('status', ['pending', 'running', 'completed', 'failed'])
                ->default('pending')
                ->comment('Backup job status');

            $table->string('task_id', 100)
                ->nullable()
                ->comment('Proxmox task UPID');

            $table->text('notes')
                ->nullable()
                ->comment('User notes about this backup');

            $table->json('metadata')
                ->nullable()
                ->comment('Additional backup metadata');

            $table->timestamp('completed_at')
                ->nullable()
                ->comment('Backup completion timestamp');

            $table->timestamps();
            $table->softDeletes();

            // Indexes for performance
            $table->index('container_id');
            $table->index('status');
            $table->index('created_at');
            $table->index(['container_id', 'created_at']);
            $table->index(['storage', 'filename']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('container_backups');
    }
};
