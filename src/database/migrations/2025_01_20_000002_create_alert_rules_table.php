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
        Schema::create('alert_rules', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('name');
            $table->text('description')->nullable();
            $table->enum('rule_type', ['threshold', 'pattern', 'anomaly'])->default('threshold');
            $table->json('conditions'); // Rule conditions (thresholds, patterns, etc.)
            $table->json('actions'); // Actions to take (create alert, send notification, etc.)
            $table->boolean('enabled')->default(true);
            $table->integer('cooldown_minutes')->default(15); // Prevent alert spam
            $table->timestamp('last_triggered_at')->nullable();
            $table->integer('trigger_count')->default(0);
            $table->timestamps();

            // Indexes
            $table->index('enabled');
            $table->index('rule_type');
            $table->index('last_triggered_at');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('alert_rules');
    }
};
