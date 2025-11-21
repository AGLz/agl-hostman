<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations - Add critical performance indexes
     * Based on CODE-ANALYSIS-REPORT.md recommendations
     */
    public function up(): void
    {
        // Users table indexes
        if (Schema::hasTable('users')) {
            Schema::table('users', function (Blueprint $table) {
                $table->index('email', 'users_email_index');
                $table->index('created_at', 'users_created_at_index');
                if (Schema::hasColumn('users', 'workos_id')) {
                    $table->index('workos_id', 'users_workos_id_index');
                }
            });
        }

        // Physical locations indexes - using actual columns
        if (Schema::hasTable('physical_locations')) {
            Schema::table('physical_locations', function (Blueprint $table) {
                // Skip if columns don't exist - they're indexed in the create migration
                if (Schema::hasColumn('physical_locations', 'parent_id') && Schema::hasColumn('physical_locations', 'location_type')) {
                    $table->index(['parent_id', 'location_type'], 'locations_parent_type_index');
                }
                if (Schema::hasColumn('physical_locations', 'server_code')) {
                    $table->index('server_code', 'locations_server_code_index');
                }
            });
        }

        // User permissions indexes
        if (Schema::hasTable('physical_location_user')) {
            Schema::table('physical_location_user', function (Blueprint $table) {
                $table->index(['user_id', 'is_primary'], 'location_user_primary_index');
                $table->index(['physical_location_id', 'permission_level'], 'location_permission_index');
            });
        }

        // Jobs table indexes for Horizon performance
        if (Schema::hasTable('jobs')) {
            Schema::table('jobs', function (Blueprint $table) {
                $table->index(['queue', 'reserved_at'], 'jobs_queue_reserved_index');
            });
        }

        // Failed jobs indexes
        if (Schema::hasTable('failed_jobs')) {
            Schema::table('failed_jobs', function (Blueprint $table) {
                $table->index('failed_at', 'failed_jobs_failed_at_index');
            });
        }
    }

    /**
     * Reverse the migrations
     */
    public function down(): void
    {
        if (Schema::hasTable('users')) {
            Schema::table('users', function (Blueprint $table) {
                $table->dropIndex('users_email_index');
                $table->dropIndex('users_created_at_index');
                if (Schema::hasColumn('users', 'workos_id')) {
                    $table->dropIndex('users_workos_id_index');
                }
            });
        }

        if (Schema::hasTable('physical_locations')) {
            Schema::table('physical_locations', function (Blueprint $table) {
                // Only drop indexes if they exist
                if (Schema::hasColumn('physical_locations', 'parent_id')) {
                    $table->dropIndex('locations_parent_type_index');
                }
                if (Schema::hasColumn('physical_locations', 'server_code')) {
                    $table->dropIndex('locations_server_code_index');
                }
            });
        }

        if (Schema::hasTable('physical_location_user')) {
            Schema::table('physical_location_user', function (Blueprint $table) {
                $table->dropIndex('location_user_primary_index');
                $table->dropIndex('location_permission_index');
            });
        }

        if (Schema::hasTable('jobs')) {
            Schema::table('jobs', function (Blueprint $table) {
                $table->dropIndex('jobs_queue_reserved_index');
            });
        }

        if (Schema::hasTable('failed_jobs')) {
            Schema::table('failed_jobs', function (Blueprint $table) {
                $table->dropIndex('failed_jobs_failed_at_index');
            });
        }
    }
};
