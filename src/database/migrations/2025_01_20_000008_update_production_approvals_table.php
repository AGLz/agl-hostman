<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('production_approvals', function (Blueprint $table) {
            // Drop old columns
            $table->dropColumn([
                'environment_id',
                'deployment_version',
                'approval_level',
                'approver_role',
            ]);
            
            // Add new columns
            $table->uuid('promotion_id')->after('id');
            $table->unsignedBigInteger('approver_id')->after('promotion_id');
            $table->timestamp('requested_at')->nullable()->after('approver_id');
            
            // Add foreign keys
            $table->foreign('promotion_id')
                ->references('id')
                ->on('promotions')
                ->onDelete('cascade');
                
            $table->foreign('approver_id')
                ->references('id')
                ->on('users')
                ->onDelete('cascade');
                
            // Add indexes
            $table->index(['promotion_id', 'status']);
            $table->index(['approver_id', 'status']);
            $table->index('expires_at');
        });
    }

    public function down(): void
    {
        Schema::table('production_approvals', function (Blueprint $table) {
            $table->dropForeign(['promotion_id']);
            $table->dropForeign(['approver_id']);
            
            $table->dropColumn([
                'promotion_id',
                'approver_id',
                'requested_at',
            ]);
            
            $table->unsignedBigInteger('environment_id')->after('id');
            $table->string('deployment_version')->after('environment_id');
            $table->integer('approval_level')->default(1)->after('deployment_version');
            $table->string('approver_role')->after('approval_level');
        });
    }
};
