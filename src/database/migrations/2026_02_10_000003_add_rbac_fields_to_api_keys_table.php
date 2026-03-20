<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Campos RBAC em api_keys (colunas já existentes em create_api_keys_table são reutilizadas).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('api_keys', function (Blueprint $table) {
            $table->string('role')->default('viewer')->after('user_id');
            $table->string('access_level')->default('read-only')->after('permissions');
            $table->json('allowed_tools')->nullable()->after('access_level');
            $table->boolean('can_read_secrets')->default(false)->after('rate_limit');
            $table->json('allowed_secrets')->nullable()->after('can_read_secrets');

            $table->index(['role', 'is_active'], 'api_keys_role_active_index');
        });
    }

    public function down(): void
    {
        Schema::table('api_keys', function (Blueprint $table) {
            $table->dropIndex('api_keys_role_active_index');

            $table->dropColumn([
                'role',
                'access_level',
                'allowed_tools',
                'can_read_secrets',
                'allowed_secrets',
            ]);
        });
    }
};
