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
        Schema::create('ai_ideas', function (Blueprint $table) {
            $table->id();
            $table->foreignId('session_id')->constrained('ai_research_sessions')->cascadeOnDelete();
            $table->string('model_role'); // visionary, analyst, architect, product, revenue
            $table->string('model_name'); // claude-opus, gpt-4.1, gemini-pro, r1, kimi-think
            $table->string('title');
            $table->text('description');
            $table->text('rationale')->nullable();
            $table->string('category')->nullable(); // innovation, optimization, revenue, tech_debt, feature
            $table->string('impact_level')->default('medium'); // low, medium, high, critical
            $table->string('effort_level')->default('medium'); // low, medium, high
            $table->string('priority')->default('normal'); // low, normal, high, urgent
            $table->json('tags')->nullable();
            $table->json('metadata')->nullable();
            $table->integer('votes_for')->default(0);
            $table->integer('votes_against')->default(0);
            $table->decimal('consensus_score', 5, 2)->default(0);
            $table->boolean('included_in_memo')->default(false);
            $table->timestamps();

            $table->index(['session_id', 'model_role']);
            $table->index('category');
            $table->index('impact_level');
            $table->index('consensus_score');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('ai_ideas');
    }
};
