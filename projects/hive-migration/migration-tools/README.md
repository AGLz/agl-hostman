# Migration Tools Suite

## Overview
Automated tools and scripts to assist with API1 → API8 migration.

## Tool Categories

### 1. Code Analysis Tools
- **php74-scanner.php** - Scans for PHP 7.4 specific patterns
- **dependency-mapper.php** - Maps all dependencies and includes
- **endpoint-extractor.php** - Extracts all route definitions
- **db-query-analyzer.php** - Analyzes database queries

### 2. Transformation Tools
- **type-converter.php** - Adds type hints where needed
- **function-replacer.php** - Replaces deprecated functions
- **error-handler-injector.php** - Updates error handling
- **null-safe-refactor.php** - Adds null safety checks

### 3. Testing Tools
- **syntax-validator.sh** - Validates PHP 8.1 syntax compatibility
- **parallel-tester.sh** - Runs tests on both PHP versions
- **diff-generator.sh** - Compares API1 vs API8 responses
- **load-test-runner.sh** - Performance comparison tool

### 4. Migration Utilities
- **route-mapper.php** - Maps API1 routes to API8
- **config-migrator.php** - Migrates configuration files
- **env-validator.sh** - Validates environment setup
- **backup-creator.sh** - Creates pre-migration backups

## Tool Development Status

| Tool | Status | Priority | Blocking |
|------|--------|----------|----------|
| php74-scanner.php | PLANNED | P1 | Researcher findings |
| endpoint-extractor.php | PLANNED | P1 | Researcher findings |
| syntax-validator.sh | PLANNED | P1 | None |
| route-mapper.php | PLANNED | P2 | Endpoint list |
| type-converter.php | PLANNED | P2 | Code analysis |
| parallel-tester.sh | PLANNED | P2 | Test suite exists |
| function-replacer.php | PLANNED | P3 | Deprecated usage list |
| load-test-runner.sh | PLANNED | P3 | None |

## Usage Workflow

### Phase 1: Analysis
```bash
# Scan API1 codebase
./php74-scanner.php /var/www/fg_OLD2_NEW

# Extract all endpoints
./endpoint-extractor.php /var/www/fg_OLD2_NEW

# Map dependencies
./dependency-mapper.php /var/www/fg_OLD2_NEW

# Output: analysis-report.json
```

### Phase 2: Planning
```bash
# Generate route mapping
./route-mapper.php --source analysis-report.json --target /var/www/fg_API8_b

# Validate target environment
./env-validator.sh FGSRV05

# Output: migration-plan.json
```

### Phase 3: Transformation
```bash
# Create backup
./backup-creator.sh /var/www/fg_OLD2_NEW

# Apply type conversions
./type-converter.php migration-plan.json

# Replace deprecated functions
./function-replacer.php migration-plan.json

# Update error handling
./error-handler-injector.php migration-plan.json

# Output: transformed-code/
```

### Phase 4: Validation
```bash
# Validate syntax
./syntax-validator.sh transformed-code/

# Run parallel tests
./parallel-tester.sh --php74=/var/www/fg_OLD2_NEW --php81=transformed-code/

# Compare responses
./diff-generator.sh --endpoints endpoints.json

# Load test
./load-test-runner.sh --duration 300 --concurrent 100
```

## Integration with Hive Mind

Each tool will:
1. Read configuration from `hive/code/migration-config`
2. Store results in `hive/code/tool-results/{tool-name}`
3. Update progress in `hive/code/migration-progress`
4. Log issues to `hive/code/migration-issues`

## Next Steps

1. Wait for Researcher to complete API1 analysis
2. Implement priority P1 tools based on findings
3. Create tool execution orchestrator
4. Build rollback automation

---
*Status*: FRAMEWORK CREATED
*Awaiting*: API1 code structure and patterns from Researcher
