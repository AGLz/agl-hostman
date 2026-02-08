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
        Schema::create('harbor_artifacts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('repository_id')->constrained('harbor_repositories')->cascadeOnDelete();
            $table->string('harbor_id')->nullable()->comment('External Harbor artifact ID');
            $table->string('digest')->comment('Artifact digest/SHA');
            $table->string('tag')->nullable()->comment('Artifact tag');
            $table->string('manifest_media_type')->nullable()->comment('Manifest media type');
            $table->string('config_media_type')->nullable()->comment('Config media type');
            $table->bigInteger('size_bytes')->default(0)->comment('Artifact size in bytes');
            $table->timestamp('pushed_at')->nullable()->comment('Push timestamp');
            $table->timestamp('pulled_at')->nullable()->comment('Last pull timestamp');
            $table->json('scan_overview')->nullable()->comment('Vulnerability scan overview');
            $table->string('scan_status')->nullable()->comment('Scan status');
            $table->json('labels')->nullable()->comment('Artifact labels');
            $table->json('annotations')->nullable()->comment('Artifact annotations');
            $table->json('references')->nullable()->comment('Artifact references');
            $table->timestamps();
            $table->softDeletes();

            // Unique constraint on repository + digest
            $table->unique(['repository_id', 'digest']);

            // Indexes for performance
            $table->index('tag');
            $table->index('digest');
            $table->index('pushed_at');
            $table->index('scan_status');
            $table->index(['repository_id', 'tag']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('harbor_artifacts');
    }
};
