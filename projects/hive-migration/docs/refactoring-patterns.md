# Refactoring Patterns for PHP 7.4 → 8.1 Migration

## Overview
Common code patterns in PHP 7.4 that require refactoring for PHP 8.1 compatibility.

## Pattern Categories

### 1. Null Safety Refactoring

#### Pattern: Unsafe strlen()
```php
// PHP 7.4 - Works but deprecated
function getLength($value) {
    return strlen($value);  // Works even if $value is null
}

// PHP 8.1 - Safe version
function getLength(?string $value): int {
    return strlen($value ?? '');
}

// Or with null coalescing operator
function getLength(?string $value): int {
    return $value !== null ? strlen($value) : 0;
}

// Refactoring pattern
BEFORE: strlen($var)
AFTER:  strlen($var ?? '')
```

#### Pattern: Array access with possible null
```php
// PHP 7.4
$data = fetchData();
$value = $data['key'];  // Notice if key doesn't exist

// PHP 8.1 - Explicit null handling
$data = fetchData() ?? [];
$value = $data['key'] ?? null;

// Or null safe operator
$value = $data?->get('key');
```

### 2. Type Declaration Patterns

#### Pattern: Add scalar type hints
```php
// PHP 7.4 - Loose typing
function processUser($id, $name, $active) {
    // ...
}

// PHP 8.1 - Strict typing
function processUser(int $id, string $name, bool $active): void {
    // ...
}

// Refactoring pattern
SEARCH:  function (\w+)\((.*?)\)
REPLACE: function $1($2): void  // Determine return type
```

#### Pattern: Union types for flexible parameters
```php
// PHP 7.4
/**
 * @param int|string $id
 */
function findUser($id) {
    // ...
}

// PHP 8.1
function findUser(int|string $id): ?User {
    // ...
}
```

#### Pattern: Mixed type for unknown
```php
// PHP 7.4
function parseValue($input) {
    return json_decode($input);
}

// PHP 8.1
function parseValue(string $input): mixed {
    return json_decode($input, true);
}
```

### 3. Error Handling Modernization

#### Pattern: JSON exception handling
```php
// PHP 7.4
function parseJson($json) {
    $data = json_decode($json, true);
    if (json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('JSON decode failed: ' . json_last_error_msg());
    }
    return $data;
}

// PHP 8.1
function parseJson(string $json): array {
    try {
        return json_decode($json, true, 512, JSON_THROW_ON_ERROR);
    } catch (JsonException $e) {
        throw new InvalidArgumentException('Invalid JSON: ' . $e->getMessage(), 0, $e);
    }
}
```

#### Pattern: Try-catch for internal functions
```php
// PHP 7.4
if ($denominator != 0) {
    $result = $numerator / $denominator;
} else {
    $result = 0;
}

// PHP 8.1 - Use exception handling
try {
    $result = $numerator / $denominator;
} catch (DivisionByZeroError $e) {
    $result = 0;
    // Or log error
}
```

### 4. String/Number Coercion Fixes

#### Pattern: Explicit type casting for arithmetic
```php
// PHP 7.4 - May work with strings
function calculateTotal($price, $quantity) {
    return $price * $quantity;  // Works if strings are numeric
}

// PHP 8.1 - Explicit casting
function calculateTotal(string|float $price, string|int $quantity): float {
    return (float)$price * (int)$quantity;
}

// Regex pattern for refactoring
SEARCH:  (\$\w+)\s*([+\-*/])\s*(\$\w+)
CHECK:   Are these variables guaranteed to be numeric?
REPLACE: (float)$1 $2 (int)$3  // Cast appropriately
```

#### Pattern: String offset access
```php
// PHP 7.4
$char = $string[$offset];  // Works even if offset is invalid

// PHP 8.1 - Validate first
if (isset($string[$offset])) {
    $char = $string[$offset];
} else {
    $char = '';
}

// Or use mb_substr for safety
$char = mb_substr($string, $offset, 1) ?: '';
```

### 5. Removed Function Replacements

#### Pattern: each() replacement
```php
// PHP 7.4
while (list($key, $value) = each($array)) {
    echo "$key => $value\n";
}

// PHP 8.1 - Use foreach
foreach ($array as $key => $value) {
    echo "$key => $value\n";
}

// Or for specific needs
reset($array);
while (($current = current($array)) !== false) {
    $key = key($array);
    echo "$key => $current\n";
    next($array);
}
```

#### Pattern: create_function() replacement
```php
// PHP 7.4
$func = create_function('$a,$b', 'return $a + $b;');
$result = $func(1, 2);

// PHP 8.1 - Use closure
$func = function($a, $b) {
    return $a + $b;
};
$result = $func(1, 2);

// Or arrow function for simple cases
$func = fn($a, $b) => $a + $b;
$result = $func(1, 2);
```

#### Pattern: money_format() replacement
```php
// PHP 7.4
$formatted = money_format('%.2n', $amount);

// PHP 8.1 - Use NumberFormatter
$formatter = new NumberFormatter('en_US', NumberFormatter::CURRENCY);
$formatted = $formatter->formatCurrency($amount, 'USD');

// Create helper function
function formatMoney(float $amount, string $currency = 'USD', string $locale = 'en_US'): string {
    static $formatter = null;
    if ($formatter === null) {
        $formatter = new NumberFormatter($locale, NumberFormatter::CURRENCY);
    }
    return $formatter->formatCurrency($amount, $currency);
}
```

### 6. Class and Method Refactoring

#### Pattern: Constructor property promotion
```php
// PHP 7.4
class User {
    private int $id;
    private string $name;
    private string $email;

    public function __construct(int $id, string $name, string $email) {
        $this->id = $id;
        $this->name = $name;
        $this->email = $email;
    }
}

// PHP 8.1 - Modern syntax (optional optimization)
class User {
    public function __construct(
        private int $id,
        private string $name,
        private string $email
    ) {}
}
```

#### Pattern: Match expression for cleaner logic
```php
// PHP 7.4
function getStatusMessage($status) {
    switch ($status) {
        case 'pending':
            return 'Order is pending';
        case 'processing':
            return 'Order is being processed';
        case 'completed':
            return 'Order is completed';
        case 'cancelled':
            return 'Order was cancelled';
        default:
            return 'Unknown status';
    }
}

// PHP 8.1 - Match expression
function getStatusMessage(string $status): string {
    return match($status) {
        'pending' => 'Order is pending',
        'processing' => 'Order is being processed',
        'completed' => 'Order is completed',
        'cancelled' => 'Order was cancelled',
        default => 'Unknown status'
    };
}
```

#### Pattern: Named arguments for clarity
```php
// PHP 7.4 - Positional arguments
$user = createUser('John', 'john@example.com', true, 'admin', 30);

// PHP 8.1 - Named arguments (improves readability)
$user = createUser(
    name: 'John',
    email: 'john@example.com',
    active: true,
    role: 'admin',
    age: 30
);
```

### 7. Array and Collection Patterns

#### Pattern: Array key validation
```php
// PHP 7.4
$value = $array[$key];  // Notice if key doesn't exist

// PHP 8.1 - Explicit check
$value = array_key_exists($key, $array) ? $array[$key] : null;

// Or null coalescing
$value = $array[$key] ?? null;

// Array access method
$value = $array[$key] ?? throw new InvalidArgumentException("Key $key not found");
```

#### Pattern: Typed array handling
```php
// PHP 7.4
function processItems($items) {
    foreach ($items as $item) {
        // Process
    }
}

// PHP 8.1 - Explicit typing
function processItems(array $items): void {
    foreach ($items as $item) {
        if (!$item instanceof Item) {
            throw new InvalidArgumentException('Invalid item type');
        }
        // Process
    }
}

// Or with validation
/** @param Item[] $items */
function processItems(array $items): void {
    array_walk($items, function($item) {
        assert($item instanceof Item);
    });
    // Process
}
```

### 8. Static Analysis Suppressions

#### Pattern: PHPStan/Psalm annotations for edge cases
```php
// When you need to bypass strict checks for legacy code
class LegacyAdapter {
    /**
     * @phpstan-ignore-next-line
     * @psalm-suppress MixedArgument
     */
    public function processLegacyData($data) {
        // Legacy code that can't be strictly typed yet
        return legacy_function($data);
    }
}
```

## Automated Refactoring Tools

### Rector Configuration
```php
// rector.php
use Rector\Config\RectorConfig;
use Rector\Set\ValueObject\LevelSetList;

return static function (RectorConfig $rectorConfig): void {
    $rectorConfig->paths([
        __DIR__ . '/src',
        __DIR__ . '/app',
    ]);

    // PHP 8.1 rules
    $rectorConfig->sets([
        LevelSetList::UP_TO_PHP_81,
    ]);

    // Skip patterns that need manual review
    $rectorConfig->skip([
        '**/vendor/*',
        '**/legacy/*',
    ]);
};
```

### PHPStan Configuration
```neon
# phpstan.neon
parameters:
    level: 8
    paths:
        - src
        - app
    excludePaths:
        - */vendor/*
        - */legacy/*

    # Report all null safety issues
    checkNullables: true
    checkMissingIterableValueType: true
    checkGenericClassInNonGenericObjectType: true
```

## Refactoring Workflow

### Step 1: Static Analysis
```bash
# Run PHPStan to identify issues
vendor/bin/phpstan analyse --level=8

# Run Psalm for additional checks
vendor/bin/psalm --show-info=true
```

### Step 2: Automated Refactoring
```bash
# Run Rector with dry-run first
vendor/bin/rector process --dry-run

# Apply changes
vendor/bin/rector process
```

### Step 3: Manual Review
- Review all changes in version control
- Test critical paths
- Update tests if needed

### Step 4: Validation
```bash
# Syntax check
find . -name "*.php" -exec php -l {} \;

# Run test suite
vendor/bin/phpunit

# Code style
vendor/bin/php-cs-fixer fix --dry-run
```

## Priority Refactoring Checklist

### Phase 1: Critical (Breaks in PHP 8.1)
- [ ] Replace removed functions (each, create_function, money_format)
- [ ] Fix null passing to non-nullable internal functions
- [ ] Fix string to number coercion in arithmetic
- [ ] Update JSON handling to use exceptions

### Phase 2: High (Warnings/Notices)
- [ ] Add type declarations to functions
- [ ] Fix undefined array key access
- [ ] Fix undefined variable usage
- [ ] Update error handling patterns

### Phase 3: Medium (Improvements)
- [ ] Use constructor property promotion
- [ ] Replace switch with match where appropriate
- [ ] Add union types for flexibility
- [ ] Implement named arguments for clarity

### Phase 4: Low (Optional)
- [ ] Use attributes instead of annotations
- [ ] Optimize with arrow functions
- [ ] Leverage new string functions
- [ ] Use enum for constants (PHP 8.1+)

## Common Gotchas

### 1. Hidden Type Coercion
Watch for implicit string to number conversion in comparisons:
```php
// May break in PHP 8.1
if ("10 apples" == 10) { }  // true in 7.4, could behave differently

// Use strict comparison
if ((int)"10 apples" === 10) { }
```

### 2. Array Access on Objects
```php
// PHP 7.4 - Might work with ArrayAccess
$value = $object['key'];

// PHP 8.1 - Ensure ArrayAccess is properly implemented
if ($object instanceof ArrayAccess) {
    $value = $object['key'];
}
```

### 3. Dynamic Property Creation
```php
// PHP 7.4 - Works
$obj = new stdClass();
$obj->newProp = 'value';

// PHP 8.1 - Deprecated warning
// Use array or explicitly define properties
$obj = (object)['newProp' => 'value'];
```

---
*Status*: PATTERN LIBRARY COMPLETE
*Usage*: Reference during code transformation phase
*Next*: Apply patterns to actual API1 codebase after Researcher analysis
