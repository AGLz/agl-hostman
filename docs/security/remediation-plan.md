# Security Remediation Plan

**AGL Hostman Security Remediation Plan**
Last Updated: 2026-01-16
Version: 1.0.0

This document outlines the remediation plan for addressing security findings from the security audit.

---

## Executive Summary

**Total Findings:** 16
- **Critical:** 0
- **High:** 0
- **Medium:** 3
- **Low:** 5
- **Informational:** 8

**Overall Security Grade:** A (91% compliance)

**Remediation Timeline:** 3 months
**Estimated Effort:** 80-120 hours

---

## Priority Matrix

### Immediate (Critical/High) - Week 1

**No critical or high severity findings requiring immediate action.**

### High Priority (Medium Severity) - Weeks 1-4

| ID | Finding | Severity | Effort | Owner | Due |
|----|---------|----------|--------|-------|-----|
| M1 | Debug mode enabled in production | Medium | 1h | DevOps | Week 1 |
| M2 | File upload security not implemented | Medium | 8h | Backend | Week 2 |
| M3 | Database SSL not enabled | Medium | 2h | DevOps | Week 1 |
| M4 | 2FA not mandatory for admins | Medium | 4h | Security | Week 3 |

### Medium Priority (Low Severity) - Weeks 5-8

| ID | Finding | Severity | Effort | Owner | Due |
|----|---------|----------|--------|-------|-----|
| L1 | Session lifetime too long (120 min) | Low | 1h | Backend | Week 5 |
| L2 | Using file cache (consider Redis) | Low | 2h | Backend | Week 6 |
| L3 | No consent tracking for GDPR | Low | 8h | Backend | Week 7 |
| L4 | No data retention policy | Low | 4h | Security | Week 8 |
| L5 | No automated dependency scanning in CI/CD | Low | 4h | DevOps | Week 5 |

### Low Priority (Informational) - Weeks 9-12

| ID | Finding | Severity | Effort | Owner | Due |
|----|---------|----------|--------|-------|-----|
| I1 | No code signing for deployments | Info | 8h | DevOps | Week 9 |
| I2 | No dependency review workflow | Info | 4h | Security | Week 10 |
| I3 | No intrusion detection system | Info | 16h | Security | Week 11-12 |
| I4 | No data pseudonymization | Info | 8h | Backend | Week 10 |
| I5 | No log retention policy | Info | 2h | DevOps | Week 9 |
| I6 | No breach detection system | Info | 12h | Security | Week 11 |
| I7 | No formal threat modeling document | Info | 4h | Security | Week 12 |
| I8 | No data minimization review | Info | 4h | Security | Week 12 |

---

## Detailed Remediation Steps

### M1: Debug Mode Enabled in Production

**Severity:** Medium
**Effort:** 1 hour
**Priority:** Week 1

**Current State:**
- `APP_DEBUG=true` in production environment
- Detailed error messages may expose sensitive information

**Risk:**
- Information disclosure via stack traces
- Exposed database credentials
- Revealed file paths

**Remediation Steps:**

1. **Update .env file**
   ```bash
   # On production server
   cd /var/www/agl-hostman
   nano .env

   # Change:
   APP_DEBUG=true

   # To:
   APP_DEBUG=false
   ```

2. **Verify configuration**
   ```bash
   php artisan config:clear
   php artisan cache:clear
   php artisan tinker
   >>> config('app.debug')
   => false
   ```

3. **Test error handling**
   - Trigger an error
   - Verify custom error page displays
   - Confirm no stack traces shown

4. **Monitoring**
   - Set up alert for APP_DEBUG changes
   - Monitor error logs for sensitive data

**Verification:**
```bash
# Run security audit
php artisan security:audit --type=quick

# Expected: No findings about debug mode
```

**Completion Criteria:**
- ✅ APP_DEBUG=false in production
- ✅ Custom error pages display
- ✅ No sensitive data in errors
- ✅ Monitoring in place

---

### M2: File Upload Security Not Implemented

**Severity:** Medium
**Effort:** 8 hours
**Priority:** Week 2

**Current State:**
- No file type validation (whitelist)
- No malware scanning
- Files stored in publicly accessible directory
- Original filenames preserved

**Risk:**
- Malicious file uploads
- Remote code execution
- Directory traversal
- XSS via uploaded files

**Remediation Steps:**

1. **Create FileUploadService**
   ```php
   // app/Services/FileUploadService.php
   class FileUploadService
   {
       private array $allowedMimes = [
           'image/jpeg',
           'image/png',
           'image/gif',
           'application/pdf',
           'text/csv',
       ];

       private array $allowedExtensions = [
           'jpg', 'jpeg', 'png', 'gif', 'pdf', 'csv'
       ];

       public function upload(UploadedFile $file): string
       {
           // 1. Validate MIME type
           if (!in_array($file->getMimeType(), $this->allowedMimes)) {
               throw new \Exception('Invalid file type');
           }

           // 2. Validate extension
           if (!in_array($file->getClientOriginalExtension(), $this->allowedExtensions)) {
               throw new \Exception('Invalid file extension');
           }

           // 3. Scan for malware (ClamAV)
           if (!$this->scanForMalware($file)) {
               throw new \Exception('Malware detected');
           }

           // 4. Generate safe filename
           $filename = $this->generateSafeFilename($file);

           // 5. Store outside webroot
           $path = $file->storeAs('uploads/' . date('Y/m'), $filename, 'secure');

           return $path;
       }

       private function scanForMalware(UploadedFile $file): bool
       {
           // Implement ClamAV scanning
           $process = Process::run('clamscan --no-summary ' . $file->getRealPath());
           return $process->successful();
       }

       private function generateSafeFilename(UploadedFile $file): string
       {
           $extension = $file->getClientOriginalExtension();
           return Str::random(40) . '.' . $extension;
       }
   }
   ```

2. **Create secure disk**
   ```php
   // config/filesystems.php
   'disks' => [
       'secure' => [
           'driver' => 'local',
           'root' => storage_path('app/uploads/secure'),
           'visibility' => 'private',
       ],
   ],
   ```

3. **Create upload endpoint with authentication**
   ```php
   // routes/api.php
   Route::middleware(['auth:api', 'permission:upload files'])->post('/upload', [UploadController::class, 'store']);
   ```

4. **Implement file serving with authorization**
   ```php
   // FileController.php
   public function show(Request $request, string $filename)
   {
       $this->authorize('view', $file);

       $path = storage_path('app/uploads/secure/' . $filename);

       if (!file_exists($path)) {
           abort(404);
       }

       return response()->file($path);
   }
   ```

5. **Add rate limiting**
   ```php
   // Limit to 10 uploads per minute per user
   Route::middleware('throttle:uploads,10,1')->post('/upload', [UploadController::class, 'store']);
   ```

**Verification:**
```php
// Test file upload validation
$this->post('/upload', [
    'file' => UploadedFile::fake()->create('malicious.exe', 100)
])->assertStatus(422);

$this->post('/upload', [
    'file' => UploadedFile::fake()->image('valid.jpg')
])->assertStatus(201);
```

**Completion Criteria:**
- ✅ MIME type validation implemented
- ✅ Extension whitelist enforced
- ✅ Malware scanning configured
- ✅ Files stored outside webroot
- ✅ Filenames randomized
- ✅ Access control on file serving

---

### M3: Database SSL Not Enabled

**Severity:** Medium
**Effort:** 2 hours
**Priority:** Week 1

**Current State:**
- Database connection not encrypted
- Data transmitted in plain text between app and database

**Risk:**
- Man-in-the-middle attacks
- Data interception
- Credential theft

**Remediation Steps:**

1. **Obtain SSL certificate**
   ```bash
   # On database server
   sudo mkdir -p /var/postgresql/certs
   sudo openssl req -new -x509 -days 365 -nodes \
     -out /var/postgresql/certs/server.crt \
     -keyout /var/postgresql/certs/server.key
   ```

2. **Configure PostgreSQL for SSL**
   ```bash
   # Edit postgresql.conf
   sudo nano /etc/postgresql/14/main/postgresql.conf

   # Add:
   ssl = on
   ssl_cert_file = '/var/postgresql/certs/server.crt'
   ssl_key_file = '/var/postgresql/certs/server.key'
   ssl_ca_file = '/var/postgresql/certs/server.crt'
   ```

3. **Force SSL connections**
   ```bash
   # Edit pg_hba.conf
   sudo nano /etc/postgresql/14/main/pg_hba.conf

   # Change host to hostssl
   hostssl    all    all    0.0.0.0/0    md5
   ```

4. **Restart PostgreSQL**
   ```bash
   sudo systemctl restart postgresql
   ```

5. **Update Laravel database configuration**
   ```php
   // config/database.php
   'connections' => [
       'pgsql' => [
           'driver' => 'pgsql',
           'url' => env('DATABASE_URL'),
           'host' => env('DB_HOST', '127.0.0.1'),
           'port' => env('DB_PORT', '5432'),
           'database' => env('DB_DATABASE', 'forge'),
           'username' => env('DB_USERNAME', 'forge'),
           'password' => env('DB_PASSWORD', ''),
           'charset' => 'utf8',
           'prefix' => '',
           'prefix_indexes' => true,
           'schema' => 'public',
           'sslmode' => 'require',
           'options' => [
               PDO::ATTR_SSL_MODE => PDO::SSL_MODE_REQUIRED,
           ],
       ],
   ],
   ```

6. **Update .env**
   ```bash
   DB_CONNECTION=pgsql
   DB_HOST=your-db-host
   DB_PORT=5432
   DB_DATABASE=agl_hostman
   DB_USERNAME=agl_hostman_user
   DB_PASSWORD=secure_password
   DB_SSLMODE=require
   ```

**Verification:**
```bash
# Test SSL connection
php artisan tinker
>>> DB::connection()->getPdo();
=> PDO { ... } # Should connect successfully

# Check if SSL is being used
>>> DB::select("SELECT ssl_is_used()");
=> [{"ssl_is_used": "t"}]
```

**Completion Criteria:**
- ✅ SSL certificate installed
- ✅ PostgreSQL configured for SSL
- ✅ Laravel requires SSL connection
- ✅ All connections use SSL
- ✅ Test connection successful

---

### M4: 2FA Not Mandatory for Admins

**Severity:** Medium
**Effort:** 4 hours
**Priority:** Week 3

**Current State:**
- 2FA available via WorkOS but not required
- Admin accounts can operate without 2FA

**Risk:**
- Compromised admin credentials give full access
- No second factor of authentication

**Remediation Steps:**

1. **Add 2FA required column to users table**
   ```bash
   php artisan make:migration add_two_factor_required_to_users_table
   ```

   ```php
   // Migration
   public function up(): void
   {
       Schema::table('users', function (Blueprint $table) {
           $table->boolean('two_factor_required')->default(false);
           $table->timestamp('two_factor_enabled_at')->nullable();
       });
   }
   ```

2. **Update User model**
   ```php
   // app/Models/User.php
   protected $fillable = [
       // ... other fields
       'two_factor_required',
       'two_factor_enabled_at',
   ];

   public function requiresTwoFactor(): bool
   {
       return $this->two_factor_required ||
              $this->hasRole('admin');
   }

   public function hasTwoFactorEnabled(): bool
   {
       return !is_null($this->two_factor_enabled_at) &&
              $this->two_factor_enabled_at->lessThanOrEqualTo(now());
   }
   ```

3. **Create 2FA enforcement middleware**
   ```php
   // app/Http/Middleware/EnsureTwoFactorEnabled.php
   public function handle(Request $request, Closure $next): Response
   {
       $user = auth()->user();

       if ($user && $user->requiresTwoFactor() && !$user->hasTwoFactorEnabled()) {
           return response()->json([
               'error' => 'Two-factor authentication required',
               'message' => 'Please enable 2FA to continue',
           ], 403);
       }

       return $next($request);
   }
   ```

4. **Apply middleware to admin routes**
   ```php
   // bootstrap/app.php
   $middleware->alias([
       '2fa.required' => \App\Http\Middleware\EnsureTwoFactorEnabled::class,
   ]);

   // routes/web.php or routes/api.php
   Route::middleware(['auth', 'role:admin', '2fa.required'])->group(function () {
       Route::get('/admin', [AdminController::class, 'index']);
       Route::resource('/users', UserController::class);
       // ... other admin routes
   });
   ```

5. **Create 2FA enablement endpoint**
   ```php
   // routes/api.php
   Route::middleware('auth')->post('/user/two-factor/enable', [TwoFactorController::class, 'enable']);
   Route::middleware('auth')->post('/user/two-factor/disable', [TwoFactorController::class, 'disable']);
   ```

6. **Update admin user registration**
   ```php
   // When creating admin users
   $admin = User::create([
       'name' => 'Admin User',
       'email' => 'admin@example.com',
       'password' => bcrypt('secure_password'),
       'two_factor_required' => true,
   ]);

   $admin->assignRole('admin');
   ```

**Verification:**
```php
// Test 2FA requirement
$admin = User::factory()->create(['role' => 'admin']);
$this->actingAs($admin)
     ->get('/admin')
     ->assertStatus(403)
     ->assertJson(['error' => 'Two-factor authentication required']);

// Enable 2FA
$admin->update(['two_factor_enabled_at' => now()]);
$this->actingAs($admin)
     ->get('/admin')
     ->assertStatus(200);
```

**Completion Criteria:**
- ✅ Admin users require 2FA
- ✅ Middleware enforces 2FA
- ✅ 2FA enablement endpoint available
- ✅ Existing admins notified to enable 2FA
- ✅ Tests pass

---

## Remaining Remediations (Low Priority)

### L1: Session Lifetime Too Long (120 min)

**Effort:** 1 hour
**Priority:** Week 5

**Remediation:**
```php
// config/session.php
'lifetime' => 60, // Reduce from 120 to 60 minutes
```

### L2: Using File Cache (Consider Redis)

**Effort:** 2 hours
**Priority:** Week 6

**Remediation:**
1. Install Redis
2. Update `CACHE_STORE=redis` in .env
3. Configure Redis connection

### L3: No Consent Tracking for GDPR

**Effort:** 8 hours
**Priority:** Week 7

**Remediation:**
1. Add consent tracking table
2. Update registration flow
3. Implement consent withdrawal

### L4: No Data Retention Policy

**Effort:** 4 hours
**Priority:** Week 8

**Remediation:**
1. Define retention periods
2. Create cleanup jobs
3. Schedule automated deletion

### L5: No Automated Dependency Scanning in CI/CD

**Effort:** 4 hours
**Priority:** Week 5

**Remediation:**
1. Add composer audit to CI pipeline
2. Add npm audit to CI pipeline
3. Fail build on vulnerabilities

---

## Tracking and Monitoring

### Remediation Progress Dashboard

```bash
# Check remediation progress
php artisan security:remediation:status

# Expected output:
+---------+-----------+-----------+-------+
| Finding | Status    | Due       | Owner |
+---------+-----------+-----------+-------+
| M1      | Complete  | Week 1    | DevOps|
| M2      | In Progress| Week 2  | Backend|
| M3      | Pending   | Week 1    | DevOps|
| M4      | Pending   | Week 3    | Security|
+---------+-----------+-----------+-------+
```

### Weekly Status Reports

**Week 1:**
- ✅ M1: Debug mode disabled
- ✅ M3: Database SSL enabled
- ⏳ M2: File upload security (in progress)

**Week 2:**
- ✅ M2: File upload security complete
- ⏳ M4: 2FA requirement (in progress)

**Week 3:**
- ✅ M4: 2FA requirement complete
- ⏳ L1: Session lifetime (starting)

### Post-Remediation Audit

**Schedule:** After Week 4 (high priority items complete)

**Command:**
```bash
php artisan security:audit --type=full --output=file
```

**Expected Results:**
- All medium severity findings resolved
- Security grade improves from A to A+
- Compliance increases from 91% to 95%+

---

## Risk Assessment

### Pre-Remediation Risks

| Risk | Likelihood | Impact | Severity |
|------|------------|--------|----------|
| Debug mode exposure | Medium | High | Medium |
| Malicious file upload | Low | Critical | Medium |
| Database interception | Low | High | Medium |
| Admin account compromise | Low | Critical | Medium |

### Post-Remediation Risks

| Risk | Likelihood | Impact | Severity |
|------|------------|--------|----------|
| Debug mode exposure | Very Low | High | Low |
| Malicious file upload | Very Low | Critical | Low |
| Database interception | Very Low | High | Low |
| Admin account compromise | Very Low | Critical | Low |

---

## Success Metrics

### Quantitative Metrics

- **Vulnerability Count:** Reduce from 16 to < 8
- **Compliance Score:** Increase from 91% to 95%+
- **Security Grade:** Maintain A or improve to A+
- **Audit Duration:** Reduce from quarterly to semi-annually

### Qualitative Metrics

- **Team Awareness:** 100% of developers complete security training
- **Process Maturity:** Move from reactive to proactive security
- **Stakeholder Confidence:** Regular security reports to management

---

## Conclusion

This remediation plan addresses all security findings identified in the audit. The timeline prioritizes medium severity findings while ensuring low-priority items are addressed within 3 months.

**Key Success Factors:**
- Executive support for security initiatives
- Dedicated time from development team
- Regular progress tracking
- Post-remediation validation

**Next Steps:**
1. Obtain approval for remediation plan
2. Assign resources to each finding
3. Schedule weekly status meetings
4. Conduct post-remediation audit

---

**Plan Approved By:** _______________
**Date:** _______________
**Next Review:** 2026-02-16 (After high-priority remediation)
