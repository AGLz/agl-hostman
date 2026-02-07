<?php

declare(strict_types=1);

use App\Models\AIModelUsage;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Create AI Model Usage Table Migration
 *
 * Creates table for tracking AI model API usage statistics
 */
return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('ai_model_usage', function (Blueprint $table) {
            $table->id();
            $table->uuid()->unique();

            // User tracking
            $table->unsignedBigInteger('user_id')->nullable()->index();
            $table->foreign('user_id')->references('id')->on('users')->nullOnDelete();

            // Provider and model information
            $table->string('provider', 50)->index(); // openai, claude, ollama
            $table->string('model', 100)->index(); // gpt-4-turbo, claude-3-opus, etc.

            // Request information
            $table->string('task_type', 50)->index(); // prediction, analysis, chat, etc.
            $table->string('status', 20)->default('success'); // success, error

            // Token usage
            $table->unsignedInteger('prompt_tokens')->default(0);
            $table->unsignedInteger('completion_tokens')->default(0);
            $table->unsignedInteger('total_tokens')->default(0);

            // Cost tracking
            $table->decimal('estimated_cost', 10, 4)->default(0);

            // Performance metrics
            $table->unsignedInteger('response_time_ms')->nullable();

            // Error tracking
            $table->text('error_message')->nullable();

            // Additional metadata
            $table->json('metadata')->nullable();

            // Timestamps
            $table->timestamp('created_at')->index();

            // Composite indexes for common queries
            $table->index(['provider', 'model'], 'provider_model_index');
            $table->index(['task_type', 'created_at'], 'task_type_created_index');
            $table->index(['user_id', 'created_at'], 'user_usage_index');
            $table->index(['status', 'created_at'], 'status_created_index');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('ai_model_usage');
    }
};
