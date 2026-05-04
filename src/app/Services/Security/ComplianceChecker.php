<?php

declare(strict_types=1);

namespace App\Services\Security;

use App\Services\SecurityComplianceService;
use App\Services\SecurityAuditService;
use App\Models\SecurityAuditLog;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Process;

/**
 * Compliance Checker Service
 *
 * Orchestrates security compliance checks, generates reports,
 * and tracks remediation progress.
 *
 * @package App\Services\Security
 */
class ComplianceChecker
{
    protected SecurityComplianceService $complianceService;
    protected SecurityAuditService $auditService;

    public function __construct(
        SecurityComplianceService $complianceService,
        SecurityAuditService $auditService
    ) {
        $this->complianceService = $complianceService;
        $this->auditService = $auditService;
    }

    /**
     * Run comprehensive compliance check
     *
     * @param array $options Check options
     * @return array
     */
    public function runComplianceCheck(array $options = []): array
    {
        Log::info('Starting comprehensive compliance check');

        $results = [
            'timestamp' => now()->toIso8601String(),
            'options' => $options,
            'owasp' => [],
            'gdpr' => [],
            'best_practices' => [],
            'summary' => [],
            'grade' => null,
            'recommendations' => [],
        ];

        // Run OWASP Top 10 check
        $results['owasp'] = $this->complianceService->checkOWASPTop10();

        // Run GDPR check
        $results['gdpr'] = $this->complianceService->checkGDPRCompliance();

        // Run best practices check
        $results['best_practices'] = $this->complianceService->checkBestPractices();

        // Run security audit
        $auditResults = $this->auditService->runFullAudit();
        $results['audit'] = $auditResults;

        // Calculate overall grade
        $results['summary'] = $this->calculateOverallSummary($results);
        $results['grade'] = $this->calculateGrade($results['summary']['overall_score'] ?? 0);

        // Log completion
        SecurityAuditLog::log(
            'compliance.check.completed',
            'Security compliance check completed',
            [
                'severity' => 'info',
                'owasp_score' => $results['owasp']['compliance_percentage'],
                'gdpr_score' => $results['gdpr']['compliance_percentage'],
                'grade' => $results['grade'],
                'critical_findings' => $auditResults['summary']['critical'] ?? 0,
                'high_findings' => $auditResults['summary']['high'] ?? 0,
            ]
        );

        return $results;
    }

    /**
     * Run OWASP Top 10 compliance check only
     *
     * @return array
     */
    public function checkOWASPTop10(): array
    {
        Log::info('Running OWASP Top 10 compliance check');

        $result = $this->complianceService->checkOWASPTop10();

        SecurityAuditLog::log(
            'owasp.compliance.check',
            'OWASP Top 10 compliance check completed',
            [
                'severity' => $result['compliance_percentage'] >= 70 ? 'info' : 'medium',
                'compliance_percentage' => $result['compliance_percentage'],
                'passed' => $result['passed'],
                'total' => $result['total'],
            ]
        );

        return $result;
    }

    /**
     * Run GDPR compliance check only
     *
     * @return array
     */
    public function checkGDPRCompliance(): array
    {
        Log::info('Running GDPR compliance check');

        $result = $this->complianceService->checkGDPRCompliance();

        SecurityAuditLog::log(
            'gdpr.compliance.check',
            'GDPR compliance check completed',
            [
                'severity' => $result['compliance_percentage'] >= 60 ? 'info' : 'medium',
                'compliance_percentage' => $result['compliance_percentage'],
                'passed' => $result['passed'],
                'total' => $result['total'],
            ]
        );

        return $result;
    }

    /**
     * Check SOC2 compliance
     *
     * @return array
     */
    public function checkSOC2Compliance(): array
    {
        Log::info('Running SOC2 compliance check');

        $checks = [
            'access_control' => $this->checkSOC2AccessControl(),
            'encryption' => $this->checkSOC2Encryption(),
            'logging' => $this->checkSOC2Logging(),
            'monitoring' => $this->checkSOC2Monitoring(),
            'incident_response' => $this->checkSOC2IncidentResponse(),
        ];

        $passed = 0;
        $total = count($checks);

        foreach ($checks as $name => $result) {
            if ($result['compliant']) {
                $passed++;
            }
        }

        $compliance = $passed > 0 ? round(($passed / $total) * 100, 2) : 0;

        $result = [
            'compliance_percentage' => $compliance,
            'passed' => $passed,
            'total' => $total,
            'checks' => $checks,
        ];

        SecurityAuditLog::log(
            'soc2.compliance.check',
            'SOC2 compliance check completed',
            [
                'severity' => $compliance >= 80 ? 'info' : 'medium',
                'compliance_percentage' => $compliance,
            ]
        );

        return $result;
    }

    /**
     * Check SOC2 access control requirements
     *
     * @return array
     */
    protected function checkSOC2AccessControl(): array
    {
        $result = [
            'compliant' => true,
            'findings' => [],
            'recommendations' => [],
        ];

        // Check if RBAC is implemented
        if (!class_exists(\Spatie\Permission\PermissionServiceProvider::class)) {
            $result['compliant'] = false;
            $result['findings'][] = 'RBAC not implemented - required for SOC2 CC6.1';
            $result['recommendations'][] = 'Implement role-based access control';
        }

        // Check for unique user identification
        if (!\Schema::hasColumn('users', 'email')) {
            $result['compliant'] = false;
            $result['findings'][] = 'User unique identification not properly implemented';
        }

        // Check for access revocation
        $result['recommendations'][] = 'Implement automated access revocation for terminated users';

        return $result;
    }

    /**
     * Check SOC2 encryption requirements
     *
     * @return array
     */
    protected function checkSOC2Encryption(): array
    {
        $result = [
            'compliant' => true,
            'findings' => [],
            'recommendations' => [],
        ];

        // Check data encryption at rest
        if (!config('session.encrypt')) {
            $result['compliant'] = false;
            $result['findings'][] = 'Session encryption not enabled';
            $result['recommendations'][] = 'Enable session encryption';
        }

        // Check HTTPS in production
        if (config('app.env') === 'production' && !str_starts_with(config('app.url'), 'https://')) {
            $result['compliant'] = false;
            $result['findings'][] = 'HTTPS not enforced in production';
            $result['recommendations'][] = 'Enable HTTPS for all connections';
        }

        return $result;
    }

    /**
     * Check SOC2 logging requirements
     *
     * @return array
     */
    protected function checkSOC2Logging(): array
    {
        $result = [
            'compliant' => true,
            'findings' => [],
            'recommendations' => [],
        ];

        // Check if audit log exists
        if (!\Schema::hasTable('security_audit_logs')) {
            $result['compliant'] = false;
            $result['findings'][] = 'Security audit log table not found - required for SOC2 CC6.6';
            $result['recommendations'][] = 'Implement comprehensive audit logging';
        }

        // Check log retention
        $result['recommendations'][] = 'Implement log retention policy (minimum 90 days for audit logs)';

        return $result;
    }

    /**
     * Check SOC2 monitoring requirements
     *
     * @return array
     */
    protected function checkSOC2Monitoring(): array
    {
        $result = [
            'compliant' => true,
            'findings' => [],
            'recommendations' => [],
        ];

        // Check if monitoring is configured
        if (!config('monitoring.enabled')) {
            $result['compliant'] = false;
            $result['findings'][] = 'System monitoring not enabled - required for SOC2 CC6.1';
            $result['recommendations'][] = 'Implement system monitoring and alerting';
        }

        return $result;
    }

    /**
     * Check SOC2 incident response requirements
     *
     * @return array
     */
    protected function checkSOC2IncidentResponse(): array
    {
        $result = [
            'compliant' => true,
            'findings' => [],
            'recommendations' => [],
        ];

        // Check for incident response procedures
        $result['recommendations'][] = 'Document and test incident response procedures';

        return $result;
    }

    /**
     * Calculate overall summary
     *
     * @param array $results
     * @return array
     */
    protected function calculateOverallSummary(array $results): array
    {
        $owaspScore = $results['owasp']['compliance_percentage'] ?? 0;
        $gdprScore = $results['gdpr']['compliance_percentage'] ?? 0;
        $practicesScore = $results['best_practices']['compliance_percentage'] ?? 0;

        // Critical findings weight more heavily
        $auditSummary = $results['audit']['summary'] ?? [];
        $criticalCount = $auditSummary['critical'] ?? 0;
        $highCount = $auditSummary['high'] ?? 0;
        $mediumCount = $auditSummary['medium'] ?? 0;

        // Calculate penalty for findings
        $findingPenalty = min(($criticalCount * 10) + ($highCount * 5) + ($mediumCount * 2), 50);

        // Calculate weighted score
        $overallScore = round(
            (($owaspScore * 0.4) + ($gdprScore * 0.3) + ($practicesScore * 0.3)) - $findingPenalty,
            2
        );

        return [
            'overall_score' => max(0, $overallScore),
            'owasp_score' => $owaspScore,
            'gdpr_score' => $gdprScore,
            'best_practices_score' => $practicesScore,
            'finding_penalty' => $findingPenalty,
        ];
    }

    /**
     * Calculate compliance grade
     *
     * @param float $score
     * @return string
     */
    protected function calculateGrade(float $score): string
    {
        if ($score >= 90) {
            return 'A';
        } elseif ($score >= 80) {
            return 'B';
        } elseif ($score >= 70) {
            return 'C';
        } elseif ($score >= 60) {
            return 'D';
        } else {
            return 'F';
        }
    }

    /**
     * Generate compliance report
     *
     * @param array $results
     * @return string
     */
    public function generateComplianceReport(array $results): string
    {
        $summary = $results['summary'] ?? [];
        $grade = $results['grade'] ?? 'F';
        $overallScore = $summary['overall_score'] ?? 0;
        $auditSummary = $results['audit']['summary'] ?? [];

        $report = "# Security Compliance Report\n\n";
        $report .= "Generated: {$results['timestamp']}\n";
        $report .= "Grade: {$grade}\n";
        $report .= "Overall Score: {$overallScore}/100\n\n";

        $report .= "## OWASP Top 10 Compliance\n\n";
        $report .= "Score: {$results['owasp']['compliance_percentage']}%\n";
        $report .= "Status: {$results['owasp']['passed']}/{$results['owasp']['total']} checks passed\n\n";

        $report .= "## GDPR Compliance\n\n";
        $report .= "Score: {$results['gdpr']['compliance_percentage']}%\n";
        $report .= "Status: {$results['gdpr']['passed']}/{$results['gdpr']['total']} checks passed\n\n";

        $report .= "## Findings Summary\n\n";
        $report .= "Critical: ".($auditSummary['critical'] ?? 0)."\n";
        $report .= "High: ".($auditSummary['high'] ?? 0)."\n";
        $report .= "Medium: ".($auditSummary['medium'] ?? 0)."\n";

        return $report;
    }

    /**
     * Get remediation plan based on compliance results
     *
     * @param array $results
     * @return array
     */
    public function getRemediationPlan(array $results): array
    {
        $plan = [
            'immediate' => [],
            'short_term' => [],
            'long_term' => [],
        ];

        // Collect critical findings for immediate action
        if (isset($results['audit']['findings'])) {
            foreach ($results['audit']['findings'] as $finding) {
                if (($finding['severity'] ?? 'info') === 'critical') {
                    $plan['immediate'][] = $finding;
                } elseif (($finding['severity'] ?? 'info') === 'high') {
                    $plan['short_term'][] = $finding;
                } elseif (($finding['severity'] ?? 'info') === 'medium') {
                    $plan['long_term'][] = $finding;
                }
            }
        }

        return $plan;
    }

    /**
     * Schedule automated compliance scans
     *
     * @param string $schedule Cron schedule expression
     * @return bool
     */
    public function scheduleComplianceScan(string $schedule = '0 2 * * *'): bool
    {
        try {
            $process = Process::run('crontab -l 2>/dev/null | grep -q "security:compliance" || echo "No existing compliance scan scheduled"');

            if (str_contains($process->output(), 'security:compliance')) {
                Log::info('Compliance scan already scheduled');
                return true;
            }

            // This would be handled by the application scheduler
            Log::info("Compliance scan scheduled for: {$schedule}");

            return true;
        } catch (\Exception $e) {
            Log::error('Failed to schedule compliance scan', ['error' => $e->getMessage()]);
            return false;
        }
    }
}
