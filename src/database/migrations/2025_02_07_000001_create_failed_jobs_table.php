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
        Schema::create('failed_jobs', function (Blueprint $table) {
            $table->id();
            $table->string('uuid')->unique();
            $table->text('connection');
            $table->text('queue');
            $table->longText('payload');
            $table->longText('exception');
            $table->timestamp('failed_at')->useCurrent();

            // Add indexes for common queries
            $table->index('queue');
            $table->index('failed_at');
        });

        // Create failed_jobs monitoring table
        Schema::create('failed_jobs_monitoring', function (Blueprint $table) {
            $table->id();
            $table->string('job_type');
            $table->string('queue');
            $table->string('error_type');
            $table->text('error_message');
            $table->integer('occurrence_count')->default(1);
            $table->timestamp('first_seen');
            $table->timestamp('last_seen');
            $table->boolean('resolved')->default(false);
            $table->timestamp('resolved_at')->nullable();
            $table->text('resolution_notes')->nullable();
            $table->timestamps();

            $table->index(['job_type', 'queue']);
            $table->index('last_seen');
            $table->index('resolved');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('failed_jobs_monitoring');
        Schema::dropIfExists('failed_jobs');
    }
};
