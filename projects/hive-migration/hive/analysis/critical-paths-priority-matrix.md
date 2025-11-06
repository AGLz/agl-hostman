# CRITICAL PATHS PRIORITY MATRIX
**Project:** FALG API Migration PHP 7.4 → 8.1
**Date:** 2025-10-13

---

## PRIORITY 1: PAYMENT PROCESSING (MUST FIX FIRST)

### P1-A: Receipt Generation (BLOCKER)
**Status:** CRITICAL - Will completely fail on PHP 8.0+
**File:** `app/Http/Controllers/Si/ReciboController.php`
**Size:** 24KB
**Breaking Issues:** 35+ instances of removed functions

#### Issues Breakdown:
| Function | Count | Severity | Replacement |
|----------|-------|----------|-------------|
| mysql_result() | 16 | CRITICAL | PDO fetch + array access |
| mysql_fetch_assoc() | 6 | CRITICAL | PDO::FETCH_ASSOC |
| mysql_fetch_array() | 6 | CRITICAL | PDO::FETCH_BOTH |
| mysql_num_rows() | 6 | CRITICAL | PDO::rowCount() |
| money_format() | 1 | CRITICAL | NumberFormatter |

#### Business Impact:
- Cannot generate receipts for rental payments
- Cannot issue payment confirmations to clients
- Breaks entire payment reconciliation workflow

#### Estimated Effort:
- With shim layer: 3 days
- Full rewrite: 2 weeks
- Testing: 1 week

#### Dependencies:
- Database access (fgdev or falgimoveis11)
- PDF generation (barryvdh/laravel-dompdf)
- Money formatting (NumberFormatter class)

---

### P1-B: Boleto Generation (HIGH RISK)
**Status:** UNKNOWN - Requires manual audit
**File:** `app/Http/Controllers/BoletoController.php`
**Size:** 135KB (2,728 lines)

#### Concerns:
1. File too large for automated analysis
2. Modified today (2025-10-13) - active development
3. Core payment slip generation for Itaú bank
4. Custom CNAB implementations

#### Custom Extensions:
```
app/Boleto/Banco/ItauCustom.php (1.5KB)
app/Boleto/Cnab/Remessa/Cnab400/Banco/ItauCustomRemessa.php (4.4KB)
app/Boleto/Render/PdfCustom.php (8.6KB)
```

#### Business Impact:
- Cannot generate bank payment slips (boletos)
- Breaks integration with Itaú bank
- Blocks all new payment collections

#### Estimated Effort:
- Manual audit: 1 week
- Testing on staging: 1 week
- Bug fixes: 1-2 weeks

#### Dependencies:
- eduardokum/laravel-boleto package (needs upgrade to 0.8.12)
- Itaú bank API connectivity
- CNAB 400 file format validation

---

### P1-C: Boleto Package Upgrade
**Status:** REQUIRED - Current version likely incompatible
**Current:** eduardokum/laravel-boleto ^0.7.1 (August 2018)
**Target:** ^0.8.12 (API8 version)

#### Compatibility:
- v0.7.1: PHP >=5.5.0 (no PHP 8.x testing)
- v0.8.12: PHP >=7.0 (likely PHP 8.x compatible)

#### Breaking Changes Risk: MEDIUM
- Package interface may have changed
- CNAB file generation might differ
- Itaú bank integration could be affected

#### Estimated Effort:
- Package upgrade: 1 day
- Integration testing: 1 week
- Regression fixes: 3-5 days

---

## PRIORITY 2: CORE CRUD OPERATIONS

### P2-A: Charge Management
**File:** `app/Http/Controllers/Si/CobrancasController.php`
**Size:** 39KB (1,037 lines)
**Risk Level:** MEDIUM

#### Issues:
- Input facade usage (deprecated)
- Complex ternary operators
- No critical mysql_* functions

#### Business Impact:
- Charge creation/editing
- Payment tracking
- Billing history

#### Estimated Effort: 1 week

---

### P2-B: Contract Management
**File:** `app/Http/Controllers/Si/ContratoController.php`
**Size:** 31KB
**Risk Level:** MEDIUM

#### Issues:
- Input facade usage
- Complex nested ternaries (line 302, 305)
- String concatenation with potential nulls

#### Business Impact:
- Contract CRUD operations
- Rental agreement management
- Client relationships

#### Estimated Effort: 1 week

---

### P2-C: Input Facade Deprecation
**Affected:** 20+ controller methods
**Risk Level:** MEDIUM (breaks in Laravel 6+)

#### Controllers:
- PoupancaController.php (9 instances)
- HistJurController.php (11 instances)
- Multiple others

#### Solution:
Simple search-replace or shim layer

#### Estimated Effort: 2 days

---

## PRIORITY 3: SECONDARY FEATURES

### P3-A: Type Safety (strlen with nulls)
**Affected:** 30+ methods across multiple controllers
**Risk Level:** LOW (deprecation warning only)

#### Pattern:
```php
for ($i = strlen($X) - 1; $i >= 0; $i--) { }
```

#### Solution:
Null-safe wrapper function

#### Estimated Effort: 3 days

---

### P3-B: Reports & Analytics
**Risk Level:** LOW
**Impact:** Formatting issues, no critical failures

---

## TIMELINE SUMMARY

### Critical Path (Cannot Deploy Without)
| Task | Effort | Dependencies | Start | Complete |
|------|--------|--------------|-------|----------|
| Deploy shim layers | 3 days | None | Week 1 | Week 1 |
| Test receipt generation | 5 days | Shims + staging | Week 1 | Week 2 |
| Upgrade boleto package | 1 week | None | Week 2 | Week 2 |
| Audit BoletoController | 1 week | Package upgrade | Week 3 | Week 3 |
| Rewrite ReciboController | 2 weeks | Shims tested | Week 2 | Week 4 |
| Integration testing | 1 week | All above | Week 4 | Week 5 |

**Minimum Viable Migration:** 5 weeks
**Safe Migration with Buffer:** 8 weeks

### Optional Improvements (Can Deploy Then Refactor)
| Task | Effort | Priority |
|------|--------|----------|
| Replace Input facade | 2 days | P2 |
| Add null safety | 3 days | P3 |
| Refactor large controllers | 4 weeks | P3 |

---

## RISK HEAT MAP

```
SEVERITY →  LOW         MEDIUM          HIGH          CRITICAL
─────────────────────────────────────────────────────────────────
PAYMENT     │           │               │ Boleto       │ Receipt
            │           │               │ Generation   │ Generation
─────────────────────────────────────────────────────────────────
CRUD        │           │ Contracts     │ Charges      │
            │           │ Management    │ Management   │
─────────────────────────────────────────────────────────────────
FRAMEWORK   │           │ Input Facade  │              │
            │           │ Deprecation   │              │
─────────────────────────────────────────────────────────────────
REPORTS     │ strlen()  │               │              │
            │ null safe │               │              │
─────────────────────────────────────────────────────────────────
```

---

## DEPLOYMENT STRATEGY

### Week 1-2: Foundation (Can't skip)
✓ Deploy compatibility shims
✓ Set up PHP 8.1 staging
✓ Test critical paths on staging

### Week 3-4: Core Migration (Minimum viable)
✓ Upgrade boleto package
✓ Fix ReciboController
✓ Fix Input facade usage

### Week 5: Validation (Required)
✓ Integration testing
✓ Performance benchmarking
✓ User acceptance testing

### Week 6-8: Staged Rollout (Recommended)
✓ 10% traffic to PHP 8.1
✓ 50% traffic after validation
✓ 100% cutover

### Week 9-12: Cleanup (Optional but recommended)
✓ Remove shim layers
✓ Refactor code for PHP 8.1 native features
✓ Performance optimization

---

## ROLLBACK TRIGGERS

### Automatic Rollback If:
- Error rate > 1% increase
- Receipt generation fails
- Boleto generation fails
- Database corruption detected
- Response time > 50% slower

### Manual Rollback Decision If:
- Error rate 0.5-1% increase
- Non-critical features broken
- Customer complaints > threshold
- Performance degradation 25-50%

---

## SUCCESS METRICS

### Must Achieve (Go/No-Go):
- ✓ Receipt generation: 0% error rate
- ✓ Boleto generation: 100% accuracy
- ✓ Payment processing: <0.1% error increase
- ✓ Zero data corruption

### Should Achieve (Quality):
- ✓ Response time: <10% increase
- ✓ Memory usage: <20% increase
- ✓ Error logs: No new PHP warnings

### Nice to Have (Optimization):
- ✓ Response time: Improved
- ✓ Memory usage: Optimized
- ✓ Code quality: Refactored

---

## COORDINATOR NOTES FOR QUEEN

### BLOCKERS IDENTIFIED:
1. **ReciboController MUST be fixed** - No workaround possible
2. **Boleto package MUST be upgraded** - Current version too old
3. **PHP 8.1 staging MUST be set up** - Cannot test without it

### RECOMMENDED APPROACH:
1. **Week 1:** Deploy shims, set up staging (CODER + TESTER)
2. **Week 2-4:** Fix critical path (CODER focus on Receipt + Boleto)
3. **Week 5:** Comprehensive testing (TESTER full regression)
4. **Week 6-8:** Gradual rollout with monitoring (ALL AGENTS)

### RESOURCES NEEDED:
- Staging server with PHP 8.1
- Access to falgimoveis11 database for testing
- Itaú bank test credentials (if available)
- 2-3 developers (CODER agents) for parallel work
- 1 dedicated tester (TESTER agent)
- Monitoring setup (MONITOR agent if available)

### ESTIMATED COST:
- Development time: 8 weeks × 2 developers = 16 dev-weeks
- Testing time: 5 weeks × 1 tester = 5 test-weeks
- Total: 21 person-weeks for safe migration

### RISK LEVEL: HIGH → MEDIUM (with shim strategy)
Original risk was HIGH due to breaking changes.
With shim layers and staged approach: MEDIUM (manageable).

---

**Report Status:** COMPLETE
**Next Action:** CODER agent to implement shim layers
**Blocking:** None - can start immediately

**Generated:** 2025-10-13 by ANALYST Agent
