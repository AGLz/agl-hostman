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
        Schema::table('tasks', function (Blueprint $table) {
            $table->string('archon_task_id')->nullable()->unique()->after('id');
            $table->timestamp('archon_synced_at')->nullable()->after('updated_at');

            $table->index('archon_task_id');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('tasks', function (Blueprint $table) {
            $table->dropIndex(['archon_task_id']);
            $table->dropColumn(['archon_task_id', 'archon_synced_at']);
        });
    }
};
