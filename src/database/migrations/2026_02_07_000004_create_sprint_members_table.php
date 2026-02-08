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
        Schema::create('sprint_members', function (Blueprint $table) {
            $table->id();
            $table->foreignId('sprint_id')->constrained()->onDelete('cascade');
            $table->foreignId('user_id')->constrained('users')->onDelete('cascade');
            $table->enum('role', ['scrum_master', 'product_owner', 'developer', 'tester', 'designer', 'observer'])->default('developer');
            $table->integer('capacity')->nullable()->comment('Capacity percentage (0-100)');
            $table->integer('availability')->default(100)->comment('Availability percentage (0-100)');
            $table->timestamp('joined_at')->useCurrent();
            $table->timestamp('left_at')->nullable();
            $table->timestamps();

            $table->unique(['sprint_id', 'user_id']);
            $table->index(['sprint_id', 'role']);
            $table->index('left_at');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('sprint_members');
    }
};
