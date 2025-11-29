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
        Schema::create('on_call_schedules', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->timestamp('start_time')->index();
            $table->timestamp('end_time')->index();
            $table->enum('rotation_type', ['weekly', 'daily', 'custom'])->default('weekly');
            $table->json('rotation_config')->nullable(); // Rotation-specific configuration
            $table->boolean('is_override')->default(false); // Manual override of rotation
            $table->text('override_reason')->nullable();
            $table->foreignId('created_by')->nullable()->constrained('users')->onDelete('set null');
            $table->timestamps();

            // Indexes for performance
            $table->index(['user_id', 'start_time', 'end_time']);
            $table->index(['start_time', 'end_time']); // For finding current on-call
            $table->index('is_override');
        });

        // Create rotation history table
        Schema::create('on_call_rotation_history', function (Blueprint $table) {
            $table->id();
            $table->foreignId('from_user_id')->nullable()->constrained('users')->onDelete('set null');
            $table->foreignId('to_user_id')->constrained('users')->onDelete('cascade');
            $table->timestamp('rotated_at');
            $table->enum('rotation_type', ['automatic', 'manual'])->default('automatic');
            $table->text('notes')->nullable();
            $table->timestamps();

            // Indexes
            $table->index('rotated_at');
            $table->index(['from_user_id', 'to_user_id']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('on_call_rotation_history');
        Schema::dropIfExists('on_call_schedules');
    }
};
