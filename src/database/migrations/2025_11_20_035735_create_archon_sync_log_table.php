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
        Schema::create('archon_sync_log', function (Blueprint $table) {
            $table->id();
            $table->string('entity_type'); // 'project', 'task', 'document'
            $table->string('entity_id');
            $table->string('action'); // 'create', 'update', 'delete', 'sync'
            $table->string('direction'); // 'push' (to Archon), 'pull' (from Archon)
            $table->string('status'); // 'success', 'failed', 'pending'
            $table->text('error_message')->nullable();
            $table->json('metadata')->nullable();
            $table->timestamp('synced_at');
            $table->timestamps();

            $table->index(['entity_type', 'entity_id']);
            $table->index('status');
            $table->index('synced_at');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('archon_sync_log');
    }
};
