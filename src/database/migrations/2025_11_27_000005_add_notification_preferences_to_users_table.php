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
        Schema::table('users', function (Blueprint $table) {
            $table->json('notification_preferences')->nullable()->after('email');
            /*
             * Example structure:
             * {
             *   "muted": {
             *     "deployment": false,
             *     "alert": false,
             *     "pr": false
             *   },
             *   "channels": {
             *     "slack": true,
             *     "email": true,
             *     "pagerduty": false
             *   },
             *   "quiet_hours": {
             *     "enabled": true,
             *     "start": "22:00",
             *     "end": "08:00",
             *     "timezone": "America/New_York"
             *   },
             *   "severity_threshold": "warning"
             * }
             */
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('notification_preferences');
        });
    }
};
