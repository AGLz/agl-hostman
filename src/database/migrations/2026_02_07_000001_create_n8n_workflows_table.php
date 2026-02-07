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
        Schema::create('n8n_workflows', function (Blueprint $table) {
            $table->id();
            $table->string('n8n_id')->unique()->index()->comment('External N8N workflow ID');
            $table->string('name')->comment('Workflow name');
            $table->string('slug')->nullable()->unique()->index()->comment('URL-friendly workflow identifier');
            $table->text('description')->nullable()->comment('Workflow description');
            $table->boolean('active')->default(false)->comment('Whether workflow is active in N8N');
            $table->string('category')->nullable()->comment('Workflow category for organization');
            $table->json('settings')->nullable()->comment('Workflow nodes and configuration');
            $table->json('metadata')->nullable()->comment('Additional workflow metadata');
            $table->timestamp('last_synced_at')->nullable()->comment('Last sync from N8N');
            $table->timestamp('last_executed_at')->nullable()->comment('Last execution timestamp');
            $table->unsignedInteger('execution_count')->default(0)->comment('Total execution count');
            $table->json('tags')->nullable()->comment('Workflow tags');
            $table->timestamps();
            $table->softDeletes();

            // Indexes for performance
            $table->index('active');
            $table->index('category');
            $table->index('last_synced_at');
            $table->index('last_executed_at');
            $table->index(['active', 'category']);
        });

        Schema::create('n8n_workflow_executions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('workflow_id')->constrained('n8n_workflows')->cascadeOnDelete();
            $table->string('n8n_execution_id')->nullable()->unique()->index()->comment('External N8N execution ID');
            $table->enum('status', ['pending', 'running', 'success', 'failed', 'cancelled'])
                ->default('pending')
                ->index()
                ->comment('Execution status');
            $table->json('input_data')->nullable()->comment('Data sent to workflow');
            $table->json('output_data')->nullable()->comment('Data returned from workflow');
            $table->text('error_message')->nullable()->comment('Error details if failed');
            $table->unsignedInteger('duration_ms')->nullable()->comment('Execution duration in milliseconds');
            $table->timestamp('started_at')->nullable()->comment('When execution started');
            $table->timestamp('completed_at')->nullable()->comment('When execution completed');
            $table->string('triggered_by')->nullable()->comment('Who/what triggered the execution');
            $table->json('metadata')->nullable()->comment('Additional execution metadata');
            $table->timestamps();

            // Indexes for performance
            $table->index('status');
            $table->index('started_at');
            $table->index('completed_at');
            $table->index(['workflow_id', 'status']);
            $table->index(['workflow_id', 'started_at']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('n8n_workflow_executions');
        Schema::dropIfExists('n8n_workflows');
    }
};
