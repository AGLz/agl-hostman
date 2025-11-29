<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('dora_metrics', function (Blueprint $table) {
            $table->id();
            $table->string('period'); // day, week, month, quarter
            $table->json('deployment_frequency');
            $table->json('lead_time');
            $table->json('mttr');
            $table->json('change_failure_rate');
            $table->json('performance_tier');
            $table->timestamp('calculated_at');
            $table->timestamps();

            $table->index(['period', 'calculated_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('dora_metrics');
    }
};
