# PHP 8.1 Compatibility Shims

This directory contains compatibility shims for migrating the FALG API from PHP 7.4 to PHP 8.1.

## Files

### Shim Files (Deploy to `/var/www/fg_OLD2_NEW/app/Helpers/`)

| File | Purpose | Critical For |
|------|---------|--------------|
| `MysqlCompatibility.php` | Provides mysql_result(), mysql_fetch_assoc(), mysql_fetch_array(), mysql_num_rows() | ReciboController.php (35+ instances) |
| `MoneyFormatShim.php` | Replaces removed money_format() function | ReciboController.php line 344 |
| `InputFacade.php` | Backward compatibility for deprecated Input facade | 20+ controller methods |
| `StringFunctions.php` | Null-safe strlen and string helpers | 30+ methods with potential null issues |

### Configuration Snippets

| File | Purpose |
|------|---------|
| `composer-autoload-snippet.json` | Add to composer.json autoload.files section |
| `app-php-aliases-snippet.php` | Add to config/app.php aliases section |

### Unit Tests (Deploy to `/var/www/fg_OLD2_NEW/tests/Unit/Helpers/`)

| File | Coverage |
|------|----------|
| `MysqlCompatibilityTest.php` | All mysql_* function wrappers |
| `MoneyFormatShimTest.php` | Currency formatting scenarios |
| `StringFunctionsTest.php` | Null-safe string operations |

## Quick Deployment

```bash
# 1. Copy shim files to server
scp -r shim/ root@100.71.107.26:/tmp/

# 2. SSH to server
ssh root@100.71.107.26

# 3. Run deployment script
cd /tmp/shim
chmod +x deploy-shims.sh
./deploy-shims.sh
```

## Manual Deployment

If you prefer manual deployment:

### 1. Create Helpers Directory
```bash
mkdir -p /var/www/fg_OLD2_NEW/app/Helpers
mkdir -p /var/www/fg_OLD2_NEW/tests/Unit/Helpers
```

### 2. Copy Shim Files
```bash
cp MysqlCompatibility.php /var/www/fg_OLD2_NEW/app/Helpers/
cp MoneyFormatShim.php /var/www/fg_OLD2_NEW/app/Helpers/
cp InputFacade.php /var/www/fg_OLD2_NEW/app/Helpers/
cp StringFunctions.php /var/www/fg_OLD2_NEW/app/Helpers/
```

### 3. Update composer.json
Add to the `autoload` section:
```json
"files": [
    "app/Helpers/MysqlCompatibility.php",
    "app/Helpers/MoneyFormatShim.php",
    "app/Helpers/StringFunctions.php"
]
```

### 4. Update config/app.php
Add to the `aliases` section:
```php
'Input' => App\Helpers\Input::class,
```

### 5. Regenerate Autoload
```bash
cd /var/www/fg_OLD2_NEW
composer dump-autoload
```

### 6. Clear Caches
```bash
php artisan cache:clear
php artisan config:clear
php artisan route:clear
```

### 7. Test Critical Endpoints
```bash
# Test receipt generation
curl -H "Authorization: Bearer YOUR_TOKEN" https://api.falg.com.br/api/recibo/1

# Test boleto generation
curl -H "Authorization: Bearer YOUR_TOKEN" https://api.falg.com.br/api/boletoitau/1

# Test payment processing
curl -X POST \
     -H "Authorization: Bearer YOUR_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"valor": 100.00}' \
     https://api.falg.com.br/api/cobrancas/pagto/1
```

## Running Tests

```bash
cd /var/www/fg_OLD2_NEW

# Run all shim tests
php artisan test --filter=Helpers

# Run specific test file
php artisan test tests/Unit/Helpers/MysqlCompatibilityTest.php
```

## Troubleshooting

### Issue: "Call to undefined function mysql_result()"
**Cause:** Shim not loaded
**Solution:**
```bash
composer dump-autoload
php artisan cache:clear
```

### Issue: "Class 'Input' not found"
**Cause:** Facade not registered
**Solution:** Check config/app.php aliases section includes `'Input' => App\Helpers\Input::class`

### Issue: "Call to a member function format() on null"
**Cause:** NumberFormatter not instantiated properly
**Solution:** Check PHP intl extension is installed:
```bash
php -m | grep intl
# If missing: apt-get install php8.1-intl
```

## Verification Checklist

- [ ] All 4 shim files in `/var/www/fg_OLD2_NEW/app/Helpers/`
- [ ] composer.json updated with files autoload
- [ ] config/app.php updated with Input alias
- [ ] `composer dump-autoload` executed
- [ ] Laravel caches cleared
- [ ] Unit tests passing
- [ ] Receipt generation working
- [ ] Boleto generation working
- [ ] Payment processing working

## Related Documentation

- [PHP Compatibility Analysis](../analysis/php-compatibility-analysis.md)
- [CODER Quickstart Guide](../analysis/CODER-QUICKSTART.md)
- [Migration Architecture](../code/MIGRATION_ARCHITECTURE.md)
