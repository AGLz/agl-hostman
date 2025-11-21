<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\Artisan;

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

        echo "⚠️  MANUAL STEP REQUIRED:\n";
        echo "1. Update .env: QUEUE_CONNECTION=redis\n";
        echo "2. Run: php artisan config:clear\n";
        echo "3. Run: php artisan horizon:terminate\n";
        echo "4. Supervisor will auto-restart Horizon workers\n";
    }

    /**
     * Reverse the migrations
     */
    public function down(): void
    {
        echo "⚠️  MANUAL STEP REQUIRED:\n";
        echo "1. Update .env: QUEUE_CONNECTION=database\n";
        echo "2. Run: php artisan config:clear\n";
        echo "3. Run: php artisan horizon:terminate\n";
    }
};
