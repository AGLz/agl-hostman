<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Add RBAC Fields to API Keys Table
 *
 * Adds role-based access control fields to the api_keys table to support
 * fine-grained access control for MCP server and API endpoints.
 *
 * @package Database\Migrations
 */
return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('api_keys', function (Blueprint $table) {
            // Role assignment for API keys
            $table->string('role')->default('viewer')->after('user_id')->index();
            $table->json('permissions')->nullable()->after('role');

            // RBAC metadata
            $table->string('access_level')->default('read-only')->after('permissions');
            $table->json('allowed_tools')->nullable()->after('access_level');

            // Rate limiting by role
            $table->integer('rate_limit')->default(100)->after('allowed_tools');

            // Secret access permissions
            $table->boolean('can_read_secrets')->default(false)->after('rate_limit');
            $table->json('allowed_secrets')->nullable()->after('can_read_secrets');

            // Audit fields
            $table->timestamp('last_used_at')->nullable()->after('expires_at');
            $table->string('last_used_ip', 45)->nullable()->after('last_used_at');
            $table->unsignedInteger('usage_count')->default(0)->after('last_used_ip');

            // Indexes for common queries
            $table->index(['role', 'is_active'], 'api_keys_role_active_index');
            $table->index('last_used_at', 'api_keys_last_used_index');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('api_keys', function (Blueprint $table) {
            $table->dropIndex('api_keys_role_active_index');
            $table->dropIndex('api_keys_last_used_index');

            $table->dropColumn([
                'role',
                'permissions',
                'access_level',
                'allowed_tools',
                'rate_limit',
                'can_read_secrets',
                'allowed_secrets',
                'last_used_at',
                'last_used_ip',
                'usage_count',
            ]);
        });
    }
};
