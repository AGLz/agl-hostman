# Backup Restoration Tests

Comprehensive automated backup restoration testing suite for AGL-22.

## Overview

This test suite verifies backup restoration capabilities with SLA compliance:
- **RTO (Recovery Time Objective)**: < 4 hours
- **RPO (Recovery Point Objective)**: < 1 hour

## Test Coverage

### Backup Availability
- Daily backups present and accessible
- Correct file formats (gzip, tar.gz)
- Valid timestamps and metadata

### Integrity Verification
- GZIP archive integrity
- TAR archive structure
- SQL dump validity
- RDB file format check

### RPO Compliance
- Backup age verification
- Within 1-hour window
- Coverage across all data types

### Extraction Tests
- PostgreSQL SQL extraction
- MariaDB SQL extraction
- Redis RDB extraction
- Volume archive extraction
- Configuration extraction

### RTO Testing
- Restoration speed measurement
- Complete workflow validation
- Performance benchmarking

### Retention Policy
- Daily cleanup (7 days)
- Weekly promotion
- Monthly promotion

## Quick Start

```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman/tests/backup

# Run all tests
npm test

# Run Python tests
python3 verify_restoration.py

# Run Bash tests
bash test_restoration.sh

# Run with coverage
npm run test:coverage
```

## Test Results

Test results are saved to:
```
/mnt/shares/agl-hostman-backups/test-restorations/
```

Results include:
- JSON reports for automation
- Text reports for human review
- SLA compliance metrics

## Dashboard

View the test results dashboard:

```bash
# Start local dashboard server
npm run dashboard

# Open in browser
open http://localhost:8080/dashboard.html
```

## Configuration

Environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `BACKUP_ROOT` | `/mnt/shares/agl-hostman-backups` | Backup directory |
| `RTO_TARGET_HOURS` | `4` | RTO target in hours |
| `RPO_TARGET_HOURS` | `1` | RPO target in hours |

## Troubleshooting

### Test Failures

1. Check backup directory exists
2. Verify backup permissions
3. Check disk space
4. Review logs in test output

### Missing Backups

If tests report missing backups:
1. Check backup job status: `systemctl status backup.timer`
2. Review backup logs: `journalctl -u backup.service`
3. Verify storage mount: `df -h /mnt/shares/`

### Timeout Issues

Increase test timeout:
```bash
# Jest
jest --testTimeout=300000

# Python
export TEST_TIMEOUT=300
python3 verify_restoration.py
```

## Development

### Adding New Tests

1. Create test in appropriate file:
   - `restoration.test.js` for Jest tests
   - `verify_restoration.py` for Python tests
   - `test_restoration.sh` for Bash tests

2. Follow naming convention:
   - Test function: `test_<feature>`
   - Test description: Clear and specific

3. Update documentation

### Code Style

- JavaScript: Standard ESLint rules
- Python: PEP 8
- Bash: ShellCheck

## Related Documentation

- [Backup Restoration Guide](/docs/backup-restoration-guide.md)
- [Backup Configuration](/ops/backup/backup-config.env)
- [Disaster Recovery Plan](/docs/disaster-recovery.md)

## Support

For issues or questions, see:
- AGL-22 in project tracking
- Infrastructure team contact
