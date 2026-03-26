<?php

namespace App\Jobs;

use App\Models\LxcContainer;
use App\Models\ProxmoxServer;
use App\Models\SecurityAuditLog;
use App\Services\AlertService;
use App\Services\SecurityAuditService;
use App\Services\SecurityComplianceService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

/**
 * Security Scan Job
 *
 * Runs comprehensive security scans across infrastructure.
 * Performs vulnerability checks, compliance validation, and security audits.
 */
class SecurityScanJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    /**
     * Job timeout (seconds) - security scans can take longer
     */
    public int $timeout = 600;

    /**
     * Number of retry attempts
     */
    public int $tries = 2;

    /**
     * Backoff delay between retries (seconds)
     */
    public int $backoff = 120;

    /**
     * Scan type: 'full', 'vulnerability', 'compliance', 'configuration'
     */
    protected string $scanType;

    /**
     * Target: 'all', specific server code, or container ID
     */
    protected string $target;

    /**
     * Whether to create alerts for findings
     */
    protected bool $createAlerts;

    /**
     * User who initiated the scan
     */
    protected ?int $userId;

    /**
     * Create a new job instance.
     */
    public function __construct(
        string $scanType = 'full',
        string $target = 'all',
        bool $createAlerts = true,
        ?int $userId = null
    ) {
        $this->scanType = $scanType;
        $this->target = $target;
        $this->createAlerts = $createAlerts;
        $this->userId = $userId;

        // Security scans go on high-priority queue
        $this->onQueue('security-scans');
    }

    /**
     * Execute the job.
     */
    public function handle(
        SecurityAuditService $auditService,
        SecurityComplianceService $complianceService,
        AlertService $alertService
    ): void {
        $startTime = microtime(true);
        $scanId = 'scan_'.now()->format('Ymd_His').'_'.Str::random(8);

        Log::info('Starting security scan', [
            'scan_id' => $scanId,
            'type' => $this->scanType,
            'target' => $this->target,
            'user_id' => $this->userId,
        ]);

        try {
            $findings = [];
            $complianceResults = [];

            // Get targets based on scan type
            $targets = $this->getScanTargets();

            switch ($this->scanType) {
                case 'vulnerability':
                    $findings = $this->runVulnerabilityScan($targets, $auditService);
                    break;

                case 'compliance':
                    $complianceResults = $this->runComplianceCheck($targets, $complianceService);
                    break;

                case 'configuration':
                    $findings = $this->runConfigurationAudit($targets, $auditService);
                    break;

                case 'full':
                default:
                    $findings = $this->runVulnerabilityScan($targets, $auditService);
                    $complianceResults = $this->runComplianceCheck($targets, $complianceService);
                    $findings = array_merge($findings, $this->runConfigurationAudit($targets, $auditService));
                    break;
            }

            // Store audit log
            $this->storeAuditLog($scanId, $findings, $complianceResults);

            // Create alerts for critical findings
            if ($this->createAlerts) {
                $this->createAlertsForFindings($findings, $alertService, $scanId);
            }

            $duration = round(microtime(true) - $startTime, 2);

            Log::info('Security scan completed', [
                'scan_id' => $scanId,
                'findings' => count($findings),
                'compliance_issues' => count($complianceResults),
                'duration' => $duration,
            ]);

            // Store results in cache
            Cache::put("security_scan:{$scanId}", [
                'findings' => $findings,
                'compliance' => $complianceResults,
                'duration' => $duration,
            ], 86400); // Keep for 24 hours

        } catch (\Exception $e) {
            Log::error('Security scan failed', [
                'scan_id' => $scanId,
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
            ]);

            throw $e;
        }
    }

    /**
     * Get scan targets based on target specification
     */
    protected function getScanTargets(): array
    {
        if ($this->target === 'all') {
            return [
                'servers' => ProxmoxServer::online()->get(),
                'containers' => LxcContainer::all(),
            ];
        }

        // Check if target is a server
        $server = ProxmoxServer::where('code', $this->target)->first();
        if ($server) {
            return [
                'servers' => collect([$server]),
                'containers' => $server->containers,
            ];
        }

        // Check if target is a container ID
        $container = LxcContainer::find($this->target);
        if ($container) {
            return [
                'servers' => collect([$container->server]),
                'containers' => collect([$container]),
            ];
        }

        return [
            'servers' => collect(),
            'containers' => collect(),
        ];
    }

    /**
     * Run vulnerability scan
     */
    protected function runVulnerabilityScan(array $targets, SecurityAuditService $service): array
    {
        $findings = [];

        foreach ($targets['servers'] as $server) {
            try {
                $serverFindings = $service->auditServerVulnerabilities($server->code);
                $findings = array_merge($findings, $serverFindings);
            } catch (\Exception $e) {
                Log::warning('Vulnerability scan failed for server', [
                    'server' => $server->code,
                    'error' => $e->getMessage(),
                ]);
            }
        }

        foreach ($targets['containers'] as $container) {
            try {
                $containerFindings = $service->auditContainerVulnerabilities($container->vmid);
                $findings = array_merge($findings, $containerFindings);
            } catch (\Exception $e) {
                Log::warning('Vulnerability scan failed for container', [
                    'container' => $container->vmid,
                    'error' => $e->getMessage(),
                ]);
            }
        }

        return $findings;
    }

    /**
     * Run compliance check
     */
    protected function runComplianceCheck(array $targets, SecurityComplianceService $service): array
    {
        $issues = [];

        foreach ($targets['servers'] as $server) {
            try {
                $serverIssues = $service->checkServerCompliance($server->code);
                $issues = array_merge($issues, $serverIssues);
            } catch (\Exception $e) {
                Log::warning('Compliance check failed for server', [
                    'server' => $server->code,
                    'error' => $e->getMessage(),
                ]);
            }
        }

        return $issues;
    }

    /**
     * Run configuration audit
     */
    protected function runConfigurationAudit(array $targets, SecurityAuditService $service): array
    {
        $findings = [];

        foreach ($targets['servers'] as $server) {
            try {
                $serverFindings = $service->auditServerConfiguration($server->code);
                $findings = array_merge($findings, $serverFindings);
            } catch (\Exception $e) {
                Log::warning('Configuration audit failed for server', [
                    'server' => $server->code,
                    'error' => $e->getMessage(),
                ]);
            }
        }

        return $findings;
    }

    /**
     * Store audit log
     */
    protected function storeAuditLog(string $scanId, array $findings, array $complianceResults): void
    {
        SecurityAuditLog::create([
            'scan_id' => $scanId,
            'scan_type' => $this->scanType,
            'target' => $this->target,
            'findings' => json_encode($findings),
            'compliance_results' => json_encode($complianceResults),
            'critical_count' => count(array_filter($findings, fn ($f) => $f['severity'] === 'critical')),
            'high_count' => count(array_filter($findings, fn ($f) => $f['severity'] === 'high')),
            'medium_count' => count(array_filter($findings, fn ($f) => $f['severity'] === 'medium')),
            'low_count' => count(array_filter($findings, fn ($f) => $f['severity'] === 'low')),
            'performed_by' => $this->userId,
            'performed_at' => now(),
        ]);
    }

    /**
     * Create alerts for critical/high findings
     */
    protected function createAlertsForFindings(array $findings, AlertService $alertService, string $scanId): void
    {
        $criticalFindings = array_filter($findings, fn ($f) => $f['severity'] === 'critical');
        $highFindings = array_filter($findings, fn ($f) => $f['severity'] === 'high');

        // Create summary alert for critical findings
        if (! empty($criticalFindings)) {
            $alertService->createAlert([
                'type' => 'security',
                'severity' => 'critical',
                'title' => "Critical Security Vulnerabilities Found - Scan {$scanId}",
                'description' => count($criticalFindings).' critical security vulnerabilities were detected during the security scan.',
                'metadata' => [
                    'scan_id' => $scanId,
                    'findings' => $criticalFindings,
                ],
            ]);
        }

        // Create summary alert for high findings
        if (! empty($highFindings)) {
            $alertService->createAlert([
                'type' => 'security',
                'severity' => 'high',
                'title' => "High Priority Security Issues Found - Scan {$scanId}",
                'description' => count($highFindings).' high priority security issues were detected during the security scan.',
                'metadata' => [
                    'scan_id' => $scanId,
                    'findings' => $highFindings,
                ],
            ]);
        }
    }

    /**
     * Handle job failure.
     */
    public function failed(\Throwable $exception): void
    {
        Log::critical('Security scan job failed permanently', [
            'type' => $this->scanType,
            'target' => $this->target,
            'error' => $exception->getMessage(),
            'trace' => $exception->getTraceAsString(),
        ]);
    }

    /**
     * Get the tags that should be assigned to the job.
     */
    public function tags(): array
    {
        return [
            'security',
            'scan',
            $this->scanType,
            $this->target,
        ];
    }
}
