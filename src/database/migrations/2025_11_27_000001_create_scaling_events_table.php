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
        Schema::create('scaling_events', function (Blueprint $table) {
            $table->id();
            $table->string('action'); // scale_up, scale_down
            $table->integer('old_replicas');
            $table->integer('new_replicas');
            $table->text('trigger'); // Reason for scaling
            $table->json('metadata')->nullable(); // Additional context
            $table->timestamp('created_at');

            $table->index('created_at');
            $table->index('action');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('scaling_events');
    }
};
