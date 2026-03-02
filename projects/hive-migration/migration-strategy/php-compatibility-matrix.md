# PHP 7.4 → 8.1 Compatibility Matrix

## Overview
This document tracks compatibility issues and migration strategies for moving from PHP 7.4 to PHP 8.1.

## Breaking Changes by Category

### 1. Type System Changes

#### Stricter Type Checking
| Feature | PHP 7.4 Behavior | PHP 8.1 Behavior | Migration Strategy |
|---------|------------------|------------------|-------------------|
| Internal function types | Loose type checking | Strict type validation | Add explicit type casts |
| String to number coercion | Implicit | Explicit cast required | Audit arithmetic operations |
| Array key type juggling | Automatic | Strict validation | Validate array keys |

**Impact**: MEDIUM - Requires code audit and type validation

#### Union Types (New Feature)
```php
// PHP 7.4 - DocBlock only
/** @param int|string $value */
function process($value) {}

// PHP 8.1 - Native support
function process(int|string $value) {}
```
**Action**: Optional refactoring for better type safety

### 2. Syntax Changes

#### Constructor Property Promotion
```php
// PHP 7.4
class User {
    private string $name;
    private int $age;

    public function __construct(string $name, int $age) {
        $this->name = $name;
        $this->age = $age;
    }
}

// PHP 8.1 (backward compatible)
class User {
    public function __construct(
        private string $name,
        private int $age
    ) {}
}
```
**Action**: Optional modernization - backward compatible with 7.4 syntax

#### Named Arguments
```php
// PHP 8.1 introduces named arguments
function render($template, $data, $cache = true) {}

// Can be called with:
render(template: 'home', data: $data, cache: false);
```
**Risk**: If API1 has method signatures with parameters that might conflict
**Action**: Audit public APIs for parameter name stability

#### Match Expression
```php
// PHP 7.4
switch ($status) {
    case 'pending':
        $message = 'Waiting';
        break;
    case 'approved':
        $message = 'Done';
        break;
    default:
        $message = 'Unknown';
}

// PHP 8.1 (backward compatible)
$message = match($status) {
    'pending' => 'Waiting',
    'approved' => 'Done',
    default => 'Unknown'
};
```
**Action**: Optional modernization

### 3. Removed Functions and Features

#### Deprecated/Removed Functions
| Function | Status | Replacement | Impact |
|----------|--------|-------------|--------|
| `create_function()` | REMOVED | Anonymous functions/closures | HIGH |
| `each()` | REMOVED | `foreach()` or array iteration | HIGH |
| `money_format()` | REMOVED | `NumberFormatter` | MEDIUM |
| `ezmlm_hash()` | REMOVED | Custom implementation | LOW |
| `restore_include_path()` | REMOVED | Manual path management | LOW |

**Action**: Search API1 codebase for usage and refactor

#### Removed String/Number Conversion Behavior
```php
// PHP 7.4 - Warning
$result = "10 apples" + 5; // 15 with notice

// PHP 8.1 - Fatal Error
$result = "10 apples" + 5; // TypeError
```
**Risk**: CRITICAL - Will break existing code
**Action**: Audit all arithmetic operations with variables that might be strings

### 4. Error Handling Changes

#### Error to Exception Promotion
| Error Type | PHP 7.4 | PHP 8.1 | Migration |
|------------|---------|---------|-----------|
| Undefined variable | Notice | Warning | Add null coalescing |
| Undefined array key | Notice | Warning | Use `??` operator |
| Division by zero | Warning | `DivisionByZeroError` | Add validation |
| String offset access | Notice/Warning | TypeError | Validate types |

**Action**: Implement comprehensive error handling

### 5. Standard Library Changes

#### JSON Functions
```php
// PHP 8.1 throws JsonException instead of returning false
try {
    $data = json_decode($json, true, 512, JSON_THROW_ON_ERROR);
} catch (JsonException $e) {
    // Handle error
}
```
**Action**: Update JSON handling to use exceptions

#### Passing null to non-nullable internal functions
```php
// PHP 7.4 - Allowed (with warning)
strlen(null); // Returns 0

// PHP 8.1 - Deprecated/Error
strlen(null); // TypeError in future versions
```
**Risk**: HIGH - Common pattern
**Action**: Add null checks before internal function calls

### 6. Class and Object Changes

#### Static Method Inheritance
```php
class Parent {
    public static function method() {}
}

class Child extends Parent {
    public static function method(): void {} // Return type mismatch
}
```
**Risk**: MEDIUM - LSP (Liskov Substitution Principle) enforcement
**Action**: Audit inheritance hierarchies

#### Serialization Changes
- `__serialize()` and `__unserialize()` introduced
- Behavior with `__sleep()` and `__wakeup()` changed

**Action**: Review serialization logic if used

### 7. Performance Optimizations

#### JIT Compiler (PHP 8.0+)
- Just-In-Time compilation available
- May affect performance characteristics
- Requires testing under load

**Action**: Performance testing plan in migration

### 8. Security Improvements

#### Password Hashing
- Updated Argon2 implementation
- Improved default hash costs

**Action**: Review password handling code

## Migration Priority Matrix

### Priority 1: Critical (Breaking Changes)
1. String to number conversion in arithmetic
2. Removed functions (`create_function`, `each`)
3. Null to non-nullable parameter passing
4. Division by zero error handling

### Priority 2: High (Behavioral Changes)
1. JSON exception handling
2. Stricter type checking
3. Array key type validation
4. Error to exception promotions

### Priority 3: Medium (Improvements)
1. Static method inheritance
2. Constructor property promotion
3. Union types
4. Match expressions

### Priority 4: Low (Optional)
1. Named arguments support
2. Attributes vs annotations
3. JIT optimization testing

## Compatibility Shim Strategy

### Approach 1: Polyfill Removed Functions
Create compatibility layer for removed functions:
```php
if (!function_exists('each')) {
    function each(array &$array) {
        $key = key($array);
        if ($key === null) return false;
        $value = current($array);
        next($array);
        return [0 => $key, 1 => $value, 'key' => $key, 'value' => $value];
    }
}
```

### Approach 2: Type Safety Wrappers
Add type validation wrappers:
```php
function safe_strlen(?string $str): int {
    return strlen($str ?? '');
}
```

### Approach 3: Error Handler Bridge
Implement error to exception converter:
```php
set_error_handler(function($severity, $message, $file, $line) {
    if (error_reporting() & $severity) {
        throw new ErrorException($message, 0, $severity, $file, $line);
    }
});
```

## Testing Strategy

### 1. Static Analysis
- Run PHPStan/Psalm on PHP 7.4 code with level 8.1 target
- Use `php -l` for syntax validation
- Rector for automated refactoring detection

### 2. Runtime Testing
- Unit tests on both PHP versions
- Integration tests with real data
- Load testing for performance regression

### 3. Monitoring
- Error rate tracking post-migration
- Performance metrics comparison
- User-reported issue tracking

## Rollback Plan

### Triggers
- Error rate > 5% increase
- Response time > 50% degradation
- Critical feature failure
- Data corruption detected

### Procedure
1. Switch Nginx upstream to API1
2. Flush API8 caches
3. Restore database if needed
4. Post-mortem analysis

---
*Status*: FRAMEWORK CREATED - Awaiting API1 code analysis
*Next*: Researcher to provide actual code patterns from API1
