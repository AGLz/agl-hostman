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
        Schema::create('dokploy_applications', function (Blueprint $table) {
            $table->id();
            $table->foreignId('project_id')->constrained('dokploy_projects')->cascadeOnDelete();
            $table->string('dokploy_id')->unique()->index()->comment('External Dokploy application ID');
            $table->string('name')->comment('Application name');
            $table->string('app_name')->comment('Application internal name');
            $table->text('description')->nullable()->comment('Application description');
            $table->string('environment_id')->nullable()->comment('Environment ID in Dokploy');
            $table->string('server_id')->nullable()->comment('Server ID in Dokploy');
            $table->string('docker_image')->nullable()->comment('Docker image name');
            $table->string('source_type')->nullable()->comment('Source type: github, docker, git, etc');
            $table->string('build_type')->nullable()->comment('Build type: dockerfile, nixpacks, etc');
            $table->string('status')->default('idle')->comment('Status: idle, running, done, error');
            $table->text('env')->nullable()->comment('Environment variables');
            $table->text('build_args')->nullable()->comment('Build arguments');
            $table->integer('cpu_limit')->nullable()->comment('CPU limit');
            $table->integer('memory_limit')->nullable()->comment('Memory limit in MB');
            $table->integer('replicas')->default(1)->comment('Number of replicas');
            $table->boolean('auto_deploy')->default(false)->comment('Auto-deploy on push');
            $table->json('metadata')->nullable()->comment('Additional configuration');
            $table->timestamp('last_deployed_at')->nullable()->comment('Last deployment timestamp');
            $table->timestamps();
            $table->softDeletes();

            // Indexes for performance
            $table->index('status');
            $table->index('environment_id');
            $table->index('last_deployed_at');
            $table->index(['project_id', 'status']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('dokploy_applications');
    }
};
