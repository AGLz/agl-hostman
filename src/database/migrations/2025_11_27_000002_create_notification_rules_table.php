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
        Schema::create('notification_rules', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->text('description')->nullable();
            $table->json('conditions'); // Rule conditions (severity, source, time window, etc.)
            $table->enum('action', ['route', 'suppress', 'escalate', 'group'])->index();
            $table->json('config'); // Action-specific configuration (channels, escalation policy, etc.)
            $table->integer('priority')->default(0); // Higher priority rules are evaluated first
            $table->boolean('enabled')->default(true)->index();
            $table->timestamp('last_triggered_at')->nullable();
            $table->integer('trigger_count')->default(0);
            $table->timestamps();
            $table->softDeletes();

            // Indexes for performance
            $table->index(['action', 'enabled']);
            $table->index('priority');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('notification_rules');
    }
};
