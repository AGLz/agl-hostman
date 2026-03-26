<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Registos diários de trabalho com o assistente (resumos, projetos, pesquisa).
     */
    public function up(): void
    {
        Schema::create('daily_session_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->date('occurred_on');
            $table->string('title')->nullable();
            $table->longText('summary');
            $table->json('topics')->nullable();
            $table->json('project_tags')->nullable();
            $table->string('source', 32)->default('manual');
            $table->timestamps();

            $table->index(['user_id', 'occurred_on']);
            $table->index('occurred_on');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('daily_session_logs');
    }
};
