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
        Schema::create('user_locations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->foreignId('physical_location_id')->constrained()->onDelete('cascade');
            $table->enum('access_level', ['view', 'manage', 'admin'])->default('view');
            $table->boolean('is_primary')->default(false); // Primary location for user
            $table->timestamps();
            
            $table->unique(['user_id', 'physical_location_id']);
            $table->index(['user_id', 'access_level']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('user_locations');
    }
};