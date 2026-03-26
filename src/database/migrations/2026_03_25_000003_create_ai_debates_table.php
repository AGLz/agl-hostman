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
        Schema::create('ai_debates', function (Blueprint $table) {
            $table->id();
            $table->foreignId('session_id')->constrained('ai_research_sessions')->cascadeOnDelete();
            $table->integer('round_number');
            $table->string('topic')->nullable();
            $table->text('context')->nullable();
            $table->string('status')->default('pending'); // pending, active, completed
            $table->timestamp('started_at')->nullable();
            $table->timestamp('completed_at')->nullable();
            $table->timestamps();

            $table->index(['session_id', 'round_number']);
            $table->index('status');
        });

        Schema::create('ai_debate_arguments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('debate_id')->constrained('ai_debates')->cascadeOnDelete();
            $table->foreignId('idea_id')->nullable()->constrained('ai_ideas')->nullOnDelete();
            $table->string('model_role');
            $table->string('model_name');
            $table->enum('stance', ['support', 'oppose', 'neutral', 'refine']);
            $table->text('argument');
            $table->json('evidence')->nullable();
            $table->json('counter_arguments')->nullable();
            $table->integer('persuasion_score')->default(0);
            $table->timestamps();

            $table->index(['debate_id', 'model_role']);
            $table->index('stance');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('ai_debate_arguments');
        Schema::dropIfExists('ai_debates');
    }
};
