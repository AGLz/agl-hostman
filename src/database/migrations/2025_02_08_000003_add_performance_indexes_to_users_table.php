<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Add performance indexes to users table
     */
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            // Active status and last login (dashboard queries)
            $table->index(['is_active', 'last_login_at'], 'idx_users_active_login');

            // WorkOS integration index
            $table->index('workos_id', 'idx_users_workos_id');

            // Email lookup (authentication)
            $table->index('email', 'idx_users_email');

            // Active status index
            $table->index('is_active', 'idx_users_is_active');
        });
    }

    /**
     * Reverse the migration
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropIndex('idx_users_active_login');
            $table->dropIndex('idx_users_workos_id');
            $table->dropIndex('idx_users_email');
            $table->dropIndex('idx_users_is_active');
        });
    }
};
