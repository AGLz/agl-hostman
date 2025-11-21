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
        Schema::create('promotions', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignId('source_environment_id')->constrained('environments')->onDelete('cascade');
            $table->foreignId('target_environment_id')->constrained('environments')->onDelete('cascade');
            $table->string('source_version'); // Docker tag or commit SHA
            $table->string('target_version')->nullable();
            $table->enum('status', ['pending', 'approved', 'rejected', 'completed', 'failed'])->default('pending');
            $table->foreignId('requested_by')->nullable()->constrained('users')->onDelete('set null');
            $table->foreignId('approved_by')->nullable()->constrained('users')->onDelete('set null');
            $table->timestamp('requested_at');
            $table->timestamp('approved_at')->nullable();
            $table->timestamp('completed_at')->nullable();
            $table->text('approval_notes')->nullable();
            $table->json('smoke_test_results')->nullable();
            $table->timestamps();

            // Indexes for performance
            $table->index('status');
            $table->index('source_environment_id');
            $table->index('target_environment_id');
            $table->index(['source_environment_id', 'target_environment_id']);
            $table->index('requested_at');
            $table->index('completed_at');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('promotions');
    }
};
