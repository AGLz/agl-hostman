<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Services\SecurityAuditService;
use App\Services\SecurityComplianceService;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\File;

/**
 * Security Audit Command
 *
 * Runs comprehensive security audit and compliance checks.
 *
 * @package App\Console\Commands
 */
class SecurityAuditCommand extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'security:audit
                            {--type=full : Audit type (full, quick, dependencies, code, compliance)}
                            {--output=console : Output format (console, json, file)}
                            {--path= : Custom path for file output}
                            {--fix : Automatically fix some issues}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Run security audit and compliance checks';

    /**
     * The security audit service instance.
     *
     * @var SecurityAuditService
     */
    protected SecurityAuditService $auditService;

    /**
     * The security compliance service instance.
     *
     * @var SecurityComplianceService
     */
    protected SecurityComplianceService $complianceService;

    /**
     * Create a new command instance.
     *
     * @param SecurityAuditService $auditService
     * @param SecurityComplianceService $complianceService
     * @return void
     */
    public function __construct(
        SecurityAuditService $auditService,
        SecurityComplianceService $complianceService
    ) {
        parent::__construct();

        $this->auditService = $auditService;
        $this->complianceService = $complianceService;
    }

    /**
     * Execute the console command.
     *
     * @return int
     */
    public function handle(): int
    {
        $this->info('🔒 Starting Security Audit...');
        $this->newLine();

        $type = $this->option('type');
        $output = $this->option('output');

        try {
            switch ($type) {
                case 'quick':
                    $results = $this->runQuickAudit();
                    break;
                case 'dependencies':
                    $results = $this->runDependencyAudit();
                    break;
                case 'code':
                    $results = $this->runCodeAudit();
                    break;
                case 'compliance':
                    $results = $this->runComplianceCheck();
                    break;
                case 'full':
                default:
                    $results = $this->runFullAudit();
                    break;
            }

            // Output results
            $this->outputResults($results, $output);

            // Auto-fix if requested
            if ($this->option('fix')) {
                $this->autoFixIssues($results);
            }

            $this->newLine();
            $this->info('✅ Security audit completed!');

            return Command::SUCCESS;
        } catch (\Exception $e) {
            $this->error('❌ Security audit failed: ' . $e->getMessage());

            return Command::FAILURE;
        }
    }

    /**
     * Run full security audit
     *
     * @return array
     */
    protected function runFullAudit(): array
    {
        $this->info('Running full security audit...');

        $auditResults = $this->auditService->runFullAudit();
        $complianceResults = $this->complianceService->runComplianceCheck();

        return [
            'type' => 'full',
            'audit' => $auditResults,
            'compliance' => $complianceResults,
            'timestamp' => now()->toIso8601String(),
        ];
    }

    /**
     * Run quick audit
     *
     * @return array
     */
    protected function runQuickAudit(): array
    {
        $this->info('Running quick security audit...');

        $this->task('Checking dependencies', function () {
            return $this->auditService->checkDependencyVulnerabilities();
        });

        $this->task('Checking configuration', function () {
            return $this->auditService->auditConfigurationSecurity();
        });

        $this->task('Checking authentication', function () {
            return $this->auditService->auditAuthenticationSecurity();
        });

        return [
            'type' => 'quick',
            'timestamp' => now()->toIso8601String(),
            'message' => 'Quick audit completed. Run full audit for detailed results.',
        ];
    }

    /**
     * Run dependency audit
     *
     * @return array
     */
    protected function runDependencyAudit(): array
    {
        $this->info('Running dependency vulnerability scan...');

        $results = $this->auditService->checkDependencyVulnerabilities();

        return [
            'type' => 'dependencies',
            'results' => $results,
            'timestamp' => now()->toIso8601String(),
        ];
    }

    /**
     * Run code audit
     *
     * @return array
     */
    protected function runCodeAudit(): array
    {
        $this->info('Running code security audit...');

        $results = $this->auditService->auditCodeSecurity();

        return [
            'type' => 'code',
            'results' => $results,
            'timestamp' => now()->toIso8601String(),
        ];
    }

    /**
     * Run compliance check
     *
     * @return array
     */
    protected function runComplianceCheck(): array
    {
        $this->info('Running compliance check...');

        $results = $this->complianceService->runComplianceCheck();

        return [
            'type' => 'compliance',
            'results' => $results,
            'timestamp' => now()->toIso8601String(),
        ];
    }

    /**
     * Output results
     *
     * @param array $results
     * @param string $output
     * @return void
     */
    protected function outputResults(array $results, string $output): void
    {
        switch ($output) {
            case 'json':
                $this->outputJson($results);
                break;
            case 'file':
                $this->outputFile($results);
                break;
            case 'console':
            default:
                $this->outputConsole($results);
                break;
        }
    }

    /**
     * Output to console
     *
     * @param array $results
     * @return void
     */
    protected function outputConsole(array $results): void
    {
        $this->newLine();
        $this->info('📊 AUDIT RESULTS');
        $this->newLine();

        if (isset($results['audit']['summary'])) {
            $summary = $results['audit']['summary'];

            $this->displaySummary($summary);
        }

        if (isset($results['compliance']['summary'])) {
            $this->newLine();
            $this->info('📋 COMPLIANCE RESULTS');
            $this->newLine();

            $this->displayCompliance($results['compliance']['summary']);
        }

        // Display findings
        if (isset($results['audit']['findings']) && !empty($results['audit']['findings'])) {
            $this->newLine();
            $this->warn('⚠️  SECURITY FINDINGS');
            $this->newLine();

            $this->displayFindings($results['audit']['findings']);
        }
    }

    /**
     * Display audit summary
     *
     * @param array $summary
     * @return void
     */
    protected function displaySummary(array $summary): void
    {
        $grade = $summary['grade'] ?? 'N/A';

        // Colorize grade
        $gradeColor = match ($grade) {
            'A' => 'green',
            'B' => 'blue',
            'C' => 'yellow',
            'D' => 'red',
            'F' => 'red',
            default => 'white',
        };

        $this->line("Security Grade: <fg={$gradeColor};options=bold>{$grade}</>");
        $this->newLine();

        $this->line("Total Findings: {$summary['total_findings']}");
        $this->line("<fg=red>  Critical: {$summary['critical']}</>");
        $this->line("<fg=yellow>  High: {$summary['high']}</>");
        $this->line("<fg=cyan>  Medium: {$summary['medium']}</>");
        $this->line("<fg=blue>  Low: {$summary['low']}</>");
        $this->line("<fg=gray>  Info: {$summary['info']}</>");
    }

    /**
     * Display compliance results
     *
     * @param array $summary
     * @return void
     */
    protected function displayCompliance(array $summary): void
    {
        $this->line("Overall Compliance: <fg={$this->getComplianceColor($summary['overall_compliance'])};options=bold>{$summary['overall_compliance']}%</> (Grade: {$summary['grade']})");
        $this->newLine();

        $this->line("OWASP Top 10: <fg={$this->getComplianceColor($summary['owasp_compliance'])}>{$summary['owasp_compliance']}%</>");
        $this->line("GDPR: <fg={$this->getComplianceColor($summary['gdpr_compliance'])}>{$summary['gdpr_compliance']}%</>");
        $this->line("Best Practices: <fg={$this->getComplianceColor($summary['best_practices_compliance'])}>{$summary['best_practices_compliance']}%</>");
    }

    /**
     * Get compliance color
     *
     * @param float $percentage
     * @return string
     */
    protected function getComplianceColor(float $percentage): string
    {
        return match (true) {
            $percentage >= 90 => 'green',
            $percentage >= 80 => 'blue',
            $percentage >= 70 => 'yellow',
            $percentage >= 60 => 'red',
            default => 'red',
        };
    }

    /**
     * Display findings
     *
     * @param array $findings
     * @return void
     */
    protected function displayFindings(array $findings): void
    {
        foreach ($findings as $finding) {
            $severity = $finding['severity'];
            $category = $finding['category'];
            $message = $finding['message'];

            $severityIcon = match ($severity) {
                'critical' => '🔴',
                'high' => '🟠',
                'medium' => '🟡',
                'low' => '🔵',
                'info' => '⚪',
                default => '⚪',
            };

            $severityColor = match ($severity) {
                'critical' => 'red',
                'high' => 'yellow',
                'medium' => 'cyan',
                'low' => 'blue',
                'info' => 'gray',
                default => 'white',
            };

            $this->line("{$severityIcon} <fg={$severityColor}>[{$category}]</> {$message}");
        }
    }

    /**
     * Output JSON
     *
     * @param array $results
     * @return void
     */
    protected function outputJson(array $results): void
    {
        $this->line(json_encode($results, JSON_PRETTY_PRINT));
    }

    /**
     * Output to file
     *
     * @param array $results
     * @return void
     */
    protected function outputFile(array $results): void
    {
        $path = $this->option('path') ?? storage_path('security-audit-' . now()->format('Y-m-d-His') . '.json');

        File::put($path, json_encode($results, JSON_PRETTY_PRINT));

        $this->info("Security audit report saved to: {$path}");
    }

    /**
     * Auto-fix issues
     *
     * @param array $results
     * @return void
     */
    protected function autoFixIssues(array $results): void
    {
        $this->newLine();
        $this->info('🔧 Attempting to auto-fix issues...');

        // Fix debug mode
        if (config('app.debug') && config('app.env') === 'production') {
            $this->task('Disable debug mode', function () {
                $envPath = base_path('.env');
                $envContent = File::get($envPath);
                $envContent = str_replace('APP_DEBUG=true', 'APP_DEBUG=false', $envContent);
                File::put($envPath, $envContent);

                return true;
            });
        }

        // Add APP_KEY to .gitignore if not present
        $gitignorePath = base_path('.gitignore');
        $gitignoreContent = File::get($gitignorePath);
        if (!str_contains($gitignoreContent, '.env')) {
            $this->task('Add .env to .gitignore', function () use ($gitignorePath, $gitignoreContent) {
                File::append($gitignorePath, "\n.env\n.env.*\n");
                return true;
            });
        }

        $this->info('✅ Auto-fix completed. Review changes and run audit again.');
    }
}
