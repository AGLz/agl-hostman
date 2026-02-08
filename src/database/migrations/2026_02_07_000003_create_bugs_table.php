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
        Schema::create('bugs', function (Blueprint $table) {
            $table->id();
            $table->string('title');
            $table->text('description')->nullable();
            $table->enum('severity', ['trivial', 'low', 'medium', 'high', 'critical', 'blocker'])->default('medium');
            $table->enum('priority', ['low', 'medium', 'high', 'critical'])->default('medium');
            $table->enum('status', ['open', 'assigned', 'in_progress', 'resolved', 'verified', 'closed'])->default('open');
            $table->json('reproduction_steps')->nullable();
            $table->text('expected_behavior')->nullable();
            $table->text('actual_behavior')->nullable();
            $table->string('environment')->nullable()->comment('Environment where bug was found');
            $table->foreignId('sprint_id')->nullable()->constrained()->onDelete('set null');
            $table->foreignId('story_id')->nullable()->constrained()->onDelete('set null');
            $table->foreignId('task_id')->nullable()->constrained()->onDelete('set null');
            $table->foreignId('reported_by')->constrained('users');
            $table->foreignId('assigned_to')->nullable()->constrained('users')->onDelete('set null');
            $table->string('found_in_version')->nullable();
            $table->string('resolved_in_version')->nullable();
            $table->json('labels')->nullable();
            $table->json('attachments')->nullable();
            $table->timestamp('reported_at')->useCurrent();
            $table->timestamp('resolved_at')->nullable();
            $table->timestamp('verified_at')->nullable();
            $table->timestamps();

            $table->index(['status', 'severity']);
            $table->index(['priority', 'status']);
            $table->index(['sprint_id', 'status']);
            $table->index(['assigned_to', 'status']);
            $table->index('reported_at');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('bugs');
    }
};
