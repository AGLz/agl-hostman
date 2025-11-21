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
        Schema::create('environments', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->enum('type', ['dev', 'qa', 'uat', 'production']);
            $table->string('dokploy_project_id')->nullable()->index();
            $table->string('harbor_project');
            $table->string('git_branch');
            $table->boolean('auto_deploy')->default(false);
            $table->boolean('auto_test')->default(false);
            $table->enum('status', ['active', 'inactive', 'maintenance'])->default('active');
            $table->json('domains'); // Array of domain names
            $table->json('env_vars'); // Environment variables
            $table->json('resources'); // CPU and memory limits
            $table->timestamp('last_deployed_at')->nullable();
            $table->timestamps();

            // Unique constraint - only one environment per type
            $table->unique('type');

            // Index for quick lookups
            $table->index(['type', 'status']);
            $table->index('status');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('environments');
    }
};
