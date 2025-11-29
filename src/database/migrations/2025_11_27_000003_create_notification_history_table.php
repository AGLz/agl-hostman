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
        Schema::create('notification_history', function (Blueprint $table) {
            $table->id();
            $table->foreignId('notification_channel_id')->nullable()->constrained()->onDelete('set null');
            $table->enum('channel_type', ['slack', 'pagerduty', 'email', 'webhook'])->index();
            $table->string('notification_type')->index(); // deployment, alert, pr, custom
            $table->string('source_id')->nullable()->index(); // ID of the source (deployment, alert, etc.)
            $table->json('payload'); // The notification payload sent
            $table->enum('status', ['pending', 'sent', 'failed', 'retrying'])->default('pending')->index();
            $table->json('response')->nullable(); // Response from the notification service
            $table->integer('attempts')->default(0);
            $table->timestamp('sent_at')->nullable();
            $table->timestamp('failed_at')->nullable();
            $table->foreignId('acknowledged_by')->nullable()->constrained('users')->onDelete('set null');
            $table->timestamp('acknowledged_at')->nullable();
            $table->timestamps();

            // Indexes for performance
            $table->index(['channel_type', 'status']);
            $table->index(['notification_type', 'source_id']);
            $table->index('created_at');
            $table->index('sent_at');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('notification_history');
    }
};
