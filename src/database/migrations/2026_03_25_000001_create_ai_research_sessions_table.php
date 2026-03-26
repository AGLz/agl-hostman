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
        Schema::create('ai_research_sessions', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->text('description')->nullable();
            $table->string('trigger_type')->default('manual'); // manual, scheduled, webhook
            $table->string('status')->default('pending'); // pending, analyzing, debating, consolidating, completed, failed
            $table->string('context_type')->nullable(); // project, codebase, market, revenue, all
            $table->json('context_data')->nullable();
            $table->json('config')->nullable(); // debate_rounds, ideas_per_model, etc.
            $table->timestamp('started_at')->nullable();
            $table->timestamp('completed_at')->nullable();
            $table->integer('debate_rounds_completed')->default(0);
            $table->integer('total_ideas_generated')->default(0);
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();

            $table->index('status');
            $table->index('trigger_type');
            $table->index('created_at');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('ai_research_sessions');
    }
};
