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
        Schema::create('harbor_repositories', function (Blueprint $table) {
            $table->id();
            $table->foreignId('project_id')->constrained('harbor_projects')->cascadeOnDelete();
            $table->string('harbor_id')->nullable()->comment('External Harbor repository ID');
            $table->string('name')->comment('Repository name');
            $table->string('project_name')->comment('Project name for full path');
            $table->text('description')->nullable()->comment('Repository description');
            $table->integer('pull_count')->default(0)->comment('Total pull count');
            $table->integer('artifact_count')->default(0)->comment('Number of artifacts');
            $table->bigInteger('artifact_size_bytes')->default(0)->comment('Total size in bytes');
            $table->timestamp('last_push_at')->nullable()->comment('Last push timestamp');
            $table->json('metadata')->nullable()->comment('Additional metadata');
            $table->timestamps();
            $table->softDeletes();

            // Unique constraint on project + name
            $table->unique(['project_id', 'name']);

            // Indexes for performance
            $table->index('name');
            $table->index('project_name');
            $table->index('last_push_at');
            $table->index('pull_count');
            $table->index(['project_id', 'artifact_count']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('harbor_repositories');
    }
};
