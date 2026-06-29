<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Monitor de providers LLM — séries temporais Argus / Mission Control.
     */
    public function up(): void
    {
        Schema::create('llm_provider_snapshots', function (Blueprint $table) {
            $table->id();
            $table->string('provider', 64);
            $table->string('model_alias', 128);
            $table->string('tier', 8)->nullable();
            $table->string('status', 32);
            $table->json('windows_json')->nullable();
            $table->unsignedInteger('context_tokens')->nullable();
            $table->text('detail')->nullable();
            $table->timestamp('captured_at');
            $table->timestamps();

            $table->index(['provider', 'captured_at']);
            $table->index(['model_alias', 'captured_at']);
        });

        Schema::create('llm_probe_runs', function (Blueprint $table) {
            $table->id();
            $table->string('probe_type', 32);
            $table->string('harness', 64)->default('laravel');
            $table->string('model', 128);
            $table->unsignedInteger('latency_ms')->nullable();
            $table->string('result', 32);
            $table->unsignedInteger('tokens_in')->nullable();
            $table->unsignedInteger('tokens_out')->nullable();
            $table->unsignedSmallInteger('http_status')->nullable();
            $table->json('meta_json')->nullable();
            $table->timestamps();

            $table->index(['model', 'created_at']);
            $table->index(['probe_type', 'created_at']);
        });

        Schema::create('llm_limit_events', function (Blueprint $table) {
            $table->id();
            $table->string('provider', 64);
            $table->string('model_alias', 128)->nullable();
            $table->string('window', 32);
            $table->string('severity', 16);
            $table->text('message');
            $table->timestamp('resolved_at')->nullable();
            $table->timestamps();

            $table->index(['provider', 'resolved_at']);
            $table->index(['severity', 'created_at']);
        });

        Schema::create('llm_config_change_proposals', function (Blueprint $table) {
            $table->id();
            $table->json('diff');
            $table->text('reason');
            $table->string('tier', 8);
            $table->string('status', 16)->default('pending');
            $table->string('approved_by', 128)->nullable();
            $table->timestamp('applied_at')->nullable();
            $table->timestamps();

            $table->index(['status', 'tier']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('llm_config_change_proposals');
        Schema::dropIfExists('llm_limit_events');
        Schema::dropIfExists('llm_probe_runs');
        Schema::dropIfExists('llm_provider_snapshots');
    }
};
