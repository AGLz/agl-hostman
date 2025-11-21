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
        Schema::create('container_snapshots', function (Blueprint $table) {
            $table->id();
            $table->foreignId('container_id')
                ->constrained('lxc_containers')
                ->onDelete('cascade')
                ->comment('Reference to LXC container');

            $table->string('name', 40)
                ->comment('Snapshot name (alphanumeric, hyphens, underscores)');

            $table->text('description')
                ->nullable()
                ->comment('Snapshot description');

            $table->unsignedInteger('size_mb')
                ->nullable()
                ->comment('Snapshot size in MB');

            $table->string('parent_name', 40)
                ->nullable()
                ->comment('Parent snapshot name (for snapshot chains)');

            $table->json('config')
                ->nullable()
                ->comment('Container configuration at snapshot time');

            $table->json('metadata')
                ->nullable()
                ->comment('Additional snapshot metadata');

            $table->timestamps();
            $table->softDeletes();

            // Unique constraint on container + snapshot name
            $table->unique(['container_id', 'name'], 'unique_container_snapshot');

            // Indexes for performance
            $table->index('container_id');
            $table->index('name');
            $table->index('created_at');
            $table->index(['container_id', 'created_at']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('container_snapshots');
    }
};
