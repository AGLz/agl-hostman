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
        Schema::create('dokploy_deployments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('application_id')->constrained('dokploy_applications')->cascadeOnDelete();
            $table->string('dokploy_id')->nullable()->index()->comment('External Dokploy deployment ID');
            $table->string('status')->default('pending')->comment('Status: pending, building, deploying, success, failed');
            $table->string('title')->nullable()->comment('Deployment title');
            $table->text('description')->nullable()->comment('Deployment description');
            $table->string('commit_hash')->nullable()->comment('Git commit hash');
            $table->string('branch')->nullable()->comment('Git branch');
            $table->string('tag')->nullable()->comment('Git tag');
            $table->string('triggered_by')->nullable()->comment('Who triggered deployment');
            $table->text('error_message')->nullable()->comment('Error message if failed');
            $table->json('metadata')->nullable()->comment('Additional deployment metadata');
            $table->timestamp('started_at')->nullable()->comment('Deployment start time');
            $table->timestamp('completed_at')->nullable()->comment('Deployment completion time');
            $table->integer('duration_seconds')->nullable()->comment('Deployment duration');
            $table->timestamps();

            // Indexes for performance
            $table->index('status');
            $table->index('started_at');
            $table->index('completed_at');
            $table->index(['application_id', 'status']);
            $table->index(['application_id', 'created_at']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('dokploy_deployments');
    }
};
