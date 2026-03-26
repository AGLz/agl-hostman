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
        // Add indexes to existing jobs table for better queue performance
        Schema::table('jobs', function (Blueprint $table) {
            $table->index(['queue', 'reserved_at']);
            $table->index(['queue', 'available_at']);
        });

        // Add index to job_batches table
        Schema::table('job_batches', function (Blueprint $table) {
            if (! Schema::hasColumn('job_batches', 'queue')) {
                $table->string('queue')->nullable();
                $table->index('queue');
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('jobs', function (Blueprint $table) {
            $table->dropIndex(['queue', 'reserved_at']);
            $table->dropIndex(['queue', 'available_at']);
        });

        Schema::table('job_batches', function (Blueprint $table) {
            $table->dropIndex('queue');
            if (Schema::hasColumn('job_batches', 'queue')) {
                $table->dropColumn('queue');
            }
        });
    }
};
