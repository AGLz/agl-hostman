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
        Schema::create('notification_channels', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->enum('type', ['slack', 'pagerduty', 'email', 'webhook'])->index();
            $table->text('description')->nullable();
            $table->json('config'); // Channel-specific configuration (webhook URLs, API keys, etc.)
            $table->boolean('enabled')->default(true)->index();
            $table->integer('priority')->default(0); // Higher priority channels are tried first
            $table->json('metadata')->nullable(); // Additional metadata
            $table->timestamps();
            $table->softDeletes();

            // Indexes for performance
            $table->index(['type', 'enabled']);
            $table->index('priority');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('notification_channels');
    }
};
