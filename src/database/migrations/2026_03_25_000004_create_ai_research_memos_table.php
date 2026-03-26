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
        Schema::create('ai_research_memos', function (Blueprint $table) {
            $table->id();
            $table->foreignId('session_id')->constrained('ai_research_sessions')->cascadeOnDelete();
            $table->string('title');
            $table->text('executive_summary');
            $table->longText('full_content');
            $table->json('key_recommendations')->nullable();
            $table->json('action_items')->nullable();
            $table->json('metrics_predicted')->nullable();
            $table->json('risks_identified')->nullable();
            $table->json('opportunities')->nullable();
            $table->string('priority_level')->default('normal');
            $table->string('status')->default('draft'); // draft, pending_review, approved, rejected, implemented
            $table->timestamp('reviewed_at')->nullable();
            $table->foreignId('reviewed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->text('review_notes')->nullable();
            $table->timestamp('implemented_at')->nullable();
            $table->text('implementation_notes')->nullable();
            $table->json('implementation_results')->nullable();
            $table->timestamps();

            $table->index('status');
            $table->index('priority_level');
            $table->index('created_at');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('ai_research_memos');
    }
};
