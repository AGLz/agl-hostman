<?php

declare(strict_types=1);

namespace App\Services;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Process;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

/**
 * Security Audit Service
 *
 * Performs comprehensive security audits including vulnerability scans,
 * dependency checks, and security compliance verification.
 */
class SecurityAuditService
{
    private array $findings = [];

    private array $scores = [
        'critical' => 0,
        'high' => 0,
        'medium' => 0,
        'low' => 0,
        'info' => 0,
    ];

    /**
     * Run complete security audit
     */
    public function runFullAudit(): array
    {
        Log::info('Starting full security audit');

        $results = [
            'timestamp' => now()->toIso8601String(),
            'version' => config('app.version', '1.0.0'),
            'checks' => [],
            'findings' => [],
            'summary' => [],
        ];

        // Run all security checks
        $results['checks']['dependency_vulnerabilities'] = $this->checkDependencyVulnerabilities();
        $results['checks']['code_security'] = $this->auditCodeSecurity();
        $results['checks']['authentication'] = $this->auditAuthenticationSecurity();
        $results['checks']['authorization'] = $this->auditAuthorizationSecurity();
        $results['checks']['data_protection'] = $this->auditDataProtection();
        $results['checks']['api_security'] = $this->auditApiSecurity();
        $results['checks']['configuration'] = $this->auditConfigurationSecurity();
        $results['checks']['logging'] = $this->auditLoggingSecurity();

        // Compile findings
        $results['findings'] = $this->findings;

        // Calculate summary
        $results['summary'] = $this->calculateSummary();

        // Save audit report
        $this->saveAuditReport($results);

        Log::info('Security audit completed', $results['summary']);

        return $results;
    }

    /**
     * Check for dependency vulnerabilities
     */
    public function checkDependencyVulnerabilities(): array
    {
        Log::info('Checking dependency vulnerabilities');

        $result = [
            'status' => 'pass',
            'findings' => [],
            'details' => [],
        ];

        // Check PHP dependencies (Composer)
        $composerAudit = $this->runComposerAudit();
        $result['details']['composer'] = $composerAudit;

        if (! $composerAudit['pass']) {
            $result['status'] = 'fail';
            foreach ($composerAudit['vulnerabilities'] as $vuln) {
                $this->addFinding('critical', 'Dependency Vulnerability', $vuln['message']);
                $result['findings'][] = $vuln;
            }
        }

        // Check Node dependencies (npm)
        $npmAudit = $this->runNpmAudit();
        $result['details']['npm'] = $npmAudit;

        if (! $npmAudit['pass']) {
            $result['status'] = 'fail';
            foreach ($npmAudit['vulnerabilities'] as $vuln) {
                $severity = $vuln['severity'] === 'critical' ? 'critical' : 'high';
                $this->addFinding($severity, 'NPM Dependency Vulnerability', $vuln['message']);
                $result['findings'][] = $vuln;
            }
        }

        return $result;
    }

    /**
     * Run composer audit
     */
    private function runComposerAudit(): array
    {
        try {
            $process = Process::timeout(120)->run('composer audit --no-dev');

            $output = $process->output();
            $exitCode = $process->exitCode();

            if ($exitCode === 0) {
                return [
                    'pass' => true,
                    'message' => 'No vulnerabilities found in PHP dependencies',
                    'vulnerabilities' => [],
                ];
            }

            // Parse vulnerabilities
            $vulnerabilities = $this->parseComposerAuditOutput($output);

            return [
                'pass' => false,
                'message' => "Found {$vulnerabilities} vulnerabilities in PHP dependencies",
                'vulnerabilities' => $vulnerabilities,
            ];
        } catch (\Exception $e) {
            Log::error('Composer audit failed', ['error' => $e->getMessage()]);

            return [
                'pass' => false,
                'message' => 'Composer audit failed: '.$e->getMessage(),
                'vulnerabilities' => [],
            ];
        }
    }

    /**
     * Parse composer audit output
     */
    private function parseComposerAuditOutput(string $output): array
    {
        $vulnerabilities = [];
        $lines = explode("\n", $output);

        foreach ($lines as $line) {
            if (str_contains($line, 'Found')) {
                $vulnerabilities[] = [
                    'severity' => 'high',
                    'message' => trim($line),
                ];
            }
        }

        return $vulnerabilities;
    }

    /**
     * Run npm audit
     */
    private function runNpmAudit(): array
    {
        try {
            $process = Process::timeout(120)->run('npm audit --json');

            if (! $process->successful()) {
                $output = $process->output();
                $data = json_decode($output, true);

                if (! $data) {
                    return [
                        'pass' => false,
                        'message' => 'Failed to parse npm audit output',
                        'vulnerabilities' => [],
                    ];
                }

                $vulnerabilities = $data['metadata']['vulnerabilities'];
                $totalVulns = array_sum($vulnerabilities);

                if ($totalVulns === 0) {
                    return [
                        'pass' => true,
                        'message' => 'No vulnerabilities found in Node dependencies',
                        'vulnerabilities' => [],
                    ];
                }

                // Parse vulnerability details
                $vulnList = [];
                if (isset($data['vulnerabilities'])) {
                    foreach (array_slice($data['vulnerabilities'], 0, 10) as $name => $info) {
                        $vulnList[] = [
                            'severity' => $info['severity'],
                            'package' => $name,
                            'message' => "{$info['severity']}: {$name}",
                        ];
                    }
                }

                return [
                    'pass' => false,
                    'message' => "Found {$totalVulns} vulnerabilities in Node dependencies",
                    'vulnerabilities' => $vulnList,
                ];
            }

            return [
                'pass' => true,
                'message' => 'No vulnerabilities found in Node dependencies',
                'vulnerabilities' => [],
            ];
        } catch (\Exception $e) {
            Log::error('NPM audit failed', ['error' => $e->getMessage()]);

            return [
                'pass' => false,
                'message' => 'NPM audit failed: '.$e->getMessage(),
                'vulnerabilities' => [],
            ];
        }
    }

    /**
     * Audit code security
     */
    public function auditCodeSecurity(): array
    {
        Log::info('Auditing code security');

        $result = [
            'status' => 'pass',
            'findings' => [],
            'checks' => [],
        ];

        // Check for hardcoded secrets
        $result['checks']['hardcoded_secrets'] = $this->checkHardcodedSecrets();

        // Check for SQL injection risks
        $result['checks']['sql_injection'] = $this->checkSqlInjectionRisks();

        // Check for XSS vulnerabilities
        $result['checks']['xss_vulnerabilities'] = $this->checkXssVulnerabilities();

        // Check for insecure file handling
        $result['checks']['file_handling'] = $this->checkFileHandlingSecurity();

        // Check for insecure configurations
        $result['checks']['insecure_configs'] = $this->checkInsecureConfigurations();

        // Aggregate findings
        foreach ($result['checks'] as $checkName => $checkResult) {
            if ($checkResult['status'] === 'fail') {
                $result['status'] = 'fail';
                foreach ($checkResult['findings'] as $finding) {
                    $result['findings'][] = $finding;
                }
            }
        }

        return $result;
    }

    /**
     * Check for hardcoded secrets
     */
    public function checkHardcodedSecrets(): array
    {
        $result = [
            'status' => 'pass',
            'findings' => [],
        ];

        $patterns = [
            '/API_KEY\s*=\s*[\'"].+[\'"]/i',
            '/SECRET\s*=\s*[\'"].+[\'"]/i',
            '/PASSWORD\s*=\s*[\'"].+[\'"]/i',
            '/TOKEN\s*=\s*[\'"].+[\'"]/i',
            '/aws_access_key_id\s*=\s*[\'"].+[\'"]/i',
            '/aws_secret_access_key\s*=\s*[\'"].+[\'"]/i',
        ];

        $scanDirectories = ['app', 'config', 'routes'];

        foreach ($scanDirectories as $dir) {
            $files = $this->getPhpFiles($dir);

            foreach ($files as $file) {
                $content = file_get_contents($file);

                foreach ($patterns as $pattern) {
                    if (preg_match($pattern, $content)) {
                        $result['status'] = 'fail';
                        $result['findings'][] = [
                            'severity' => 'critical',
                            'file' => str_replace(base_path(), '', $file),
                            'message' => 'Potential hardcoded secret detected',
                        ];
                        $this->addFinding('critical', 'Hardcoded Secret', "Found in {$file}");
                    }
                }
            }
        }

        return $result;
    }

    /**
     * Check for SQL injection risks
     */
    public function checkSqlInjectionRisks(): array
    {
        $result = [
            'status' => 'pass',
            'findings' => [],
        ];

        // Look for raw SQL with user input concatenation
        $pattern = '/DB::(select|raw|statement)\([^)]*\$[^)]*\)/i';

        $files = $this->getPhpFiles('app');

        foreach ($files as $file) {
            $content = file_get_contents($file);

            if (preg_match($pattern, $content)) {
                $result['status'] = 'fail';
                $result['findings'][] = [
                    'severity' => 'critical',
                    'file' => str_replace(base_path(), '', $file),
                    'message' => 'Potential SQL injection vulnerability',
                ];
                $this->addFinding('critical', 'SQL Injection Risk', "Found in {$file}");
            }
        }

        return $result;
    }

    /**
     * Check for XSS vulnerabilities
     */
    public function checkXssVulnerabilities(): array
    {
        $result = [
            'status' => 'pass',
            'findings' => [],
        ];

        // Look for unescaped output
        $patterns = [
            '/\{\{\s*\$[a-zA-Z_]+\s*\}\}/', // Blade without |e
            '/<[^>]*>\s*\$[a-zA-Z_]+\s*<[^>]*>/',
        ];

        $files = $this->getPhpFiles('resources');

        foreach ($files as $file) {
            $content = file_get_contents($file);

            foreach ($patterns as $pattern) {
                if (preg_match($pattern, $content)) {
                    $result['status'] = 'fail';
                    $result['findings'][] = [
                        'severity' => 'high',
                        'file' => str_replace(base_path(), '', $file),
                        'message' => 'Potential XSS vulnerability - unescaped output',
                    ];
                    $this->addFinding('high', 'XSS Vulnerability', "Found in {$file}");
                }
            }
        }

        return $result;
    }

    /**
     * Check file handling security
     */
    public function checkFileHandlingSecurity(): array
    {
        $result = [
            'status' => 'pass',
            'findings' => [],
        ];

        // Look for unsafe file operations
        $patterns = [
            '/file_get_contents\s*\(\s*\$[a-zA-Z_]+\s*\)/i',
            '/file_put_contents\s*\(\s*\$[a-zA-Z_]+\s*,/i',
            '/include\s*\(\s*\$[a-zA-Z_]+\s*\)/i',
            '/require\s*\(\s*\$[a-zA-Z_]+\s*\)/i',
        ];

        $files = $this->getPhpFiles('app');

        foreach ($files as $file) {
            $content = file_get_contents($file);

            foreach ($patterns as $pattern) {
                if (preg_match($pattern, $content)) {
                    $result['status'] = 'fail';
                    $result['findings'][] = [
                        'severity' => 'critical',
                        'file' => str_replace(base_path(), '', $file),
                        'message' => 'Unsafe file operation - potential path traversal vulnerability',
                    ];
                    $this->addFinding('critical', 'Path Traversal Risk', "Found in {$file}");
                }
            }
        }

        return $result;
    }

    /**
     * Check for insecure configurations
     */
    public function checkInsecureConfigurations(): array
    {
        $result = [
            'status' => 'pass',
            'findings' => [],
        ];

        // Check debug mode
        if (config('app.debug')) {
            $result['status'] = 'fail';
            $result['findings'][] = [
                'severity' => 'high',
                'message' => 'Debug mode is enabled in production',
            ];
            $this->addFinding('high', 'Insecure Configuration', 'Debug mode enabled');
        }

        // Check app key
        if (config('app.key') === 'base64:your-key-here' || Str::length(config('app.key')) < 32) {
            $result['status'] = 'fail';
            $result['findings'][] = [
                'severity' => 'critical',
                'message' => 'Weak or default APP_KEY detected',
            ];
            $this->addFinding('critical', 'Weak APP_KEY', 'APP_KEY must be changed');
        }

        // Check cache security
        if (config('cache.default') === 'file') {
            $result['findings'][] = [
                'severity' => 'medium',
                'message' => 'Using file cache driver - consider Redis for better security',
            ];
            $this->addFinding('medium', 'Cache Configuration', 'Consider using Redis');
        }

        return $result;
    }

    /**
     * Audit authentication security
     */
    public function auditAuthenticationSecurity(): array
    {
        Log::info('Auditing authentication security');

        $result = [
            'status' => 'pass',
            'findings' => [],
            'checks' => [],
        ];

        // Check password requirements
        $result['checks']['password_policy'] = $this->checkPasswordPolicy();

        // Check session configuration
        $result['checks']['session_config'] = $this->checkSessionConfiguration();

        // Check 2FA availability
        $result['checks']['two_factor'] = $this->checkTwoFactorAvailability();

        // Check rate limiting on auth
        $result['checks']['auth_rate_limiting'] = $this->checkAuthRateLimiting();

        // Aggregate findings
        foreach ($result['checks'] as $checkName => $checkResult) {
            if ($checkResult['status'] === 'fail') {
                $result['status'] = 'fail';
                foreach ($checkResult['findings'] as $finding) {
                    $result['findings'][] = $finding;
                }
            }
        }

        return $result;
    }

    /**
     * Check password policy
     */
    public function checkPasswordPolicy(): array
    {
        $result = [
            'status' => 'pass',
            'findings' => [],
        ];

        // Check if StrongPassword rule is being used
        $files = $this->getPhpFiles('app/Http/Requests');

        $hasStrongPassword = false;
        foreach ($files as $file) {
            $content = file_get_contents($file);
            if (str_contains($content, 'StrongPassword')) {
                $hasStrongPassword = true;
                break;
            }
        }

        if (! $hasStrongPassword) {
            $result['status'] = 'fail';
            $result['findings'][] = [
                'severity' => 'medium',
                'message' => 'Strong password requirements not enforced',
            ];
            $this->addFinding('medium', 'Password Policy', 'Implement strong password requirements');
        }

        return $result;
    }

    /**
     * Check session configuration
     */
    public function checkSessionConfiguration(): array
    {
        $result = [
            'status' => 'pass',
            'findings' => [],
        ];

        $lifetime = config('session.lifetime');
        $expireOnClose = config('session.expire_on_close');

        if ($lifetime > 120 && ! $expireOnClose) {
            $result['findings'][] = [
                'severity' => 'medium',
                'message' => "Session lifetime is {$lifetime} minutes - consider reducing to 120 minutes",
            ];
            $this->addFinding('medium', 'Session Lifetime', 'Reduce session lifetime');
        }

        if (config('session.secure') === false && config('app.env') === 'production') {
            $result['status'] = 'fail';
            $result['findings'][] = [
                'severity' => 'critical',
                'message' => 'SESSION_SECURE=false in production - sessions not sent over HTTPS only',
            ];
            $this->addFinding('critical', 'Session Security', 'Enable SESSION_SECURE');
        }

        if (config('session.http_only') === false) {
            $result['status'] = 'fail';
            $result['findings'][] = [
                'severity' => 'high',
                'message' => 'SESSION_HTTP_ONLY=false - cookies accessible via JavaScript',
            ];
            $this->addFinding('high', 'Cookie Security', 'Enable SESSION_HTTP_ONLY');
        }

        if (config('session.same_site') !== 'lax' && config('session.same_site') !== 'strict') {
            $result['status'] = 'fail';
            $result['findings'][] = [
                'severity' => 'high',
                'message' => 'SESSION_SAME_SITE not set to lax or strict - CSRF risk',
            ];
            $this->addFinding('high', 'CSRF Protection', 'Set SESSION_SAME_SITE to lax or strict');
        }

        return $result;
    }

    /**
     * Check 2FA availability
     */
    public function checkTwoFactorAvailability(): array
    {
        $result = [
            'status' => 'pass',
            'findings' => [],
        ];

        // Check if 2FA is implemented
        $hasTwoFactor = false;

        // Check for WorkOS 2FA
        if (config('services.workos.enabled') && file_exists(app_path('Services/WorkOsService.php'))) {
            $content = file_get_contents(app_path('Services/WorkOsService.php'));
            if (str_contains($content, 'MFA') || str_contains($content, 'twoFactor')) {
                $hasTwoFactor = true;
            }
        }

        if (! $hasTwoFactor) {
            $result['findings'][] = [
                'severity' => 'medium',
                'message' => 'Two-factor authentication not implemented for sensitive operations',
            ];
            $this->addFinding('medium', '2FA', 'Consider implementing 2FA for admin accounts');
        }

        return $result;
    }

    /**
     * Check auth rate limiting
     */
    public function checkAuthRateLimiting(): array
    {
        $result = [
            'status' => 'pass',
            'findings' => [],
        ];

        // Check if rate limiting is applied to auth routes
        $routesFile = base_path('routes/api.php');
        if (file_exists($routesFile)) {
            $content = file_get_contents($routesFile);

            if (! str_contains($content, 'throttle:auth')) {
                $result['status'] = 'fail';
                $result['findings'][] = [
                    'severity' => 'high',
                    'message' => 'Authentication routes not rate limited',
                ];
                $this->addFinding('high', 'Auth Rate Limiting', 'Apply rate limiting to auth routes');
            }
        }

        return $result;
    }

    /**
     * Audit authorization security
     */
    public function auditAuthorizationSecurity(): array
    {
        Log::info('Auditing authorization security');

        $result = [
            'status' => 'pass',
            'findings' => [],
            'checks' => [],
        ];

        // Check RBAC implementation
        $result['checks']['rbac'] = $this->checkRBACImplementation();

        // Check policy usage
        $result['checks']['policies'] = $this->checkPolicyUsage();

        // Check middleware protection
        $result['checks']['middleware'] = $this->checkMiddlewareProtection();

        // Aggregate findings
        foreach ($result['checks'] as $checkName => $checkResult) {
            if ($checkResult['status'] === 'fail') {
                $result['status'] = 'fail';
                foreach ($checkResult['findings'] as $finding) {
                    $result['findings'][] = $finding;
                }
            }
        }

        return $result;
    }

    /**
     * Check RBAC implementation
     */
    public function checkRBACImplementation(): array
    {
        $result = [
            'status' => 'pass',
            'findings' => [],
        ];

        // Check if Spatie Permission is installed
        if (! class_exists(\Spatie\Permission\PermissionServiceProvider::class)) {
            $result['status'] = 'fail';
            $result['findings'][] = [
                'severity' => 'high',
                'message' => 'Spatie Permission not installed - no RBAC implementation',
            ];
            $this->addFinding('high', 'RBAC', 'Install and configure Spatie Permission');

            return $result;
        }

        if (! Schema::hasTable('roles')) {
            $result['status'] = 'fail';
            $result['findings'][] = [
                'severity' => 'high',
                'message' => 'Roles table not found in database',
            ];
            $this->addFinding('high', 'RBAC', 'Run permission migrations before auditing RBAC');

            return $result;
        }

        // Check if roles are defined
        $roles = DB::table('roles')->count();
        if ($roles === 0) {
            $result['status'] = 'fail';
            $result['findings'][] = [
                'severity' => 'high',
                'message' => 'No roles defined in database',
            ];
            $this->addFinding('high', 'RBAC', 'Define roles and permissions');
        }

        return $result;
    }

    /**
     * Check policy usage
     */
    public function checkPolicyUsage(): array
    {
        $result = [
            'status' => 'pass',
            'findings' => [],
        ];

        // Check if policies exist
        $policyFiles = glob(app_path('Policies/*.php'));

        if (empty($policyFiles)) {
            $result['findings'][] = [
                'severity' => 'medium',
                'message' => 'No authorization policies found',
            ];
            $this->addFinding('medium', 'Authorization', 'Implement authorization policies');
        }

        return $result;
    }

    /**
     * Check middleware protection
     */
    public function checkMiddlewareProtection(): array
    {
        $result = [
            'status' => 'pass',
            'findings' => [],
        ];

        // Check if authentication is required for API routes
        $apiRoutesFile = base_path('routes/api.php');
        if (file_exists($apiRoutesFile)) {
            $content = file_get_contents($apiRoutesFile);

            // Look for unprotected routes
            $hasAuthMiddleware = str_contains($content, 'auth:api') || str_contains($content, 'auth:sanctum');

            if (! $hasAuthMiddleware) {
                $result['status'] = 'fail';
                $result['findings'][] = [
                    'severity' => 'critical',
                    'message' => 'API routes missing authentication middleware',
                ];
                $this->addFinding('critical', 'API Authentication', 'Apply authentication middleware to API routes');
            }
        }

        return $result;
    }

    /**
     * Audit data protection
     */
    public function auditDataProtection(): array
    {
        Log::info('Auditing data protection');

        $result = [
            'status' => 'pass',
            'findings' => [],
            'checks' => [],
        ];

        // Check encryption at rest
        $result['checks']['encryption_at_rest'] = $this->checkEncryptionAtRest();

        // Check TLS/HTTPS
        $result['checks']['tls_configuration'] = $this->checkTLSConfiguration();

        // Check logging security
        $result['checks']['logging_security'] = $this->checkLoggingSecurity();

        // Aggregate findings
        foreach ($result['checks'] as $checkName => $checkResult) {
            if ($checkResult['status'] === 'fail') {
                $result['status'] = 'fail';
                foreach ($checkResult['findings'] as $finding) {
                    $result['findings'][] = $finding;
                }
            }
        }

        return $result;
    }

    /**
     * Check encryption at rest
     */
    public function checkEncryptionAtRest(): array
    {
        $result = [
            'status' => 'pass',
            'findings' => [],
        ];

        // Check database encryption
        if (config('database.default') === 'mysql' || config('database.default') === 'pgsql') {
            // Check for SSL requirements
            $sslEnabled = config('database.connections.'.config('database.default').'.options.'.PDO::MYSQL_ATTR_SSL_CA);

            if (! $sslEnabled && config('app.env') === 'production') {
                $result['findings'][] = [
                    'severity' => 'medium',
                    'message' => 'Database SSL not enabled - data not encrypted in transit',
                ];
                $this->addFinding('medium', 'Database Encryption', 'Enable database SSL');
            }
        }

        return $result;
    }

    /**
     * Check TLS configuration
     */
    public function checkTLSConfiguration(): array
    {
        $result = [
            'status' => 'pass',
            'findings' => [],
        ];

        // Check if URL is forced to HTTPS
        if (config('app.env') === 'production') {
            if (! str_starts_with(config('app.url'), 'https://')) {
                $result['status'] = 'fail';
                $result['findings'][] = [
                    'severity' => 'critical',
                    'message' => 'APP_URL not using HTTPS in production',
                ];
                $this->addFinding('critical', 'TLS', 'Use HTTPS for APP_URL');
            }
        }

        return $result;
    }

    /**
     * Check logging security
     */
    public function checkLoggingSecurity(): array
    {
        $result = [
            'status' => 'pass',
            'findings' => [],
        ];

        // Check if logs contain sensitive data
        $logFile = storage_path('logs/laravel.log');

        if (file_exists($logFile)) {
            $content = file_get_contents($logFile);

            // Check for sensitive patterns
            $patterns = [
                '/password["\']?\s*=>\s*["\']?[^"\'>]+/i',
                '/token["\']?\s*=>\s*["\']?[^"\'>]+/i',
                '/api_key["\']?\s*=>\s*["\']?[^"\'>]+/i',
            ];

            foreach ($patterns as $pattern) {
                if (preg_match($pattern, $content)) {
                    $result['status'] = 'fail';
                    $result['findings'][] = [
                        'severity' => 'high',
                        'message' => 'Logs may contain sensitive data',
                    ];
                    $this->addFinding('high', 'Logging Security', 'Review and clean logs');
                    break;
                }
            }
        }

        return $result;
    }

    /**
     * Audit API security
     */
    public function auditApiSecurity(): array
    {
        Log::info('Auditing API security');

        $result = [
            'status' => 'pass',
            'findings' => [],
            'checks' => [],
        ];

        // Check rate limiting
        $result['checks']['rate_limiting'] = $this->checkAPIRateLimiting();

        // Check authentication
        $result['checks']['authentication'] = $this->checkAPIAuthentication();

        // Check input validation
        $result['checks']['validation'] = $this->checkAPIValidation();

        // Check CORS configuration
        $result['checks']['cors'] = $this->checkCORSConfiguration();

        // Aggregate findings
        foreach ($result['checks'] as $checkName => $checkResult) {
            if ($checkResult['status'] === 'fail') {
                $result['status'] = 'fail';
                foreach ($checkResult['findings'] as $finding) {
                    $result['findings'][] = $finding;
                }
            }
        }

        return $result;
    }

    /**
     * Check API rate limiting
     */
    public function checkAPIRateLimiting(): array
    {
        $result = [
            'status' => 'pass',
            'findings' => [],
        ];

        // Check if rate limiting middleware is applied
        $appFile = base_path('bootstrap/app.php');
        if (file_exists($appFile)) {
            $content = file_get_contents($appFile);

            if (! str_contains($content, 'RateLimiting')) {
                $result['status'] = 'fail';
                $result['findings'][] = [
                    'severity' => 'high',
                    'message' => 'Rate limiting middleware not registered',
                ];
                $this->addFinding('high', 'API Rate Limiting', 'Register rate limiting middleware');
            }
        }

        return $result;
    }

    /**
     * Check API authentication
     */
    public function checkAPIAuthentication(): array
    {
        $result = [
            'status' => 'pass',
            'findings' => [],
        ];

        // Check if routes require authentication
        $apiRoutesFile = base_path('routes/api.php');
        if (file_exists($apiRoutesFile)) {
            $content = file_get_contents($apiRoutesFile);

            if (! str_contains($content, 'auth:api') && ! str_contains($content, 'auth:sanctum')) {
                $result['status'] = 'fail';
                $result['findings'][] = [
                    'severity' => 'critical',
                    'message' => 'API routes missing authentication',
                ];
                $this->addFinding('critical', 'API Authentication', 'Require authentication for API routes');
            }
        }

        return $result;
    }

    /**
     * Check API validation
     */
    public function checkAPIValidation(): array
    {
        $result = [
            'status' => 'pass',
            'findings' => [],
        ];

        // Check if form requests are used
        $requestFiles = glob(app_path('Http/Requests/*Request.php'));

        if (empty($requestFiles)) {
            $result['status'] = 'fail';
            $result['findings'][] = [
                'severity' => 'high',
                'message' => 'No Form Request validators found',
            ];
            $this->addFinding('high', 'API Validation', 'Implement Form Request validators');
        }

        return $result;
    }

    /**
     * Check CORS configuration
     */
    public function checkCORSConfiguration(): array
    {
        $result = [
            'status' => 'pass',
            'findings' => [],
        ];

        $corsConfig = config('cors');

        if (empty($corsConfig) || $corsConfig['paths'] === ['*']) {
            $result['findings'][] = [
                'severity' => 'medium',
                'message' => 'CORS configured to allow all paths',
            ];
            $this->addFinding('medium', 'CORS Configuration', 'Restrict CORS paths');
        }

        if ($corsConfig['allowed_origins'] === ['*'] && config('app.env') === 'production') {
            $result['status'] = 'fail';
            $result['findings'][] = [
                'severity' => 'high',
                'message' => 'CORS allows all origins in production',
            ];
            $this->addFinding('high', 'CORS Security', 'Restrict allowed origins');
        }

        return $result;
    }

    /**
     * Audit configuration security
     */
    public function auditConfigurationSecurity(): array
    {
        Log::info('Auditing configuration security');

        $result = [
            'status' => 'pass',
            'findings' => [],
            'checks' => [],
        ];

        // Check environment variables
        $result['checks']['env_variables'] = $this->checkEnvironmentVariables();

        // Check sensitive configs
        $result['checks']['sensitive_configs'] = $this->checkSensitiveConfigs();

        // Aggregate findings
        foreach ($result['checks'] as $checkName => $checkResult) {
            if ($checkResult['status'] === 'fail') {
                $result['status'] = 'fail';
                foreach ($checkResult['findings'] as $finding) {
                    $result['findings'][] = $finding;
                }
            }
        }

        return $result;
    }

    /**
     * Check environment variables
     */
    public function checkEnvironmentVariables(): array
    {
        $result = [
            'status' => 'pass',
            'findings' => [],
        ];

        // Check for default values
        $defaults = [
            'APP_KEY' => 'base64:your-key-here',
            'APP_URL' => 'http://localhost',
            'DB_PASSWORD' => '',
        ];

        foreach ($defaults as $key => $default) {
            $value = env($key);
            if ($value === $default || $value === null) {
                $result['status'] = 'fail';
                $result['findings'][] = [
                    'severity' => 'critical',
                    'message' => "Environment variable {$key} has default or empty value",
                ];
                $this->addFinding('critical', 'Environment Configuration', "Set {$key}");
            }
        }

        return $result;
    }

    /**
     * Check sensitive configs
     */
    public function checkSensitiveConfigs(): array
    {
        $result = [
            'status' => 'pass',
            'findings' => [],
        ];

        // Check if sensitive files are not in version control
        $sensitiveFiles = [
            '.env',
            '.env.production',
            'database/database.sqlite',
        ];

        foreach ($sensitiveFiles as $file) {
            if (file_exists(base_path($file.'.git')) || file_exists(base_path($file))) {
                // Check gitignore
                $gitignore = file_get_contents(base_path('.gitignore'));
                if (! str_contains($gitignore, $file)) {
                    $result['findings'][] = [
                        'severity' => 'high',
                        'message' => "Sensitive file {$file} not in .gitignore",
                    ];
                    $this->addFinding('high', 'Git Security', "Add {$file} to .gitignore");
                }
            }
        }

        return $result;
    }

    /**
     * Audit logging security
     */
    public function auditLoggingSecurity(): array
    {
        Log::info('Auditing logging security');

        $result = [
            'status' => 'pass',
            'findings' => [],
            'checks' => [],
        ];

        // Check log channel configuration
        $result['checks']['log_channels'] = $this->checkLogChannels();

        // Check audit log availability
        $result['checks']['audit_logging'] = $this->checkAuditLogging();

        // Aggregate findings
        foreach ($result['checks'] as $checkName => $checkResult) {
            if ($checkResult['status'] === 'fail') {
                $result['status'] = 'fail';
                foreach ($checkResult['findings'] as $finding) {
                    $result['findings'][] = $finding;
                }
            }
        }

        return $result;
    }

    /**
     * Check log channels
     */
    public function checkLogChannels(): array
    {
        $result = [
            'status' => 'pass',
            'findings' => [],
        ];

        $defaultChannel = config('logging.default');

        if ($defaultChannel === 'stack' && config('app.env') === 'production') {
            $result['findings'][] = [
                'severity' => 'medium',
                'message' => 'Using stack log channel - consider using dedicated channel in production',
            ];
            $this->addFinding('medium', 'Logging Configuration', 'Use dedicated log channel');
        }

        return $result;
    }

    /**
     * Check audit logging
     */
    public function checkAuditLogging(): array
    {
        $result = [
            'status' => 'pass',
            'findings' => [],
        ];

        // Check if audit log table exists
        $hasAuditLog = Schema::hasTable('audit_logs');

        if (! $hasAuditLog) {
            $result['findings'][] = [
                'severity' => 'medium',
                'message' => 'Audit logging not implemented',
            ];
            $this->addFinding('medium', 'Audit Logging', 'Implement audit logging for sensitive operations');
        }

        return $result;
    }

    /**
     * Add finding
     */
    private function addFinding(string $severity, string $category, string $message): void
    {
        $this->findings[] = [
            'severity' => $severity,
            'category' => $category,
            'message' => $message,
            'timestamp' => now()->toIso8601String(),
        ];

        $this->scores[$severity]++;
    }

    /**
     * Calculate summary
     */
    private function calculateSummary(): array
    {
        $totalFindings = array_sum($this->scores);

        // Calculate grade
        $criticalWeight = 10;
        $highWeight = 5;
        $mediumWeight = 2;
        $lowWeight = 1;
        $infoWeight = 0;

        $score = (
            $this->scores['critical'] * $criticalWeight +
            $this->scores['high'] * $highWeight +
            $this->scores['medium'] * $mediumWeight +
            $this->scores['low'] * $lowWeight
        );

        if ($this->scores['critical'] > 0) {
            $grade = 'F';
        } elseif ($this->scores['high'] > 2) {
            $grade = 'D';
        } elseif ($this->scores['high'] > 0 || $this->scores['medium'] > 5) {
            $grade = 'C';
        } elseif ($this->scores['medium'] > 2) {
            $grade = 'B';
        } else {
            $grade = 'A';
        }

        return [
            'total_findings' => $totalFindings,
            'critical' => $this->scores['critical'],
            'high' => $this->scores['high'],
            'medium' => $this->scores['medium'],
            'low' => $this->scores['low'],
            'info' => $this->scores['info'],
            'score' => $score,
            'grade' => $grade,
        ];
    }

    /**
     * Save audit report
     */
    private function saveAuditReport(array $results): void
    {
        $filename = 'security-audit-'.now()->format('Y-m-d-His').'.json';
        $path = 'security-audits/'.$filename;

        Storage::disk('local')->put($path, json_encode($results, JSON_PRETTY_PRINT));

        Log::info('Security audit report saved', ['path' => $path]);
    }

    /**
     * Get PHP files from directory
     */
    private function getPhpFiles(string $directory): array
    {
        $files = [];
        $dir = base_path($directory);

        if (! is_dir($dir)) {
            return $files;
        }

        $iterator = new \RecursiveIteratorIterator(
            new \RecursiveDirectoryIterator($dir, \RecursiveDirectoryIterator::SKIP_DOTS),
            \RecursiveIteratorIterator::SELF_FIRST
        );

        foreach ($iterator as $file) {
            if ($file->isFile() && $file->getExtension() === 'php') {
                $files[] = $file->getPathname();
            }
        }

        return $files;
    }
}
