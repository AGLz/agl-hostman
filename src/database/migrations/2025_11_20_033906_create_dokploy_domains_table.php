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
        Schema::create('dokploy_domains', function (Blueprint $table) {
            $table->id();
            $table->foreignId('application_id')->constrained('dokploy_applications')->cascadeOnDelete();
            $table->string('dokploy_id')->unique()->index()->comment('External Dokploy domain ID');
            $table->string('host')->comment('Domain hostname');
            $table->boolean('https')->default(false)->comment('Enable HTTPS');
            $table->string('certificate_type')->default('none')->comment('Certificate type: letsencrypt, none, custom');
            $table->boolean('strip_path')->default(false)->comment('Strip path prefix');
            $table->string('path')->nullable()->comment('URL path');
            $table->integer('port')->nullable()->comment('Port number');
            $table->string('service_name')->nullable()->comment('Service name for compose');
            $table->string('custom_cert_resolver')->nullable()->comment('Custom certificate resolver');
            $table->string('internal_path')->nullable()->comment('Internal routing path');
            $table->string('domain_type')->default('application')->comment('Domain type: compose, application, preview');
            $table->string('status')->default('active')->comment('Status: active, inactive, pending');
            $table->json('metadata')->nullable()->comment('Additional domain configuration');
            $table->timestamps();
            $table->softDeletes();

            // Indexes for performance
            $table->index('host');
            $table->index('status');
            $table->index(['application_id', 'status']);
            $table->unique(['application_id', 'host'], 'unique_app_host');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('dokploy_domains');
    }
};
