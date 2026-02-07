<?php

declare(strict_types=1);

use App\Models\SecurityAuditLog;
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
        Schema::create('security_audit_logs', function (Blueprint $table) {
            $table->id();
            $table->string('event_type', 100)->index();
            $table->enum('severity', SecurityAuditLog::getSeverityLevels())->default(SecurityAuditLog::SEVERITY_INFO)->index();
            $table->text('description');

            // User info
            $table->unsignedBigInteger('user_id')->nullable()->index();
            $table->string('ip_address', 45)->nullable();
            $table->text('user_agent')->nullable();

            // Polymorphic relation to auditable entity
            $table->string('auditable_type')->nullable();
            $table->unsignedBigInteger('auditable_id')->nullable();
            $table->index(['auditable_type', 'auditable_id']);

            // Change tracking
            $table->json('old_values')->nullable();
            $table->json('new_values')->nullable();

            // Additional metadata
            $table->json('metadata')->nullable();
            $table->json('tags')->nullable();

            $table->timestamp('created_at')->index();

            // Composite indexes for common queries
            $table->index(['severity', 'created_at'], 'severity_created_index');
            $table->index(['event_type', 'created_at'], 'event_type_created_index');
            $table->index(['user_id', 'created_at'], 'user_created_index');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('security_audit_logs');
    }
};
