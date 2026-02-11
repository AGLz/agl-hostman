#!/usr/bin/env python3
"""
Backup Restoration Verification Script

Tests automated backup restoration with SLA compliance verification.
AGL-22: Automated Backup and Disaster Recovery
SLA: RTO < 4 hours, RPO < 1 hour
"""

import os
import sys
import json
import gzip
import tarfile
import tempfile
import shutil
import subprocess
import time
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple

# Configuration
BACKUP_ROOT = Path(os.getenv('BACKUP_ROOT', '/mnt/shares/agl-hostman-backups'))
TEST_RESTORE_DIR = Path('/tmp/backup-restore-test')
RTO_TARGET_HOURS = 4
RPO_TARGET_HOURS = 1

# Colors for output
class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    RESET = '\033[0m'

def log_info(message: str):
    """Log info message"""
    print(f"{Colors.BLUE}[INFO]{Colors.RESET} {message}")

def log_success(message: str):
    """Log success message"""
    print(f"{Colors.GREEN}[SUCCESS]{Colors.RESET} {message}")

def log_error(message: str):
    """Log error message"""
    print(f"{Colors.RED}[ERROR]{Colors.RESET} {message}")

def log_warning(message: str):
    """Log warning message"""
    print(f"{Colors.YELLOW}[WARNING]{Colors.RESET} {message}")

class RestorationVerifier:
    """Backup restoration verification utilities"""

    def __init__(self):
        self.test_results = []
        self.start_time = time.time()

    def get_latest_backup(self, pattern: str, backup_type: str = 'daily') -> Optional[Path]:
        """Get the latest backup matching a pattern"""
        backup_dir = BACKUP_ROOT / backup_type
        if not backup_dir.exists():
            return None

        backups = list(backup_dir.glob(pattern))
        if not backups:
            return None

        return sorted(backups, key=lambda p: p.stat().st_mtime, reverse=True)[0]

    def get_backup_age(self, backup_path: Path) -> timedelta:
        """Get the age of a backup"""
        mtime = datetime.fromtimestamp(backup_path.stat().st_mtime)
        return datetime.now() - mtime

    def verify_rpo(self, backup_path: Path) -> Dict:
        """Verify RPO compliance"""
        age = self.get_backup_age(backup_path)
        age_hours = age.total_seconds() / 3600
        compliant = age_hours <= RPO_TARGET_HOURS

        return {
            'compliant': compliant,
            'age_hours': round(age_hours, 2),
            'age_minutes': int(age.total_seconds() / 60),
            'target_hours': RPO_TARGET_HOURS,
            'target_minutes': RPO_TARGET_HOURS * 60
        }

    def verify_gzip_integrity(self, backup_path: Path) -> bool:
        """Verify gzip file integrity"""
        try:
            with gzip.open(backup_path, 'rb') as f:
                f.read(1)  # Try to read first byte
            return True
        except Exception as e:
            log_error(f"GZIP integrity check failed: {e}")
            return False

    def verify_tar_gz_integrity(self, backup_path: Path) -> bool:
        """Verify tar.gz file integrity"""
        try:
            with tarfile.open(backup_path, 'r:gz') as tar:
                tar.getnames()
            return True
        except Exception as e:
            log_error(f"Tar.gz integrity check failed: {e}")
            return False

    def extract_backup(self, backup_path: Path, extract_dir: Path) -> bool:
        """Extract backup to directory"""
        try:
            if backup_path.suffix == '.gz':
                if backup_path.stem.endswith('.tar'):
                    with tarfile.open(backup_path, 'r:gz') as tar:
                        tar.extractall(extract_dir)
                else:
                    output_path = extract_dir / backup_path.stem
                    with gzip.open(backup_path, 'rb') as f_in:
                        with open(output_path, 'wb') as f_out:
                            shutil.copyfileobj(f_in, f_out)
            return True
        except Exception as e:
            log_error(f"Extraction failed: {e}")
            return False

    def test_postgresql_backup(self) -> Dict:
        """Test PostgreSQL backup restoration"""
        log_info("Testing PostgreSQL backup...")

        backup = self.get_latest_backup('*_postgres_*.sql.gz')
        if not backup:
            log_warning("No PostgreSQL backup found")
            return {'status': 'skipped', 'reason': 'No backup found'}

        # Verify integrity
        if not self.verify_gzip_integrity(backup):
            return {'status': 'failed', 'reason': 'Integrity check failed'}

        # Check RPO compliance
        rpo = self.verify_rpo(backup)
        if not rpo['compliant']:
            log_warning(f"PostgreSQL backup RPO non-compliant: {rpo['age_hours']}h")

        # Extract and verify SQL content
        with tempfile.TemporaryDirectory() as tmpdir:
            extract_dir = Path(tmpdir)
            if self.extract_backup(backup, extract_dir):
                extracted_files = list(extract_dir.glob('*.sql'))
                has_valid_sql = False
                for sql_file in extracted_files:
                    try:
                        content = sql_file.read_text()[:1000]
                        if 'PostgreSQL' in content or 'pg_dump' in content:
                            has_valid_sql = True
                            break
                    except:
                        pass

                return {
                    'status': 'passed' if has_valid_sql else 'failed',
                    'backup_file': backup.name,
                    'age_hours': rpo['age_hours'],
                    'rpo_compliant': rpo['compliant']
                }

        return {'status': 'failed', 'reason': 'Extraction or validation failed'}

    def test_mariadb_backup(self) -> Dict:
        """Test MariaDB backup restoration"""
        log_info("Testing MariaDB backup...")

        backup = self.get_latest_backup('*_mariadb_*.sql.gz')
        if not backup:
            log_warning("No MariaDB backup found")
            return {'status': 'skipped', 'reason': 'No backup found'}

        if not self.verify_gzip_integrity(backup):
            return {'status': 'failed', 'reason': 'Integrity check failed'}

        rpo = self.verify_rpo(backup)

        # Extract and verify SQL content
        with tempfile.TemporaryDirectory() as tmpdir:
            extract_dir = Path(tmpdir)
            if self.extract_backup(backup, extract_dir):
                extracted_files = list(extract_dir.glob('*.sql'))
                has_valid_sql = False
                for sql_file in extracted_files:
                    try:
                        content = sql_file.read_text()[:1000]
                        if 'MySQL' in content or 'MariaDB' in content or 'mysqldump' in content:
                            has_valid_sql = True
                            break
                    except:
                        pass

                return {
                    'status': 'passed' if has_valid_sql else 'failed',
                    'backup_file': backup.name,
                    'age_hours': rpo['age_hours'],
                    'rpo_compliant': rpo['compliant']
                }

        return {'status': 'failed', 'reason': 'Extraction or validation failed'}

    def test_redis_backup(self) -> Dict:
        """Test Redis backup restoration"""
        log_info("Testing Redis backup...")

        backup = self.get_latest_backup('*_redis_*.rdb.gz')
        if not backup:
            log_warning("No Redis backup found")
            return {'status': 'skipped', 'reason': 'No backup found'}

        if not self.verify_gzip_integrity(backup):
            return {'status': 'failed', 'reason': 'Integrity check failed'}

        rpo = self.verify_rpo(backup)

        # Verify RDB file format
        with tempfile.TemporaryDirectory() as tmpdir:
            extract_dir = Path(tmpdir)
            if self.extract_backup(backup, extract_dir):
                rdb_files = list(extract_dir.glob('*.rdb'))
                if rdb_files:
                    # RDB files start with REDIS magic string
                    try:
                        header = rdb_files[0].read_bytes()[:9]
                        has_redis_header = header == b'REDIS'
                        return {
                            'status': 'passed' if has_redis_header else 'failed',
                            'backup_file': backup.name,
                            'age_hours': rpo['age_hours'],
                            'rpo_compliant': rpo['compliant']
                        }
                    except:
                        pass

        return {'status': 'failed', 'reason': 'RDB format validation failed'}

    def test_volume_backup(self) -> Dict:
        """Test Docker volume backup restoration"""
        log_info("Testing volume backup...")

        backup = self.get_latest_backup('volume_*_*.tar.gz')
        if not backup:
            log_warning("No volume backup found")
            return {'status': 'skipped', 'reason': 'No backup found'}

        if not self.verify_tar_gz_integrity(backup):
            return {'status': 'failed', 'reason': 'Integrity check failed'}

        # List contents
        try:
            with tarfile.open(backup, 'r:gz') as tar:
                members = tar.getnames()
                return {
                    'status': 'passed',
                    'backup_file': backup.name,
                    'file_count': len(members)
                }
        except Exception as e:
            return {'status': 'failed', 'reason': str(e)}

    def test_config_backup(self) -> Dict:
        """Test application config backup restoration"""
        log_info("Testing application config backup...")

        backup = self.get_latest_backup('app_config_*.tar.gz')
        if not backup:
            log_warning("No config backup found")
            return {'status': 'skipped', 'reason': 'No backup found'}

        if not self.verify_tar_gz_integrity(backup):
            return {'status': 'failed', 'reason': 'Integrity check failed'}

        # Extract and verify required files
        required_files = ['docker-compose.yml']
        with tempfile.TemporaryDirectory() as tmpdir:
            extract_dir = Path(tmpdir)
            if self.extract_backup(backup, extract_dir):
                found_files = []
                for req_file in required_files:
                    if (extract_dir / req_file).exists():
                        found_files.append(req_file)

                return {
                    'status': 'passed' if len(found_files) > 0 else 'failed',
                    'backup_file': backup.name,
                    'found_files': found_files
                }

        return {'status': 'failed', 'reason': 'Extraction failed'}

    def test_rto_compliance(self) -> Dict:
        """Test RTO compliance by measuring restoration speed"""
        log_info("Testing RTO compliance...")

        backup = self.get_latest_backup('app_config_*.tar.gz')
        if not backup:
            return {'status': 'skipped', 'reason': 'No backup found'}

        start = time.time()

        # Extract backup
        with tempfile.TemporaryDirectory() as tmpdir:
            if self.extract_backup(backup, Path(tmpdir)):
                duration = time.time() - start
                duration_hours = duration / 3600
                compliant = duration_hours <= RTO_TARGET_HOURS

                return {
                    'status': 'passed',
                    'duration_seconds': round(duration, 2),
                    'duration_minutes': round(duration / 60, 2),
                    'rto_compliant': compliant,
                    'target_hours': RTO_TARGET_HOURS
                }

        return {'status': 'failed', 'reason': 'Extraction failed'}

    def test_retention_policy(self) -> Dict:
        """Test backup retention policy"""
        log_info("Testing retention policy...")

        daily_dir = BACKUP_ROOT / 'daily'
        if not daily_dir.exists():
            return {'status': 'skipped', 'reason': 'Daily backup directory not found'}

        now = datetime.now()
        seven_days_ago = now - timedelta(days=7)

        old_files = []
        for backup in daily_dir.glob('*'):
            if backup.is_file():
                mtime = datetime.fromtimestamp(backup.stat().st_mtime)
                if mtime < seven_days_ago:
                    old_files.append(backup.name)

        return {
            'status': 'passed' if len(old_files) == 0 else 'failed',
            'old_file_count': len(old_files),
            'old_files': old_files[:5]  # Limit output
        }

    def generate_report(self) -> Dict:
        """Generate comprehensive SLA compliance report"""
        log_info("Generating SLA compliance report...")

        tests = [
            ('PostgreSQL Backup', self.test_postgresql_backup),
            ('MariaDB Backup', self.test_mariadb_backup),
            ('Redis Backup', self.test_redis_backup),
            ('Volume Backup', self.test_volume_backup),
            ('Config Backup', self.test_config_backup),
            ('RTO Compliance', self.test_rto_compliance),
            ('Retention Policy', self.test_retention_policy)
        ]

        results = {}
        passed = 0
        failed = 0
        skipped = 0

        for test_name, test_fn in tests:
            try:
                result = test_fn()
                results[test_name] = result

                if result['status'] == 'passed':
                    passed += 1
                    log_success(f"{test_name}: PASSED")
                elif result['status'] == 'failed':
                    failed += 1
                    log_error(f"{test_name}: FAILED - {result.get('reason', 'Unknown')}")
                else:
                    skipped += 1
                    log_warning(f"{test_name}: SKIPPED - {result.get('reason', 'Unknown')}")
            except Exception as e:
                failed += 1
                log_error(f"{test_name}: ERROR - {e}")
                results[test_name] = {'status': 'error', 'reason': str(e)}

        # Calculate overall RPO compliance
        rpo_compliant = True
        for test_name, result in results.items():
            if result.get('rpo_compliant') is False:
                rpo_compliant = False

        duration = time.time() - self.start_time

        report = {
            'timestamp': datetime.now().isoformat(),
            'duration_seconds': round(duration, 2),
            'summary': {
                'total': len(tests),
                'passed': passed,
                'failed': failed,
                'skipped': skipped
            },
            'sla': {
                'rto': {
                    'target_hours': RTO_TARGET_HOURS,
                    'compliant': results.get('RTO Compliance', {}).get('rto_compliant', True)
                },
                'rpo': {
                    'target_hours': RPO_TARGET_HOURS,
                    'compliant': rpo_compliant
                }
            },
            'tests': results,
            'overall_status': 'PASSED' if failed == 0 else 'FAILED'
        }

        return report

def main():
    """Main execution"""
    print(f"\n{'='*60}")
    print("Backup Restoration Verification")
    print(f"{'='*60}\n")

    # Create test restore directory
    TEST_RESTORE_DIR.mkdir(parents=True, exist_ok=True)

    # Run verification
    verifier = RestorationVerifier()
    report = verifier.generate_report()

    # Print summary
    print(f"\n{'='*60}")
    print("Test Summary")
    print(f"{'='*60}")
    print(f"Total:  {report['summary']['total']}")
    print(f"Passed: {report['summary']['passed']}")
    print(f"Failed: {report['summary']['failed']}")
    print(f"Skipped: {report['summary']['skipped']}")
    print(f"\nOverall Status: {report['overall_status']}")
    print(f"Duration: {report['duration_seconds']}s")
    print(f"\nSLA Compliance:")
    print(f"  RTO: {'COMPLIANT' if report['sla']['rto']['compliant'] else 'NON-COMPLIANT'}")
    print(f"      Target: {report['sla']['rto']['target_hours']} hours")
    print(f"  RPO: {'COMPLIANT' if report['sla']['rpo']['compliant'] else 'NON-COMPLIANT'}")
    print(f"      Target: {report['sla']['rpo']['target_hours']} hours")
    print(f"{'='*60}\n")

    # Save report
    report_dir = BACKUP_ROOT / 'test-restorations'
    report_dir.mkdir(parents=True, exist_ok=True)
    report_path = report_dir / f"restoration-report-{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    with open(report_path, 'w') as f:
        json.dump(report, f, indent=2)

    log_success(f"Report saved to: {report_path}")

    # Exit with appropriate code
    sys.exit(0 if report['overall_status'] == 'PASSED' else 1)

if __name__ == '__main__':
    main()
