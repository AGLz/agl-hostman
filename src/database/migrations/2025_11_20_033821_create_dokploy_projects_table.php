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
        Schema::create('dokploy_projects', function (Blueprint $table) {
            $table->id();
            $table->string('dokploy_id')->unique()->index()->comment('External Dokploy project ID');
            $table->string('name')->comment('Project name');
            $table->text('description')->nullable()->comment('Project description');
            $table->string('organization_id')->nullable()->comment('Organization ID in Dokploy');
            $table->text('env')->nullable()->comment('Environment variables');
            $table->json('metadata')->nullable()->comment('Additional configuration');
            $table->string('status')->default('active')->comment('Project status: active, inactive, archived');
            $table->timestamps();
            $table->softDeletes();

            // Indexes for performance
            $table->index('status');
            $table->index('created_at');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('dokploy_projects');
    }
};
