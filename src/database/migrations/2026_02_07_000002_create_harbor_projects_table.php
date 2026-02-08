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
        Schema::create('harbor_projects', function (Blueprint $table) {
            $table->id();
            $table->string('harbor_id')->unique()->index()->comment('External Harbor project ID');
            $table->string('name')->unique()->comment('Project name');
            $table->boolean('public')->default(false)->comment('Public accessibility');
            $table->string('owner_id')->nullable()->comment('Owner user ID in Harbor');
            $table->string('owner_name')->nullable()->comment('Owner username');
            $table->json('metadata')->nullable()->comment('Additional project metadata');
            $table->json('cve_allowlist')->nullable()->comment('CVE allowlist configuration');
            $table->boolean('prevent_vul')->default(false)->comment('Prevent vulnerable images');
            $table->string('severity')->default('medium')->comment('Minimum vulnerability severity');
            $table->boolean('auto_scan')->default(true)->comment('Auto-scan on push');
            $table->boolean('enable_content_trust')->default(false)->comment('Enable content trust');
            $table->boolean('enable_content_trust_ci')->default(false)->comment('Enable content trust CI');
            $table->bigInteger('storage_quota')->nullable()->comment('Storage quota in bytes');
            $table->bigInteger('storage_used')->default(0)->comment('Storage used in bytes');
            $table->string('registry_id')->nullable()->comment('Associated registry ID');
            $table->timestamps();
            $table->softDeletes();

            // Indexes for performance
            $table->index('public');
            $table->index('owner_id');
            $table->index(['public', 'auto_scan']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('harbor_projects');
    }
};
