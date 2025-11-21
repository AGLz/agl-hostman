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
        Schema::table('sprints', function (Blueprint $table) {
            $table->string('archon_project_id')->nullable()->unique()->after('id');
            $table->string('github_repo')->nullable()->after('description');
            $table->timestamp('archon_synced_at')->nullable()->after('end_date');

            $table->index('archon_project_id');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('sprints', function (Blueprint $table) {
            $table->dropIndex(['archon_project_id']);
            $table->dropColumn(['archon_project_id', 'github_repo', 'archon_synced_at']);
        });
    }
};
