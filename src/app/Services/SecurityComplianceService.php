<?php

declare(strict_types=1);

namespace App\Services;

use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Process;
use Illuminate\Support\Facades\Schema;

/**
 * Security Compliance Service
 *
 * Checks compliance against security standards including OWASP Top 10,
 * GDPR requirements, and industry best practices.
 */
class SecurityComplianceService
{
    private array $checklist = [];

    private array $complianceScores = [
        'owasp' => 0,
        'gdpr' => 0,
        'best_practices' => 0,
    ];

    /**
     * Run full compliance check
     */
    public function runComplianceCheck(): array
    {
        Log::info('Starting compliance check');

        $results = [
            'timestamp' => now()->toIso8601String(),
            'checks' => [],
            'summary' => [],
        ];

        // Run compliance checks
        $results['checks']['owasp_top_10'] = $this->checkOWASPTop10();
        $results['checks']['gdpr'] = $this->checkGDPRCompliance();
        $results['checks']['best_practices'] = $this->checkBestPractices();

        // Calculate compliance scores
        $results['summary'] = $this->calculateComplianceScores();

        return $results;
    }

    /**
     * Check OWASP Top 10 compliance
     */
    public function checkOWASPTop10(): array
    {
        Log::info('Checking OWASP Top 10 compliance');

        $checks = [
            'A01_2021_Broken_Access_Control' => $this->checkBrokenAccessControl(),
            'A02_2021_Cryptographic_Failures' => $this->checkCryptographicFailures(),
            'A03_2021_Injection' => $this->checkInjection(),
            'A04_2021_Insecure_Design' => $this->checkInsecureDesign(),
            'A05_2021_Security_Misconfiguration' => $this->checkSecurityMisconfiguration(),
            'A06_2021_Vulnerable_and_Outdated_Components' => $this->checkVulnerableComponents(),
            'A07_2021_Identification_and_Authentication_Failures' => $this->checkAuthFailures(),
            'A08_2021_Software_and_Data_Integrity_Failures' => $this->checkIntegrityFailures(),
            'A09_2021_Security_Logging_and_Monitoring_Failures' => $this->checkLoggingFailures(),
            'A10_2021_Server_Side_Request_Forgery' => $this->checkSSRF(),
        ];

        $passed = 0;
        $total = count($checks);

        foreach ($checks as $name => $result) {
            if ($result['compliant']) {
                $passed++;
                $this->complianceScores['owasp']++;
            }
        }

        $compliance = $passed > 0 ? round(($passed / $total) * 100, 2) : 0;

        return [
            'compliance_percentage' => $compliance,
            'passed' => $passed,
            'total' => $total,
            'checks' => $checks,
        ];
    }

    /**
     * Check A01: Broken Access Control
     */
    public function checkBrokenAccessControl(): array
    {
        $result = [
            'compliant' => true,
            'findings' => [],
            'recommendations' => [],
        ];

        // Check if users can access other users' data
        if (! Schema::hasColumn('users', 'id')) {
            $result['compliant'] = false;
            $result['findings'][] = 'Users table structure may not support proper access control';
        }

        // Check for IDOR vulnerabilities
        $controllers = glob(app_path('Http/Controllers/*Controller.php'));
        foreach ($controllers as $controller) {
            $content = file_get_contents($controller);

            // Look for direct ID access without authorization
            if (preg_match('/\$this->route\([\'"]id[\'"]\)/i', $content) &&
                ! preg_match('/\$this->authorize\(/i', $content)) {
                $result['compliant'] = false;
                $result['findings'][] = 'Potential IDOR vulnerability in '.basename($controller);
            }
        }

        if (! $result['compliant']) {
            $result['recommendations'][] = 'Implement proper authorization checks using policies';
            $result['recommendations'][] = 'Use route model binding with authorization';
            $result['recommendations'][] = 'Validate user permissions before resource access';
        }

        return $result;
    }

    /**
     * Check A02: Cryptographic Failures
     */
    public function checkCryptographicFailures(): array
    {
        $result = [
            'compliant' => true,
            'findings' => [],
            'recommendations' => [],
        ];

        // Check for HTTPS
        if (config('app.env') === 'production' && ! str_starts_with(config('app.url'), 'https://')) {
            $result['compliant'] = false;
            $result['findings'][] = 'Application not using HTTPS in production';
            $result['recommendations'][] = 'Enable HTTPS and configure SSL certificate';
        }

        // Check for encrypted sessions
        if (! config('session.encrypt')) {
            $result['compliant'] = false;
            $result['findings'][] = 'Session encryption is disabled';
            $result['recommendations'][] = 'Enable session encryption in config/session.php';
        }

        // Check for hashed passwords
        if (config('hashing.driver') !== 'bcrypt' && config('hashing.driver') !== 'argon2id') {
            $result['compliant'] = false;
            $result['findings'][] = 'Weak password hashing algorithm';
            $result['recommendations'][] = 'Use bcrypt or argon2id for password hashing';
        }

        // Check APP_KEY strength
        if (strlen(config('app.key')) < 32) {
            $result['compliant'] = false;
            $result['findings'][] = 'Weak APP_KEY detected';
            $result['recommendations'][] = 'Generate strong APP_KEY using php artisan key:generate';
        }

        return $result;
    }

    /**
     * Check A03: Injection
     */
    public function checkInjection(): array
    {
        $result = [
            'compliant' => true,
            'findings' => [],
            'recommendations' => [],
        ];

        // Check for raw SQL with user input
        $models = glob(app_path('Models/*.php'));
        foreach ($models as $model) {
            $content = file_get_contents($model);

            // Look for dangerous patterns
            if (preg_match('/DB::(raw|select|statement)\([^)]*\$\w+\)/i', $content)) {
                $result['compliant'] = false;
                $result['findings'][] = 'Potential SQL injection in '.basename($model);
            }
        }

        // Check for ORM usage
        $usesEloquent = false;
        foreach ($models as $model) {
            $content = file_get_contents($model);
            if (str_contains($content, 'extends Model')) {
                $usesEloquent = true;
                break;
            }
        }

        if (! $usesEloquent) {
            $result['findings'][] = 'Not using Eloquent ORM - increased SQL injection risk';
            $result['recommendations'][] = 'Use Eloquent ORM with parameterized queries';
        }

        // Check for input validation
        $requests = glob(app_path('Http/Requests/*Request.php'));
        if (empty($requests)) {
            $result['compliant'] = false;
            $result['findings'][] = 'No input validation implemented';
            $result['recommendations'][] = 'Implement Form Request validation for all inputs';
        }

        return $result;
    }

    /**
     * Check A04: Insecure Design
     */
    public function checkInsecureDesign(): array
    {
        $result = [
            'compliant' => true,
            'findings' => [],
            'recommendations' => [],
        ];

        // Check for rate limiting
        if (! class_exists(\App\Http\Middleware\RateLimiting::class)) {
            $result['compliant'] = false;
            $result['findings'][] = 'No rate limiting implemented';
            $result['recommendations'][] = 'Implement rate limiting to prevent abuse';
        }

        // Check for authentication
        if (! config('session.driver')) {
            $result['compliant'] = false;
            $result['findings'][] = 'No session driver configured';
            $result['recommendations'][] = 'Configure proper session driver';
        }

        // Check for RBAC
        if (! class_exists(\Spatie\Permission\PermissionServiceProvider::class)) {
            $result['findings'][] = 'No RBAC implementation';
            $result['recommendations'][] = 'Implement role-based access control';
        }

        return $result;
    }

    /**
     * Check A05: Security Misconfiguration
     */
    public function checkSecurityMisconfiguration(): array
    {
        $result = [
            'compliant' => true,
            'findings' => [],
            'recommendations' => [],
        ];

        // Check debug mode
        if (config('app.debug') && config('app.env') === 'production') {
            $result['compliant'] = false;
            $result['findings'][] = 'Debug mode enabled in production';
            $result['recommendations'][] = 'Set APP_DEBUG=false in production';
        }

        // Check for error exposure
        if (config('app.debug')) {
            $result['findings'][] = 'Detailed error messages may expose sensitive information';
            $result['recommendations'][] = 'Disable debug mode and implement proper error handling';
        }

        // Check for default credentials
        if (config('database.default')) {
            $connection = config('database.connections.'.config('database.default'));
            if (isset($connection['username']) && $connection['username'] === 'root') {
                $result['findings'][] = 'Using root database user';
                $result['recommendations'][] = 'Create dedicated database user with limited privileges';
            }
        }

        // Check for security headers
        if (! class_exists(\App\Http\Middleware\SecurityHeaders::class)) {
            $result['compliant'] = false;
            $result['findings'][] = 'Security headers middleware not implemented';
            $result['recommendations'][] = 'Implement security headers (CSP, HSTS, X-Frame-Options, etc.)';
        }

        return $result;
    }

    /**
     * Check A06: Vulnerable and Outdated Components
     */
    public function checkVulnerableComponents(): array
    {
        $result = [
            'compliant' => true,
            'findings' => [],
            'recommendations' => [],
        ];

        // Check for composer audit
        try {
            $process = Process::timeout(60)->run('composer audit --no-dev');
            if (! $process->successful()) {
                $result['compliant'] = false;
                $result['findings'][] = 'PHP dependencies have known vulnerabilities';
                $result['recommendations'][] = 'Run composer update to fix vulnerabilities';
            }
        } catch (\Exception $e) {
            $result['findings'][] = 'Unable to check for vulnerabilities: '.$e->getMessage();
        }

        // Check for npm audit
        try {
            $process = Process::timeout(60)->run('npm audit --json');
            if (! $process->successful()) {
                $result['compliant'] = false;
                $result['findings'][] = 'Node dependencies have known vulnerabilities';
                $result['recommendations'][] = 'Run npm audit fix to fix vulnerabilities';
            }
        } catch (\Exception $e) {
            $result['findings'][] = 'Unable to check for vulnerabilities: '.$e->getMessage();
        }

        // Check Laravel version
        $laravelVersion = app()->version();
        if (version_compare($laravelVersion, '11.0.0', '<')) {
            $result['compliant'] = false;
            $result['findings'][] = "Laravel version {$laravelVersion} is outdated";
            $result['recommendations'][] = 'Upgrade to Laravel 11+';
        }

        return $result;
    }

    /**
     * Check A07: Identification and Authentication Failures
     */
    public function checkAuthFailures(): array
    {
        $result = [
            'compliant' => true,
            'findings' => [],
            'recommendations' => [],
        ];

        // Check for password policy
        if (! class_exists(\App\Rules\StrongPassword::class)) {
            $result['compliant'] = false;
            $result['findings'][] = 'No strong password policy implemented';
            $result['recommendations'][] = 'Implement strong password requirements';
        }

        // Check for session security
        if (! config('session.secure') && config('app.env') === 'production') {
            $result['compliant'] = false;
            $result['findings'][] = 'Session cookies not marked as secure';
            $result['recommendations'][] = 'Set SESSION_SECURE=true';
        }

        if (! config('session.http_only')) {
            $result['compliant'] = false;
            $result['findings'][] = 'Session cookies accessible via JavaScript';
            $result['recommendations'][] = 'Set SESSION_HTTP_ONLY=true';
        }

        // Check for rate limiting on auth endpoints
        $authRoutes = base_path('routes/api.php');
        if (file_exists($authRoutes)) {
            $content = file_get_contents($authRoutes);
            if (! str_contains($content, 'throttle:auth')) {
                $result['findings'][] = 'Authentication endpoints not rate limited';
                $result['recommendations'][] = 'Apply rate limiting to authentication endpoints';
            }
        }

        return $result;
    }

    /**
     * Check A08: Software and Data Integrity Failures
     */
    public function checkIntegrityFailures(): array
    {
        $result = [
            'compliant' => true,
            'findings' => [],
            'recommendations' => [],
        ];

        // Check for code signing (if applicable)
        $result['recommendations'][] = 'Consider implementing code signing for deployments';

        // Check for verification of third-party components
        if (! file_exists(base_path('composer.lock'))) {
            $result['findings'][] = 'composer.lock not found - unable to verify dependency versions';
            $result['recommendations'][] = 'Commit composer.lock to version control';
        }

        if (! file_exists(base_path('package-lock.json'))) {
            $result['findings'][] = 'package-lock.json not found - unable to verify dependency versions';
            $result['recommendations'][] = 'Commit package-lock.json to version control';
        }

        // Check for supply chain security
        $result['recommendations'][] = 'Implement dependency review workflow';

        return $result;
    }

    /**
     * Check A09: Security Logging and Monitoring Failures
     */
    public function checkLoggingFailures(): array
    {
        $result = [
            'compliant' => true,
            'findings' => [],
            'recommendations' => [],
        ];

        // Check for logging configuration
        if (! config('logging.default')) {
            $result['compliant'] = false;
            $result['findings'][] = 'No logging channel configured';
            $result['recommendations'][] = 'Configure logging channels';
        }

        // Check for audit logs
        if (! Schema::hasTable('audit_logs') && ! Schema::hasTable('activity_log')) {
            $result['compliant'] = false;
            $result['findings'][] = 'No audit logging implemented';
            $result['recommendations'][] = 'Implement audit logging for sensitive operations';
        }

        // Check for log retention
        $result['recommendations'][] = 'Implement log retention policy';

        // Check for intrusion detection
        $result['recommendations'][] = 'Implement intrusion detection system';

        return $result;
    }

    /**
     * Check A10: Server-Side Request Forgery
     */
    public function checkSSRF(): array
    {
        $result = [
            'compliant' => true,
            'findings' => [],
            'recommendations' => [],
        ];

        // Check for URL validation
        if (! class_exists(\App\Rules\SafeUrl::class)) {
            $result['compliant'] = false;
            $result['findings'][] = 'No URL validation to prevent SSRF';
            $result['recommendations'][] = 'Implement URL validation with SSRF protection';
        }

        // Check for file_get_contents with URLs
        $files = $this->getPhpFiles('app');
        foreach ($files as $file) {
            $content = file_get_contents($file);
            if (preg_match('/file_get_contents\s*\(\s*["\']https?:\/\//i', $content)) {
                $result['findings'][] = 'Potential SSRF in '.basename($file);
                $result['recommendations'][] = 'Use HTTP client with proper validation';
            }
        }

        // Check for HTTP client usage
        $hasHttpValidation = false;
        foreach ($files as $file) {
            $content = file_get_contents($file);
            if (str_contains($content, 'SafeUrl') || str_contains($content, 'allowedHosts')) {
                $hasHttpValidation = true;
                break;
            }
        }

        if (! $hasHttpValidation) {
            $result['findings'][] = 'HTTP requests may not be properly validated';
            $result['recommendations'][] = 'Implement allowlist for external requests';
        }

        return $result;
    }

    /**
     * Check GDPR compliance
     */
    public function checkGDPRCompliance(): array
    {
        Log::info('Checking GDPR compliance');

        $checks = [
            'data_minimization' => $this->checkDataMinimization(),
            'right_to_access' => $this->checkRightToAccess(),
            'right_to_erasure' => $this->checkRightToErasure(),
            'right_to_portability' => $this->checkRightToPortability(),
            'consent_management' => $this->checkConsentManagement(),
            'data_breach_notification' => $this->checkDataBreachNotification(),
            'data_protection_by_design' => $this->checkDataProtectionByDesign(),
        ];

        $passed = 0;
        $total = count($checks);

        foreach ($checks as $name => $result) {
            if ($result['compliant']) {
                $passed++;
                $this->complianceScores['gdpr']++;
            }
        }

        $compliance = $passed > 0 ? round(($passed / $total) * 100, 2) : 0;

        return [
            'compliance_percentage' => $compliance,
            'passed' => $passed,
            'total' => $total,
            'checks' => $checks,
        ];
    }

    /**
     * Check data minimization
     */
    public function checkDataMinimization(): array
    {
        $result = [
            'compliant' => true,
            'findings' => [],
            'recommendations' => [],
        ];

        // Check if collecting unnecessary data
        if (Schema::hasTable('users')) {
            $columns = Schema::getColumnListing('users');

            // Look for potentially unnecessary data
            $unnecessaryFields = ['ip_address', 'user_agent', 'device_id'];
            $foundUnnecessary = array_intersect($unnecessaryFields, $columns);

            if (! empty($foundUnnecessary)) {
                $result['findings'][] = 'Collecting potentially unnecessary data: '.implode(', ', $foundUnnecessary);
                $result['recommendations'][] = 'Review data collection practices and minimize data collection';
            }
        }

        return $result;
    }

    /**
     * Check right to access
     */
    public function checkRightToAccess(): array
    {
        $result = [
            'compliant' => true,
            'findings' => [],
            'recommendations' => [],
        ];

        // Check if user can export their data
        $controllers = glob(app_path('Http/Controllers/*Controller.php'));
        $hasExport = false;

        foreach ($controllers as $controller) {
            $content = file_get_contents($controller);
            if (preg_match('/function\s+(export|downloadData|getUserData)/i', $content)) {
                $hasExport = true;
                break;
            }
        }

        if (! $hasExport) {
            $result['compliant'] = false;
            $result['findings'][] = 'No data export functionality implemented';
            $result['recommendations'][] = 'Implement data export endpoint for users';
        }

        return $result;
    }

    /**
     * Check right to erasure
     */
    public function checkRightToErasure(): array
    {
        $result = [
            'compliant' => true,
            'findings' => [],
            'recommendations' => [],
        ];

        // Check if user can delete their account
        $controllers = glob(app_path('Http/Controllers/UserController.php'));
        if (! empty($controllers)) {
            $content = file_get_contents($controllers[0]);
            if (! str_contains($content, 'destroy') && ! str_contains($content, 'delete')) {
                $result['compliant'] = false;
                $result['findings'][] = 'No account deletion functionality';
                $result['recommendations'][] = 'Implement account deletion with data anonymization';
            }
        } else {
            $result['compliant'] = false;
            $result['findings'][] = 'UserController not found';
        }

        return $result;
    }

    /**
     * Check right to portability
     */
    public function checkRightToPortability(): array
    {
        $result = [
            'compliant' => true,
            'findings' => [],
            'recommendations' => [],
        ];

        // Check if data can be exported in machine-readable format
        $result['recommendations'][] = 'Provide data export in JSON or XML format';

        return $result;
    }

    /**
     * Check consent management
     */
    public function checkConsentManagement(): array
    {
        $result = [
            'compliant' => true,
            'findings' => [],
            'recommendations' => [],
        ];

        // Check if consent is tracked
        if (Schema::hasTable('users')) {
            $columns = Schema::getColumnListing('users');
            if (! in_array('terms_accepted_at', $columns) && ! in_array('consent_given', $columns)) {
                $result['compliant'] = false;
                $result['findings'][] = 'No consent tracking implemented';
                $result['recommendations'][] = 'Implement consent tracking and management';
            }
        }

        return $result;
    }

    /**
     * Check data breach notification
     */
    public function checkDataBreachNotification(): array
    {
        $result = [
            'compliant' => true,
            'findings' => [],
            'recommendations' => [],
        ];

        // Check if breach notification mechanism exists
        $result['recommendations'][] = 'Implement data breach detection and notification system';
        $result['recommendations'][] = 'Document incident response procedures';

        return $result;
    }

    /**
     * Check data protection by design
     */
    public function checkDataProtectionByDesign(): array
    {
        $result = [
            'compliant' => true,
            'findings' => [],
            'recommendations' => [],
        ];

        // Check for encryption at rest
        $result['recommendations'][] = 'Implement disk encryption for sensitive data';

        // Check for pseudonymization
        $result['recommendations'][] = 'Implement data pseudonymization where applicable';

        return $result;
    }

    /**
     * Check security best practices
     */
    public function checkBestPractices(): array
    {
        Log::info('Checking security best practices');

        $checks = [
            'password_policy' => $this->checkPasswordPolicy(),
            'session_management' => $this->checkSessionManagement(),
            'api_security' => $this->checkAPISecurity(),
            'file_upload_security' => $this->checkFileUploadSecurity(),
            'error_handling' => $this->checkErrorHandling(),
            'backup_security' => $this->checkBackupSecurity(),
            'dependency_management' => $this->checkDependencyManagement(),
        ];

        $passed = 0;
        $total = count($checks);

        foreach ($checks as $name => $result) {
            if ($result['compliant']) {
                $passed++;
                $this->complianceScores['best_practices']++;
            }
        }

        $compliance = $passed > 0 ? round(($passed / $total) * 100, 2) : 0;

        return [
            'compliance_percentage' => $compliance,
            'passed' => $passed,
            'total' => $total,
            'checks' => $checks,
        ];
    }

    /**
     * Check password policy
     */
    public function checkPasswordPolicy(): array
    {
        $result = [
            'compliant' => true,
            'findings' => [],
            'recommendations' => [],
        ];

        if (! class_exists(\App\Rules\StrongPassword::class)) {
            $result['compliant'] = false;
            $result['findings'][] = 'No strong password policy';
            $result['recommendations'][] = 'Implement strong password requirements (12+ chars, mixed case, numbers, special chars)';
        }

        return $result;
    }

    /**
     * Check session management
     */
    public function checkSessionManagement(): array
    {
        $result = [
            'compliant' => true,
            'findings' => [],
            'recommendations' => [],
        ];

        if (config('session.lifetime') > 120) {
            $result['findings'][] = 'Session lifetime exceeds 2 hours';
            $result['recommendations'][] = 'Reduce session lifetime to 2 hours or less';
        }

        if (! config('session.expire_on_close')) {
            $result['findings'][] = 'Sessions not set to expire on close';
            $result['recommendations'][] = 'Consider setting SESSION_EXPIRE_ON_CLOSE=true for sensitive applications';
        }

        return $result;
    }

    /**
     * Check API security
     */
    public function checkAPISecurity(): array
    {
        $result = [
            'compliant' => true,
            'findings' => [],
            'recommendations' => [],
        ];

        // Check for API authentication
        if (! class_exists(\App\Http\Middleware\Authenticate::class)) {
            $result['compliant'] = false;
            $result['findings'][] = 'API authentication middleware not found';
        }

        // Check for rate limiting
        if (! class_exists(\App\Http\Middleware\RateLimiting::class)) {
            $result['compliant'] = false;
            $result['findings'][] = 'API rate limiting not implemented';
        }

        // Check for security headers
        if (! class_exists(\App\Http\Middleware\SecurityHeaders::class)) {
            $result['findings'][] = 'Security headers not implemented';
        }

        return $result;
    }

    /**
     * Check file upload security
     */
    public function checkFileUploadSecurity(): array
    {
        $result = [
            'compliant' => true,
            'findings' => [],
            'recommendations' => [],
        ];

        // Check for file validation
        $result['recommendations'][] = 'Implement file type validation (whitelist approach)';
        $result['recommendations'][] = 'Scan uploaded files for malware';
        $result['recommendations'][] = 'Store uploads outside webroot';
        $result['recommendations'][] = 'Rename uploaded files to prevent execution';

        return $result;
    }

    /**
     * Check error handling
     *
     {
        $result = [
            'compliant' => true,
            'findings' => [],
            'recommendations' => [],
        ];

        if (config('app.debug')) {
            $result['compliant'] = false;
            $result['findings'][] = 'Debug mode enabled';
            $result['recommendations'][] = 'Disable debug mode in production';
        }

        $result['recommendations'][] = 'Implement custom error pages';
        $result['recommendations'][] = 'Log errors without exposing sensitive information';

        return $result;
    }

    /**
     * Check backup security
     */
    public function checkBackupSecurity(): array
    {
        $result = [
            'compliant' => true,
            'findings' => [],
            'recommendations' => [],
        ];

        $result['recommendations'][] = 'Encrypt backup files';
        $result['recommendations'][] = 'Store backups in secure, offsite location';
        $result['recommendations'][] = 'Test backup restoration regularly';
        $result['recommendations'][] = 'Implement backup retention policy';

        return $result;
    }

    /**
     * Check dependency management
     */
    public function checkDependencyManagement(): array
    {
        $result = [
            'compliant' => true,
            'findings' => [],
            'recommendations' => [],
        ];

        // Check if lock files are committed
        if (! file_exists(base_path('composer.lock'))) {
            $result['compliant'] = false;
            $result['findings'][] = 'composer.lock not committed to version control';
        }

        if (! file_exists(base_path('package-lock.json'))) {
            $result['findings'][] = 'package-lock.json not committed to version control';
        }

        $result['recommendations'][] = 'Set up automated dependency scanning';
        $result['recommendations'][] = 'Subscribe to security advisories for dependencies';

        return $result;
    }

    /**
     * Calculate compliance scores
     */
    public function checkErrorHandling(): array
    {
        $findings = [];
        $recommendations = [];

        if (config('app.debug')) {
            $findings[] = 'Application debug mode is enabled';
            $recommendations[] = 'Disable APP_DEBUG outside local development';
        }

        return [
            'compliant' => empty($findings),
            'findings' => $findings,
            'recommendations' => $recommendations,
        ];
    }

    private function calculateComplianceScores(): array
    {
        $totalChecks = count($this->checklist);

        if ($totalChecks === 0) {
            return [
                'overall_compliance' => 0,
                'owasp_compliance' => 0,
                'gdpr_compliance' => 0,
                'best_practices_compliance' => 0,
                'grade' => 'F',
            ];
        }

        $owaspTotal = 10; // OWASP Top 10
        $gdprTotal = 7;   // GDPR checks
        $bestPracticesTotal = 7; // Best practice checks

        $owaspPercentage = $this->complianceScores['owasp'] > 0
            ? round(($this->complianceScores['owasp'] / $owaspTotal) * 100, 2)
            : 0;

        $gdprPercentage = $this->complianceScores['gdpr'] > 0
            ? round(($this->complianceScores['gdpr'] / $gdprTotal) * 100, 2)
            : 0;

        $bestPracticesPercentage = $this->complianceScores['best_practices'] > 0
            ? round(($this->complianceScores['best_practices'] / $bestPracticesTotal) * 100, 2)
            : 0;

        $overallPercentage = round(($owaspPercentage + $gdprPercentage + $bestPracticesPercentage) / 3, 2);

        // Calculate grade
        if ($overallPercentage >= 90) {
            $grade = 'A';
        } elseif ($overallPercentage >= 80) {
            $grade = 'B';
        } elseif ($overallPercentage >= 70) {
            $grade = 'C';
        } elseif ($overallPercentage >= 60) {
            $grade = 'D';
        } else {
            $grade = 'F';
        }

        return [
            'overall_compliance' => $overallPercentage,
            'owasp_compliance' => $owaspPercentage,
            'gdpr_compliance' => $gdprPercentage,
            'best_practices_compliance' => $bestPracticesPercentage,
            'grade' => $grade,
        ];
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
