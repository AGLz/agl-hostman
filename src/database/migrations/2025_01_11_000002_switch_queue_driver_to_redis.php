<?php

use Illuminate\Database\Migrations\Migration;

return new class extends Migration
{
    /**
     * Run the migrations - Prepare for Redis queue driver
     * Note: Requires QUEUE_CONNECTION=redis in .env after deployment
     */
    public function up(): void
    {
        // This migration serves as a deployment checkpoint
        // Actual queue driver change requires .env update

        // Clear and restart queue workers after deployment
        // Artisan::call('queue:clear');
        // Artisan::call('horizon:terminate');

        // Checkpoint de deploy: atualizar QUEUE_CONNECTION no .env e reiniciar workers (sem echo: quebra Pest/phpunit output)
    }

    /**
     * Reverse the migrations
     */
    public function down(): void
    {
    }
};
