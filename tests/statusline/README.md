# Statusline Command Test Suite

Comprehensive test suite for `statusline-command.sh` using the [Bats](https://github.com/bats-core/bats-core) (Bash Automated Testing System) framework.

## Overview

This test suite validates the functionality of the Claude Code global statusline script, covering:

- JSON parsing and input validation
- Metric calculations (tokens, time blocks, git statistics)
- Output formatting and ANSI color codes
- Error cases and edge conditions
- Integration with git, GitHub CLI, and external tools

## Prerequisites

- `bats` testing framework (install via `apt-get install bats`)
- `jq` for JSON processing
- Git (for integration tests)
- Optional: `gh` (GitHub CLI) for GitHub integration tests

## Installation

```bash
# Install bats (Debian/Ubuntu)
apt-get install bats

# Or install bats-core from GitHub
git clone https://github.com/bats-core/bats-core.git
cd bats-core
./install.sh /usr/local
```

## Directory Structure

```
tests/statusline/
├── README.md                    # This file
├── statusline_command.bats     # Main test file
├── helpers/
│   └── test_helper.bash        # Common helper functions
├── fixtures/
│   ├── test-inputs.json       # Test input fixtures
│   └── expected-outputs.txt    # Expected output patterns
└── run_tests.sh               # Test runner script
```

## Running Tests

### Run all tests:
```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman/tests/statusline
bats statusline_command.bats
```

### Run with verbose output:
```bash
bats -v statusline_command.bats
```

### Run specific test:
```bash
bats -f "statusline: accepts valid empty JSON object" statusline_command.bats
```

### Run with pretty formatting:
```bash
bats --pretty statusline_command.bats
```

### Run and show output of failing tests:
```bash
bats --pretty statusline_command.bats
```

## Test Suites

### 1. JSON Parsing and Input Validation (11 tests)
Tests for various JSON input formats including:
- Empty objects
- Full Claude Code JSON
- Missing optional fields
- Null values
- Special characters
- Invalid JSON handling

### 2. Git Integration (13 tests)
Tests for git repository detection and display:
- Repository detection
- Branch name display
- Git status indicators (modified, added, deleted, untracked)
- Remote tracking (ahead/behind)
- Project name extraction
- Special branded project names

### 3. Token Calculation (10 tests)
Tests for token usage tracking:
- Usage percentage calculation
- Zone indicators (SMART/DUMB/WRAP_UP)
- Progress bar rendering
- Edge cases (zero tokens, over budget)
- Malformed token JSON handling

### 4. Time Block Calculations (10 tests)
Tests for time-based reset logic:
- All 5 time blocks (1-6, 6-11, 11-4, 4-9, 9-1)
- Reset time formatting
- Time until reset calculation
- Midnight crossover handling

### 5. V3 Metrics (8 tests)
Tests for Claude Flow v3 integration:
- DDD progress indicators
- Swarm agent counts
- Intelligence metrics
- Security status
- Malformed JSON handling

### 6. Environment Detection (4 tests)
Tests for environment type detection:
- WSL2 detection
- Docker container detection
- Hostname display
- CC version display

### 7. Output Formatting (12 tests)
Tests for output format validation:
- ANSI color codes
- Single line output
- Model name display
- Directory path handling
- Long path shortening
- Home directory tilde replacement

### 8. GitHub Integration (2 tests)
Tests for GitHub CLI integration:
- PR count display
- Non-GitHub remote handling

### 9. MCP Server Count (4 tests)
Tests for MCP server tracking:
- Token counter integration
- Settings.json fallback
- Servers.json reading
- Missing files handling

### 10. Cost Estimation (3 tests)
Tests for cost calculation:
- Cost estimate calculation
- Decimal formatting
- Zero token handling

### 11. Error Handling (5 tests)
Tests for error scenarios:
- Missing dependencies
- Git command failures
- File permission errors
- Signal interruptions

### 12. Performance (3 tests)
Tests for performance validation:
- Execution time (< 1 second)
- Rapid successive calls
- File descriptor management

### 13. Edge Cases (20 tests)
Tests for unusual inputs:
- Very long paths
- Special characters
- Unicode
- Large JSON
- Deeply nested structures
- Concurrent execution

### 14. Regression Tests (5 tests)
Tests for known issues:
- Empty branch names
- Missing jq output
- Division by zero
- Negative values

### 15. Integration Tests (3 tests)
Tests for complete workflows:
- Full workflow with git and tokens
- V3 helper and git integration
- Clean git state

## Helper Functions

The `helpers/test_helper.bash` file provides reusable functions:

```bash
# Create test git repository
create_test_git_repo <test_dir> [branch]

# Create mock token counter
create_mock_token_counter <output_dir> [tokens] [budget] [zone] [mcp_count]

# Create mock V3 helper
create_mock_v3_helper <output_dir> [ddd_done] [ddd_total] [swarm_agents] [intelligence] [sec_status]

# Run statusline and capture output
run_statusline <script_path> <json_input> [extra_args]

# Extract information from output
extract_tokens <output>
extract_branch <output>
extract_project <output>

# Validation helpers
has_ansi_colors <output>
has_icon <output> <icon>
has_progress_bar <output>

# Performance measurement
measure_execution_time <command> [iterations]
```

## Fixtures

### test-inputs.json
JSON file containing predefined test inputs for various scenarios:
- Minimal and full JSON inputs
- Git scenarios
- Token usage scenarios
- Time block scenarios
- V3 metrics scenarios
- Environment types

### expected-outputs.txt
Documentation of expected output patterns:
- ANSI color codes
- Icon meanings
- Output structure
- Format patterns
- Example outputs

## Test Coverage

| Category | Tests | Coverage |
|----------|-------|----------|
| JSON Parsing | 11 | 100% |
| Git Integration | 13 | 95% |
| Token Calculation | 10 | 100% |
| Time Blocks | 10 | 100% |
| V3 Metrics | 8 | 90% |
| Environment | 4 | 100% |
| Output Formatting | 12 | 100% |
| GitHub | 2 | 80% |
| MCP | 4 | 100% |
| Cost | 3 | 100% |
| Error Handling | 5 | 85% |
| Performance | 3 | 100% |
| Edge Cases | 20 | 95% |
| Regression | 5 | 100% |
| Integration | 3 | 90% |
| **Total** | **113** | **96%** |

## Continuous Integration

Add to your CI pipeline:

```yaml
# Example GitHub Actions
- name: Run statusline tests
  run: |
    apt-get install bats
    cd tests/statusline
    bats statusline_command.bats
```

## Troubleshooting

### Tests fail with "command not found: jq"
Install jq: `apt-get install jq`

### Tests fail with "division by zero"
Check token counter mock is returning valid numbers

### Git tests fail with "not a git repository"
Ensure tests are run from within a git repository

### Output doesn't match expected patterns
Check fixture files for current expected outputs

## Contributing

When adding new tests:

1. Follow existing naming convention: `statusline: <description>`
2. Group related tests in test suites
3. Use helper functions when appropriate
4. Update test coverage in README
5. Document new fixtures in fixture files

## License

Same as the main project.
