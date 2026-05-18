<?php

declare(strict_types=1);

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
        Schema::create('secret_versions', function (Blueprint $table) {
            $table->id();

            // Reference to the parent secret (cascade delete for clean teardown)
            $table->foreignId('secret_id')
                ->constrained('secrets')
                ->cascadeOnDelete();

            // Encrypted snapshot of the value at the time of archival
            $table->text('encrypted_value');

            // Version number at the time this snapshot was archived
            $table->integer('version')->unsigned();

            // Why this version was archived: "rotation", "manual", "import", etc.
            $table->string('archived_reason')->nullable();

            // When the value was archived
            $table->timestamp('archived_at');

            // When the grace period ends (null = no expiry; default 30 days from archival)
            $table->timestamp('expires_at')->nullable();

            $table->index(['secret_id', 'version']);
            $table->index('expires_at');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('secret_versions');
    }
};
