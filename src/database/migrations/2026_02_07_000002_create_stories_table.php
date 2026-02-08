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
        Schema::create('stories', function (Blueprint $table) {
            $table->id();
            $table->string('title');
            $table->text('description')->nullable();
            $table->json('acceptance_criteria')->nullable();
            $table->string('user_role')->nullable()->comment('User role for the story');
            $table->integer('story_points')->nullable();
            $table->enum('priority', ['low', 'medium', 'high', 'critical'])->default('medium');
            $table->enum('status', ['backlog', 'refined', 'planned', 'in_progress', 'testing', 'done'])->default('backlog');
            $table->string('epic')->nullable()->comment('Epic identifier');
            $table->foreignId('sprint_id')->nullable()->constrained()->onDelete('set null');
            $table->foreignId('created_by')->constrained('users');
            $table->integer('business_value')->nullable()->default(0)->comment('Business value 0-100');
            $table->integer('complexity')->nullable()->default(0)->comment('Complexity 0-10');
            $table->json('tags')->nullable();
            $table->json('attachments')->nullable();
            $table->timestamp('started_at')->nullable();
            $table->timestamp('completed_at')->nullable();
            $table->timestamps();

            $table->index(['status', 'sprint_id']);
            $table->index(['priority', 'status']);
            $table->index('epic');
            $table->index('business_value');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('stories');
    }
};
