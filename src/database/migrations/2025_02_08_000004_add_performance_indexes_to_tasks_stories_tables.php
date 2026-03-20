<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Add performance indexes to tasks and stories tables
     */
    public function up(): void
    {
        if (Schema::hasTable('tasks')) {
            Schema::table('tasks', function (Blueprint $table) {
                $table->index(['status', 'sprint_id'], 'idx_tasks_status_sprint');
                $table->index('assignee_id', 'idx_tasks_assignee');
                $table->index('story_id', 'idx_tasks_story');
                $table->index('created_at', 'idx_tasks_created_at');
            });
        }

        if (Schema::hasTable('stories')) {
            Schema::table('stories', function (Blueprint $table) {
                $table->index(['status', 'sprint_id'], 'idx_stories_status_sprint');
                $table->index('created_by', 'idx_stories_created_by');
                $table->index('created_at', 'idx_stories_created_at');
            });
        }

        if (Schema::hasTable('sprints')) {
            Schema::table('sprints', function (Blueprint $table) {
                $table->index(['status', 'start_date'], 'idx_sprints_status_date');
                $table->index('status', 'idx_sprints_status');
            });
        }
    }

    /**
     * Reverse the migration
     */
    public function down(): void
    {
        if (Schema::hasTable('tasks')) {
            Schema::table('tasks', function (Blueprint $table) {
                $table->dropIndex('idx_tasks_status_sprint');
                $table->dropIndex('idx_tasks_assignee');
                $table->dropIndex('idx_tasks_story');
                $table->dropIndex('idx_tasks_created_at');
            });
        }

        if (Schema::hasTable('stories')) {
            Schema::table('stories', function (Blueprint $table) {
                $table->dropIndex('idx_stories_status_sprint');
                $table->dropIndex('idx_stories_created_by');
                $table->dropIndex('idx_stories_created_at');
            });
        }

        if (Schema::hasTable('sprints')) {
            Schema::table('sprints', function (Blueprint $table) {
                $table->dropIndex('idx_sprints_status_date');
                $table->dropIndex('idx_sprints_status');
            });
        }
    }
};
