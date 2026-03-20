<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('production_approvals')) {
            return;
        }

        if (! Schema::hasColumn('production_approvals', 'environment_id')) {
            return;
        }

        Schema::disableForeignKeyConstraints();

        try {
            try {
                Schema::table('production_approvals', function (Blueprint $table) {
                    $table->dropIndex(['environment_id', 'status']);
                });
            } catch (\Throwable) {
                // Índice pode ter nome distinto consoante o driver; ignora se já não existir.
            }

            Schema::table('production_approvals', function (Blueprint $table) {
                $table->dropForeign(['environment_id']);
            });

            if (Schema::hasColumn('production_approvals', 'approved_by')) {
                Schema::table('production_approvals', function (Blueprint $table) {
                    $table->dropForeign(['approved_by']);
                });
            }

            Schema::table('production_approvals', function (Blueprint $table) {
                $table->dropColumn([
                    'environment_id',
                    'deployment_version',
                    'approval_level',
                    'approver_role',
                ]);
            });

            Schema::table('production_approvals', function (Blueprint $table) {
                $table->foreignUuid('promotion_id')->nullable()->after('id')->constrained('promotions')->cascadeOnDelete();
                $table->foreignId('approver_id')->nullable()->after('promotion_id')->constrained('users')->cascadeOnDelete();
                $table->timestamp('requested_at')->nullable()->after('approver_id');
            });

            Schema::table('production_approvals', function (Blueprint $table) {
                $table->index(['promotion_id', 'status']);
                $table->index(['approver_id', 'status']);
                $table->index('expires_at');
            });
        } finally {
            Schema::enableForeignKeyConstraints();
        }
    }

    public function down(): void
    {
        if (! Schema::hasTable('production_approvals')) {
            return;
        }

        if (! Schema::hasColumn('production_approvals', 'promotion_id')) {
            return;
        }

        Schema::disableForeignKeyConstraints();

        try {
            Schema::table('production_approvals', function (Blueprint $table) {
                $table->dropIndex(['promotion_id', 'status']);
                $table->dropIndex(['approver_id', 'status']);
            });
        } catch (\Throwable) {
        }

        try {
            Schema::table('production_approvals', function (Blueprint $table) {
                $table->dropIndex(['expires_at']);
            });
        } catch (\Throwable) {
        }

        Schema::table('production_approvals', function (Blueprint $table) {
            $table->dropForeign(['promotion_id']);
            $table->dropForeign(['approver_id']);
        });

        Schema::table('production_approvals', function (Blueprint $table) {
            $table->dropColumn([
                'promotion_id',
                'approver_id',
                'requested_at',
            ]);
        });

        Schema::table('production_approvals', function (Blueprint $table) {
            $table->foreignId('environment_id')->after('id')->constrained('environments')->cascadeOnDelete();
            $table->string('deployment_version')->after('environment_id');
            $table->integer('approval_level')->default(1)->after('deployment_version');
            $table->string('approver_role')->after('approval_level');
        });

        Schema::enableForeignKeyConstraints();
    }
};
