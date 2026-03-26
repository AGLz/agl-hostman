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
        Schema::create('backups', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->enum('type', ['full', 'database', 'files', 'config']);
            $table->bigInteger('size')->default(0);
            $table->string('path')->nullable();
            $table->string('remote_path')->nullable();
            $table->json('metadata')->nullable();
            $table->boolean('encrypted')->default(false);
            $table->boolean('verified')->default(false);
            $table->timestamp('expires_at')->nullable();
            $table->timestamps();

            $table->index('created_at');
            $table->index('type');
            $table->index('expires_at');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('backups');
    }
};
