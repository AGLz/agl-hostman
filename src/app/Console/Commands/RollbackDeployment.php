<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Models\DokployDeployment;
use App\Models\Environment;
use App\Services\Deployment\DeploymentWorkflowService;
use Illuminate\Console\Command;

/**
 * Artisan command: deployment:rollback-deployment
 *
 * Rolls back a specific deployment (or the latest failed deployment for an
 * environment) to the previous successful image in Harbor.
 *
 * Usage:
 *   php artisan deployment:rollback-deployment <deployment-id> [--reason="..."]
 *   php artisan deployment:rollback-deployment --latest --env=qa [--reason="..."] [--dry-run]
 *
 * NOTE: This command does NOT revert database migrations.
 * See docs/ROLLBACK-USAGE.md for full guidance.
 */
class RollbackDeployment extends Command
{
    protected $signature = 'deployment:rollback-deployment
        {id? : Deployment ID to roll back from (required unless --latest is used)}
        {--env= : Environment type (qa, uat, production) — used with --latest}
        {--latest : Roll back the most recent failed deployment for the given --env}
        {--reason= : Optional human-readable reason for the rollback (stored in audit log)}
        {--dry-run : Preview what would happen without actually rolling back}';

    protected $description = 'Roll back a deployment to the previous successful image in Harbor';

    public function __construct(
        private readonly DeploymentWorkflowService $workflowService
    ) {
        parent::__construct();
    }

    public function handle(): int
    {
        if (! config('deployment.rollback_enabled', true)) {
            $this->error('Rollbacks are disabled (DOKPLOY_ROLLBACK_ENABLED=false).');

            return self::FAILURE;
        }

        $deployment = $this->resolveDeployment();

        if (! $deployment) {
            return self::FAILURE;
        }

        $reason = $this->option('reason');
        $isDryRun = (bool) $this->option('dry-run');

        $this->renderDeploymentInfo($deployment, $reason, $isDryRun);

        // Dry-run: show what would happen and exit
        if ($isDryRun) {
            $previous = DokployDeployment::where('application_id', $deployment->application_id)
                ->where('status', 'success')
                ->where('id', '!=', $deployment->id)
                ->orderBy('completed_at', 'desc')
                ->first();

            if (! $previous) {
                $this->error('DRY-RUN: No previous successful deployment found. Rollback would fail.');

                return self::FAILURE;
            }

            $this->info('DRY-RUN: Rollback would restore:');
            $this->table(
                ['Field', 'Value'],
                [
                    ['Deployment ID', $previous->id],
                    ['Tag', $previous->tag ?? '(none)'],
                    ['Commit', $previous->commit_hash ?? '(none)'],
                    ['Completed at', $previous->completed_at?->toDateTimeString() ?? '(unknown)'],
                ]
            );
            $this->warn('DRY-RUN: No changes made.');

            return self::SUCCESS;
        }

        if (! $this->confirm('Are you sure you want to roll back this deployment?')) {
            $this->info('Rollback cancelled.');

            return self::SUCCESS;
        }

        $this->info('Initiating rollback…');

        $result = $this->workflowService->rollback((string) $deployment->id, $reason);

        if ($result['success']) {
            $this->info('✅ Rollback completed successfully.');
            $this->table(
                ['Field', 'Value'],
                [
                    ['Rollback Deployment ID', $result['rollback_deployment_id']],
                    ['Rolled back to Deployment', $result['rolled_back_to_deployment']],
                    ['Rolled back to Tag', $result['rolled_back_to_tag'] ?? '(none)'],
                    ['Rolled back to Commit', $result['rolled_back_to_commit'] ?? '(none)'],
                ]
            );

            return self::SUCCESS;
        }

        $this->error("❌ Rollback failed: {$result['error']}");

        return self::FAILURE;
    }

    private function resolveDeployment(): ?DokployDeployment
    {
        if ($this->option('latest')) {
            $env = $this->option('env');
            if (! $env) {
                $this->error('--env is required when using --latest.');

                return null;
            }

            // Resolve environment by type, then filter deployments via
            // application → project (using dokploy_project_id as the bridge).
            $environment = Environment::where('type', $env)->first();
            if (! $environment) {
                $this->error("Environment not found for type: {$env}");

                return null;
            }

            $deployment = DokployDeployment::query()
                ->whereHas('application', fn ($q) => $q->whereHas('project', fn ($q2) => $q2->where('dokploy_id', $environment->dokploy_project_id)))
                ->where('status', 'failed')
                ->orderBy('created_at', 'desc')
                ->first();

            if (! $deployment) {
                $this->error("No failed deployment found for environment: {$env}");

                return null;
            }

            return $deployment;
        }

        $id = $this->argument('id');
        if (! $id) {
            $this->error('Provide a deployment ID or use --latest --env=<env>.');

            return null;
        }

        $deployment = DokployDeployment::find($id);
        if (! $deployment) {
            $this->error("Deployment not found: {$id}");

            return null;
        }

        return $deployment;
    }

    private function renderDeploymentInfo(DokployDeployment $deployment, ?string $reason, bool $isDryRun): void
    {
        $prefix = $isDryRun ? '[DRY-RUN] ' : '';
        $this->warn("{$prefix}Rolling back deployment #{$deployment->id}");
        $this->table(
            ['Field', 'Value'],
            [
                ['Deployment ID', $deployment->id],
                ['Status', $deployment->status],
                ['Tag', $deployment->tag ?? '(none)'],
                ['Commit', $deployment->commit_hash ?? '(none)'],
                ['Reason', $reason ?? '(none provided)'],
            ]
        );
    }
}
