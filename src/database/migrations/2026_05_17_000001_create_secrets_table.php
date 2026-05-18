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
        Schema::create('secrets', function (Blueprint $table) {
            $table->id();

            // Logical key for the secret (e.g., "database.primary.password")
            $table->string('key')->unique();

            // Laravel Encrypter (AES-256-CBC) output — value is never stored in plaintext
            $table->text('encrypted_value');

            // Optional metadata: description, tags, rotation_schedule, etc.
            $table->json('metadata')->nullable();

            // Rotation tracking — incremented on every rotate()
            $table->integer('version')->default(1)->unsigned();

            // Soft-active flag — false means logically deleted (keeps audit trail)
            $table->boolean('is_active')->default(true)->index();

            $table->timestamps();
            $table->softDeletes();

            // Composite index for the most common query pattern
            $table->index(['is_active', 'version']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('secrets');
    }
};
