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
            $table->string('workos_id')->nullable()->unique()->after('email');
            $table->string('avatar_url')->nullable()->after('password');
            $table->timestamp('last_login_at')->nullable()->after('remember_token');
            $table->boolean('is_active')->default(true)->after('last_login_at');

            $table->index('workos_id');
            $table->index('is_active');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['workos_id', 'avatar_url', 'last_login_at', 'is_active']);
        });
    }
};
