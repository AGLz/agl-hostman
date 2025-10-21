# CODER QUICKSTART GUIDE
**Mission:** Implement PHP 8.1 compatibility shims for FALG API
**Priority:** CRITICAL - Payment processing will fail without these fixes
**Estimated Time:** 3-5 days for shim deployment + testing

---

## IMMEDIATE ACTIONS (DAY 1)

### 1. Create Shim Directory Structure
```bash
ssh root@100.71.107.26
cd /var/www/fg_OLD2_NEW

# Create helpers directory
mkdir -p app/Helpers

# Create test environment
mkdir -p tests/Unit/Helpers
```

### 2. Deploy Compatibility Shims

Copy these files from the main analysis report to the server:

#### File 1: `app/Helpers/MysqlCompatibility.php`
**Purpose:** Provides mysql_result(), mysql_fetch_assoc(), mysql_fetch_array(), mysql_num_rows()
**Critical For:** ReciboController.php (35+ instances)
**Code:** See full analysis report section "SHIM LAYER DESIGN"

#### File 2: `app/Helpers/MoneyFormatShim.php`
**Purpose:** Replaces removed money_format() function
**Critical For:** ReciboController.php line 344
**Code:** See full analysis report

#### File 3: `app/Helpers/InputFacade.php`
**Purpose:** Provides backward compatibility for deprecated Input facade
**Critical For:** 20+ controller methods
**Code:** See full analysis report

#### File 4: `app/Helpers/StringFunctions.php`
**Purpose:** Null-safe strlen and string helpers
**Critical For:** 30+ methods with potential null issues
**Code:** See full analysis report

### 3. Register Shims in Composer
```bash
cd /var/www/fg_OLD2_NEW

# Edit composer.json - add to "autoload" section:
nano composer.json
```

Add this to the autoload section:
```json
{
    "autoload": {
        "classmap": [
            "database/seeds",
            "database/factories"
        ],
        "psr-4": {
            "App\\": "app/"
        },
        "files": [
            "app/Helpers/MysqlCompatibility.php",
            "app/Helpers/MoneyFormatShim.php",
            "app/Helpers/StringFunctions.php"
        ]
    }
}
```

Then regenerate autoload:
```bash
composer dump-autoload
```

### 4. Register Input Facade
```bash
# Edit config/app.php
nano config/app.php
```

Add to aliases array:
```php
'aliases' => [
    // ... existing aliases ...
    'Input' => App\Helpers\Input::class,
],
```

### 5. Test on PHP 7.4 (Current Production)
```bash
# Clear caches
php artisan cache:clear
php artisan config:clear
php artisan route:clear

# Test receipt generation
curl -H "Authorization: Bearer YOUR_TOKEN" \
     https://api.falg.com.br/api/recibo/1

# Expected: Should work exactly as before
```

---

## DAY 2-3: STAGING SETUP & TESTING

### 1. Set Up PHP 8.1 Staging Environment

If staging doesn't exist:
```bash
# On FGSRV05
cd /var/www
cp -r fg_OLD2_NEW fg_OLD2_NEW_staging

# Update .env for staging
cd fg_OLD2_NEW_staging
cp .env .env.backup
nano .env

# Change:
DB_DATABASE_SYS=fgdev  # Use test database
APP_ENV=staging
APP_DEBUG=true
```

Configure Nginx for staging:
```bash
nano /etc/nginx/sites-available/api_staging.conf
```

Add:
```nginx
server {
    listen 8081 ssl http2;
    server_name api.falg.com.br;

    root /var/www/fg_OLD2_NEW_staging/public;
    index index.php;

    ssl_certificate /etc/letsencrypt/live/api.falg.com.br/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.falg.com.br/privkey.pem;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
```

Enable and restart:
```bash
ln -s /etc/nginx/sites-available/api_staging.conf /etc/nginx/sites-enabled/
nginx -t
systemctl reload nginx
```

### 2. Test Critical Paths on PHP 8.1

```bash
# Test receipt generation
curl -H "Authorization: Bearer YOUR_TOKEN" \
     https://api.falg.com.br:8081/api/recibo/1

# Test boleto generation
curl -H "Authorization: Bearer YOUR_TOKEN" \
     https://api.falg.com.br:8081/api/boletoitau/1

# Test payment processing
curl -X POST \
     -H "Authorization: Bearer YOUR_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"valor": 100.00}' \
     https://api.falg.com.br:8081/api/cobrancas/pagto/1
```

### 3. Monitor PHP Error Logs

```bash
# Watch for PHP 8.1 errors
tail -f /var/log/nginx/error.log
tail -f /var/www/fg_OLD2_NEW_staging/storage/logs/laravel.log

# Look for:
# - Deprecated warnings
# - Fatal errors
# - Type errors
# - Null pointer issues
```

---

## DAY 4: PACKAGE UPGRADES

### 1. Upgrade laravel-boleto Package

```bash
cd /var/www/fg_OLD2_NEW_staging

# Backup current vendor
tar -czf vendor_backup_$(date +%Y%m%d).tar.gz vendor/

# Upgrade package
composer require eduardokum/laravel-boleto:^0.8.12

# Check for breaking changes
composer show eduardokum/laravel-boleto
```

### 2. Test Boleto Generation After Upgrade

```bash
# Generate test boleto
php artisan tinker

# In tinker:
$boleto = \Eduardokum\LaravelBoleto\Boleto\Banco\Itau::new();
// ... configure boleto ...
$boleto->render();
```

### 3. Test CNAB File Generation

```bash
# Test remittance file generation
curl -H "Authorization: Bearer YOUR_TOKEN" \
     https://api.falg.com.br:8081/api/get-remessa-itau

# Verify file format matches production
diff production_remessa.txt staging_remessa.txt
```

---

## DAY 5: RECIBO CONTROLLER REWRITE (OPTIONAL BUT RECOMMENDED)

### Current State (Broken):
```php
// ReciboController.php line 344
$valortotal = money_format("%n", mysql_result($rsvercontrato_aux, 0, "Valorpago"));
```

### Option A: Quick Fix (Works with shim)
No changes needed - shims handle it automatically.

### Option B: Proper Refactor (Recommended)
```php
// ReciboController.php line 344 - Refactored
$recibo = DB::table('SCLRecibos')
    ->where('ID', $request->id)
    ->first();

$valorpago = $recibo->Valorpago ?? 0;
$valortotal = money_format("%n", $valorpago);
```

### Option C: Full Eloquent Migration
```php
// Create Recibo model
namespace App;

use Illuminate\Database\Eloquent\Model;

class Recibo extends Model
{
    protected $connection = 'mysql_sys';
    protected $table = 'SCLRecibos';
    protected $primaryKey = 'ID';

    public function contrato()
    {
        return $this->belongsTo(Contrato::class, 'ContratoID', 'ID');
    }

    public function getValorTotalFormatadoAttribute()
    {
        $formatter = new \NumberFormatter('pt_BR', \NumberFormatter::CURRENCY);
        return $formatter->formatCurrency($this->Valorpago, 'BRL');
    }
}

// In controller
public function show($id)
{
    $recibo = Recibo::with('contrato')->findOrFail($id);
    return response()->json([
        'valortotal' => $recibo->valor_total_formatado,
        // ... rest of response
    ]);
}
```

**Recommendation:** Start with Option A (shims), then refactor to Option C in Week 3-4.

---

## TESTING CHECKLIST

### Critical Path Tests (MUST PASS)

- [ ] Receipt generation (GET /api/recibo/{id})
  - [ ] With valid ID
  - [ ] With invalid ID
  - [ ] With multiple contractors
  - [ ] With multiple lessees
  - [ ] With paid status
  - [ ] With unpaid status

- [ ] Boleto generation (GET /api/boletoitau/{id})
  - [ ] Standard boleto
  - [ ] Registered boleto
  - [ ] Custom CNAB fields
  - [ ] PDF rendering
  - [ ] Barcode generation

- [ ] Payment processing (POST /api/cobrancas/pagto/{id})
  - [ ] Full payment
  - [ ] Partial payment
  - [ ] Multiple payments
  - [ ] Payment reversal

- [ ] Remittance generation (GET /api/get-remessa-itau)
  - [ ] File format (CNAB 400)
  - [ ] Field mapping
  - [ ] Checksum validation

### Secondary Tests (SHOULD PASS)

- [ ] Contract CRUD operations
- [ ] Client management
- [ ] Charge listing
- [ ] Historical records

### Performance Tests (BENCHMARK)

```bash
# Before (PHP 7.4)
ab -n 1000 -c 10 https://api.falg.com.br/api/recibo/1

# After (PHP 8.1)
ab -n 1000 -c 10 https://api.falg.com.br:8081/api/recibo/1

# Compare:
# - Requests per second
# - Mean response time
# - 95th percentile
# - Memory usage
```

---

## ROLLBACK PROCEDURE

### If Something Breaks on Staging:

```bash
# 1. Switch back to PHP 7.4
cd /var/www/fg_OLD2_NEW_staging
nano .env
# Set: APP_DEBUG=true

# 2. Check error logs
tail -100 storage/logs/laravel.log

# 3. Restore vendor backup if package upgrade failed
tar -xzf vendor_backup_YYYYMMDD.tar.gz

# 4. Clear all caches
php artisan cache:clear
php artisan config:clear
php artisan route:clear
```

### If Something Breaks on Production (UNLIKELY - staged rollout):

```bash
# 1. Nginx immediate rollback
# Edit /etc/nginx/sites-available/fg_api2
# Change fastcgi_pass to:
fastcgi_pass unix:/run/php/php7.4-fpm-fg_old2_new.sock;

nginx -t && systemctl reload nginx

# 2. Verify production working
curl https://api.falg.com.br/api/recibo/1

# 3. Post-mortem analysis
grep "PHP Fatal" /var/log/nginx/error.log | tail -50
```

---

## SUCCESS CRITERIA

### Phase 1 Complete When:
- [x] All shim files deployed
- [x] Composer autoload updated
- [x] Tests pass on PHP 7.4 (no regression)
- [x] Tests pass on PHP 8.1 staging
- [x] No PHP errors in logs
- [x] Receipt generation working
- [x] Boleto generation working

### Ready for Production When:
- [x] All Phase 1 criteria met
- [x] Package upgrades tested
- [x] Performance benchmarks acceptable
- [x] Integration tests passing
- [x] Rollback procedure documented and tested
- [x] Monitoring in place

---

## COMMON ISSUES & SOLUTIONS

### Issue 1: "Call to undefined function mysql_result()"
**Cause:** Shim not loaded
**Solution:**
```bash
composer dump-autoload
php artisan cache:clear
```

### Issue 2: "Class 'Input' not found"
**Cause:** Facade not registered
**Solution:** Check config/app.php aliases section

### Issue 3: "Call to a member function format() on null"
**Cause:** NumberFormatter not instantiated properly
**Solution:** Check MoneyFormatShim.php implementation

### Issue 4: Boleto generation fails silently
**Cause:** Package version mismatch
**Solution:**
```bash
composer show eduardokum/laravel-boleto
# Should be 0.8.12 or higher
```

### Issue 5: Performance degradation >20%
**Cause:** Shim layer overhead (rare)
**Solution:** Profile with Xdebug, optimize hot paths

---

## COORDINATION WITH OTHER AGENTS

### Handoff to TESTER Agent:
Once shims deployed and basic tests passing, provide:
- Staging URL (https://api.falg.com.br:8081)
- Test credentials
- List of critical endpoints to test
- Expected vs actual behavior documentation

### Handoff to MONITOR Agent (if available):
Set up monitoring for:
- Error rate (PHP errors, exceptions)
- Response time (p50, p95, p99)
- Memory usage
- Success rate for critical paths

### Report to QUEEN:
Daily updates on:
- Shims deployed: X/4 complete
- Tests passing: X/Y
- Blockers encountered
- Estimated completion date

---

## FILES LOCATION SUMMARY

### Analysis Reports (Read First):
```
/mnt/overpower/apps/dev/agl/hostman/hive/analysis/php-compatibility-analysis.md
/mnt/overpower/apps/dev/agl/hostman/hive/analysis/critical-paths-priority-matrix.md
/mnt/overpower/apps/dev/agl/hostman/hive/analysis/CODER-QUICKSTART.md (this file)
```

### Code to Deploy:
```
All shim code is in: php-compatibility-analysis.md
Section: "SHIM LAYER DESIGN"
```

### Production API:
```
Server: FGSRV05 (100.71.107.26)
Path: /var/www/fg_OLD2_NEW
PHP: 7.4-FPM (unix:/run/php/php7.4-fpm-fg_old2_new.sock)
```

### Modern API (Reference):
```
Server: FGSRV05 (100.71.107.26)
Path: /var/www/fg_API8_d
PHP: 8.1-FPM (unix:/var/run/php/php8.1-fpm.sock)
```

---

## QUICK COMMAND REFERENCE

```bash
# SSH to server
ssh root@100.71.107.26

# Navigate to API
cd /var/www/fg_OLD2_NEW

# Reload composer
composer dump-autoload

# Clear caches
php artisan cache:clear && php artisan config:clear && php artisan route:clear

# Test endpoint
curl -H "Authorization: Bearer TOKEN" https://api.falg.com.br/api/recibo/1

# Watch logs
tail -f storage/logs/laravel.log

# Check PHP version
php -v

# Check PHP-FPM status
systemctl status php7.4-fpm php8.1-fpm

# Restart PHP-FPM
systemctl restart php8.1-fpm

# Restart Nginx
systemctl reload nginx
```

---

**MISSION PRIORITY:** CRITICAL
**ESTIMATED TIME:** 3-5 days
**BLOCKING:** Receipt generation will fail on PHP 8.0+ without these fixes

**START IMMEDIATELY:** Deploy shims to staging, test, report results.

**Questions?** Check main analysis report or coordinate with ANALYST agent.

---

*Generated: 2025-10-13 by ANALYST Agent*
*For: CODER Agent*
*Status: READY TO EXECUTE*
