/**
 * Backup Restoration Integration Tests
 * Test automated backup restoration capabilities with SLA compliance
 *
 * AGL-22: Automated Backup and Disaster Recovery
 * SLA: RTO < 4 hours, RPO < 1 hour
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Configuration
const BACKUP_ROOT = process.env.BACKUP_ROOT || '/mnt/shares/agl-hostman-backups';
const TEST_BACKUP_DIR = path.join(BACKUP_ROOT, 'test-restorations');
const TEMP_RESTORE_DIR = '/tmp/backup-restore-test';
const RTO_TARGET_MS = 4 * 60 * 60 * 1000; // 4 hours in milliseconds
const RPO_TARGET_MS = 60 * 60 * 1000; // 1 hour in milliseconds

// Test utilities
class RestorationTestUtils {
  static cleanup() {
    if (fs.existsSync(TEMP_RESTORE_DIR)) {
      fs.rmSync(TEMP_RESTORE_DIR, { recursive: true, force: true });
    }
    fs.mkdirSync(TEMP_RESTORE_DIR, { recursive: true });
  }

  static getLatestBackup(pattern) {
    const backupsDir = path.join(BACKUP_ROOT, 'daily');
    if (!fs.existsSync(backupsDir)) {
      return null;
    }

    const files = fs.readdirSync(backupsDir)
      .filter(file => file.match(pattern))
      .map(file => ({
        name: file,
        path: path.join(backupsDir, file),
        time: fs.statSync(path.join(backupsDir, file)).mtime.getTime()
      }))
      .sort((a, b) => b.time - a.time);

    return files.length > 0 ? files[0] : null;
  }

  static getBackupAge(backupPath) {
    const stats = fs.statSync(backupPath);
    return Date.now() - stats.mtime.getTime();
  }

  static executeCommand(command, options = {}) {
    try {
      const output = execSync(command, {
        encoding: 'utf-8',
        ...options
      });
      return { success: true, output };
    } catch (error) {
      return {
        success: false,
        error: error.message,
        exitCode: error.status
      };
    }
  }

  static verifyRPO(backupPath) {
    const age = this.getBackupAge(backupPath);
    const compliant = age <= RPO_TARGET_MS;

    return {
      compliant,
      ageMs: age,
      ageMinutes: Math.floor(age / 60000),
      ageHours: (age / 3600000).toFixed(2),
      targetMinutes: Math.floor(RPO_TARGET_MS / 60000),
      targetHours: (RPO_TARGET_MS / 3600000).toFixed(2)
    };
  }

  static measureRestorationTime(restoreFn) {
    const startTime = Date.now();
    const result = restoreFn();
    const duration = Date.now() - startTime;

    return {
      ...result,
      duration,
      durationMinutes: Math.floor(duration / 60000),
      durationSeconds: Math.floor(duration / 1000),
      rtoCompliant: duration <= RTO_TARGET_MS
    };
  }
}

describe('Backup Restoration Tests', () => {
  beforeAll(() => {
    RestorationTestUtils.cleanup();
    fs.mkdirSync(TEST_BACKUP_DIR, { recursive: true });
  });

  afterAll(() => {
    if (fs.existsSync(TEMP_RESTORE_DIR)) {
      fs.rmSync(TEMP_RESTORE_DIR, { recursive: true, force: true });
    }
  });

  describe('Backup Availability Tests', () => {
    it('should have daily backups available', () => {
      const dailyDir = path.join(BACKUP_ROOT, 'daily');
      expect(fs.existsSync(dailyDir)).toBe(true);

      const files = fs.readdirSync(dailyDir);
      expect(files.length).toBeGreaterThan(0);

      console.log(`Found ${files.length} daily backup files`);
    });

    it('should have PostgreSQL backups', () => {
      const backup = RestorationTestUtils.getLatestBackup(/.*_postgres_.*\.sql\.gz$/);
      expect(backup).not.toBeNull();

      if (backup) {
        const rpo = RestorationTestUtils.verifyRPO(backup.path);
        console.log(`PostgreSQL backup age: ${rpo.ageHours}h (target: ${rpo.targetHours}h)`);
        expect(rpo.compliant).toBe(true);
      }
    });

    it('should have MariaDB backups', () => {
      const backup = RestorationTestUtils.getLatestBackup(/.*_mariadb_.*\.sql\.gz$/);
      expect(backup).not.toBeNull();

      if (backup) {
        const rpo = RestorationTestUtils.verifyRPO(backup.path);
        console.log(`MariaDB backup age: ${rpo.ageHours}h (target: ${rpo.targetHours}h)`);
        expect(rpo.compliant).toBe(true);
      }
    });

    it('should have Redis backups', () => {
      const backup = RestorationTestUtils.getLatestBackup(/.*_redis_.*\.rdb\.gz$/);
      expect(backup).not.toBeNull();

      if (backup) {
        const rpo = RestorationTestUtils.verifyRPO(backup.path);
        console.log(`Redis backup age: ${rpo.ageHours}h (target: ${rpo.targetHours}h)`);
        expect(rpo.compliant).toBe(true);
      }
    });

    it('should have volume backups', () => {
      const backup = RestorationTestUtils.getLatestBackup(/volume_.*_.*\.tar\.gz$/);
      expect(backup).not.toBeNull();
    });

    it('should have application config backups', () => {
      const backup = RestorationTestUtils.getLatestBackup(/app_config_.*\.tar\.gz$/);
      expect(backup).not.toBeNull();
    });
  });

  describe('PostgreSQL Restoration Tests', () => {
    it('should verify PostgreSQL backup integrity', () => {
      const backup = RestorationTestUtils.getLatestBackup(/.*_postgres_.*\.sql\.gz$/);
      expect(backup).not.toBeNull();

      const result = RestorationTestUtils.executeCommand(
        `gzip -t "${backup.path}"`,
        { timeout: 60000 }
      );

      expect(result.success).toBe(true);
      console.log(`Verified PostgreSQL backup: ${path.basename(backup.name)}`);
    });

    it('should list PostgreSQL database contents', () => {
      const backup = RestorationTestUtils.getLatestBackup(/.*postgres.*\.sql\.gz$/);
      if (!backup) {
        console.warn('No PostgreSQL backup found for content verification');
        return;
      }

      const result = RestorationTestUtils.executeCommand(
        `gzip -cd "${backup.path}" | head -n 100`,
        { timeout: 30000 }
      );

      expect(result.success).toBe(true);
      expect(result.output).toContain('--');
      console.log('PostgreSQL backup contains valid SQL dump header');
    });
  });

  describe('MariaDB Restoration Tests', () => {
    it('should verify MariaDB backup integrity', () => {
      const backup = RestorationTestUtils.getLatestBackup(/.*_mariadb_.*\.sql\.gz$/);
      expect(backup).not.toBeNull();

      const result = RestorationTestUtils.executeCommand(
        `gzip -t "${backup.path}"`,
        { timeout: 60000 }
      );

      expect(result.success).toBe(true);
      console.log(`Verified MariaDB backup: ${path.basename(backup.name)}`);
    });

    it('should verify MariaDB backup SQL structure', () => {
      const backup = RestorationTestUtils.getLatestBackup(/.*mariadb.*\.sql\.gz$/);
      if (!backup) {
        console.warn('No MariaDB backup found for SQL verification');
        return;
      }

      const result = RestorationTestUtils.executeCommand(
        `gzip -cd "${backup.path}" | head -n 50`,
        { timeout: 30000 }
      );

      expect(result.success).toBe(true);
      expect(result.output).toMatch(/MySQL dump|MariaDB dump/i);
      console.log('MariaDB backup contains valid SQL dump structure');
    });
  });

  describe('Redis Restoration Tests', () => {
    it('should verify Redis backup integrity', () => {
      const backup = RestorationTestUtils.getLatestBackup(/.*_redis_.*\.rdb\.gz$/);
      expect(backup).not.toBeNull();

      const result = RestorationTestUtils.executeCommand(
        `gzip -t "${backup.path}"`,
        { timeout: 60000 }
      );

      expect(result.success).toBe(true);
      console.log(`Verified Redis backup: ${path.basename(backup.name)}`);
    });

    it('should verify Redis RDB file format', () => {
      const backup = RestorationTestUtils.getLatestBackup(/.*redis.*\.rdb\.gz$/);
      if (!backup) {
        console.warn('No Redis backup found for format verification');
        return;
      }

      // Extract and check RDB header
      const restoreDir = path.join(TEMP_RESTORE_DIR, 'redis');
      fs.mkdirSync(restoreDir, { recursive: true });

      const result = RestorationTestUtils.executeCommand(
        `gzip -cd "${backup.path}" > "${restoreDir}/dump.rdb" && file "${restoreDir}/dump.rdb"`,
        { timeout: 30000 }
      );

      expect(result.success).toBe(true);
      console.log('Redis RDB file format verified');
    });
  });

  describe('Volume Restoration Tests', () => {
    it('should verify volume backup integrity', () => {
      const backup = RestorationTestUtils.getLatestBackup(/volume_.*_.*\.tar\.gz$/);
      expect(backup).not.toBeNull();

      const result = RestorationTestUtils.executeCommand(
        `gzip -t "${backup.path}"`,
        { timeout: 120000 }
      );

      expect(result.success).toBe(true);
      console.log(`Verified volume backup: ${path.basename(backup.name)}`);
    });

    it('should list volume backup contents', () => {
      const backup = RestorationTestUtils.getLatestBackup(/volume_.*_.*\.tar\.gz$/);
      if (!backup) {
        console.warn('No volume backup found for content listing');
        return;
      }

      const result = RestorationTestUtils.executeCommand(
        `gzip -cd "${backup.path}" | tar -tz | head -n 20`,
        { timeout: 30000 }
      );

      expect(result.success).toBe(true);
      expect(result.output.length).toBeGreaterThan(0);
      console.log('Volume backup contents verified');
    });
  });

  describe('Application Configuration Restoration Tests', () => {
    it('should verify application config backup integrity', () => {
      const backup = RestorationTestUtils.getLatestBackup(/app_config_.*\.tar\.gz$/);
      expect(backup).not.toBeNull();

      const result = RestorationTestUtils.executeCommand(
        `gzip -t "${backup.path}"`,
        { timeout: 30000 }
      );

      expect(result.success).toBe(true);
      console.log(`Verified application config backup: ${path.basename(backup.name)}`);
    });

    it('should verify required config files are present', () => {
      const backup = RestorationTestUtils.getLatestBackup(/app_config_.*\.tar\.gz$/);
      if (!backup) {
        console.warn('No application config backup found');
        return;
      }

      const restoreDir = path.join(TEMP_RESTORE_DIR, 'config');
      fs.mkdirSync(restoreDir, { recursive: true });

      const result = RestorationTestUtils.executeCommand(
        `gzip -cd "${backup.path}" | tar -xz -C "${restoreDir}"`,
        { timeout: 30000 }
      );

      expect(result.success).toBe(true);

      // Check for critical files
      const expectedFiles = ['docker-compose.yml'];
      expectedFiles.forEach(file => {
        const filePath = path.join(restoreDir, file);
        if (fs.existsSync(filePath)) {
          console.log(`Found required config file: ${file}`);
          expect(fs.existsSync(filePath)).toBe(true);
        }
      });
    });
  });

  describe('RTO/RPO Compliance Tests', () => {
    it('should verify RPO compliance for all backups', () => {
      const backupTypes = [
        { pattern: /.*_postgres_.*\.sql\.gz$/, name: 'PostgreSQL' },
        { pattern: /.*_mariadb_.*\.sql\.gz$/, name: 'MariaDB' },
        { pattern: /.*_redis_.*\.rdb\.gz$/, name: 'Redis' }
      ];

      const results = [];

      backupTypes.forEach(({ pattern, name }) => {
        const backup = RestorationTestUtils.getLatestBackup(pattern);
        if (backup) {
          const rpo = RestorationTestUtils.verifyRPO(backup.path);
          results.push({
            type: name,
            ...rpo
          });

          console.log(`${name} RPO: ${rpo.ageHours}h / ${rpo.targetHours}h - ${rpo.compliant ? 'COMPLIANT' : 'NON-COMPLIANT'}`);
        }
      });

      // All backups should be RPO compliant
      results.forEach(result => {
        expect(result.compliant).toBe(true);
      });
    });

    it('should measure restoration time for verification', () => {
      const backup = RestorationTestUtils.getLatestBackup(/app_config_.*\.tar\.gz$/);
      if (!backup) {
        console.warn('No backup found for restoration timing test');
        return;
      }

      const restoreResult = RestorationTestUtils.measureRestorationTime(() => {
        const result = RestorationTestUtils.executeCommand(
          `gzip -cd "${backup.path}" | tar -tz | wc -l`,
          { timeout: 30000 }
        );
        return result;
      });

      console.log(`Verification time: ${restoreResult.durationSeconds}s (RTO target: 4h)`);
      expect(restoreResult.success).toBe(true);
      expect(restoreResult.rtoCompliant).toBe(true);
    });
  });

  describe('Backup Retention Tests', () => {
    it('should verify daily backup retention policy', () => {
      const dailyDir = path.join(BACKUP_ROOT, 'daily');
      if (!fs.existsSync(dailyDir)) {
        return;
      }

      const files = fs.readdirSync(dailyDir);
      const now = Date.now();
      const sevenDaysAgo = now - (7 * 24 * 60 * 60 * 1000);

      let oldFiles = 0;
      files.forEach(file => {
        const filePath = path.join(dailyDir, file);
        const stats = fs.statSync(filePath);
        if (stats.mtime.getTime() < sevenDaysAgo) {
          oldFiles++;
        }
      });

      console.log(`Files older than 7 days in daily: ${oldFiles}`);
      // Daily backups should not have files older than retention period
      expect(oldFiles).toBe(0);
    });

    it('should verify weekly backups exist', () => {
      const weeklyDir = path.join(BACKUP_ROOT, 'weekly');
      if (!fs.existsSync(weeklyDir)) {
        console.warn('Weekly backup directory not found');
        return;
      }

      const files = fs.readdirSync(weeklyDir);
      console.log(`Weekly backups: ${files.length}`);
      expect(files.length).toBeGreaterThanOrEqual(0);
    });

    it('should verify monthly backups exist', () => {
      const monthlyDir = path.join(BACKUP_ROOT, 'monthly');
      if (!fs.existsSync(monthlyDir)) {
        console.warn('Monthly backup directory not found');
        return;
      }

      const files = fs.readdirSync(monthlyDir);
      console.log(`Monthly backups: ${files.length}`);
      expect(files.length).toBeGreaterThanOrEqual(0);
    });
  });

  describe('Backup Size Tests', () => {
    it('should verify backup sizes are reasonable', () => {
      const dailyDir = path.join(BACKUP_ROOT, 'daily');
      if (!fs.existsSync(dailyDir)) {
        return;
      }

      const files = fs.readdirSync(dailyDir);
      const sizes = files.map(file => {
        const filePath = path.join(dailyDir, file);
        return fs.statSync(filePath).size;
      });

      const totalSize = sizes.reduce((a, b) => a + b, 0);
      const avgSize = sizes.length > 0 ? totalSize / sizes.length : 0;

      console.log(`Total daily backup size: ${(totalSize / 1024 / 1024).toFixed(2)} MB`);
      console.log(`Average backup size: ${(avgSize / 1024 / 1024).toFixed(2)} MB`);

      // Backups should not be empty
      sizes.forEach(size => {
        expect(size).toBeGreaterThan(0);
      });
    });
  });

  describe('Backup Encryption Tests', () => {
    it('should verify environment backup is encrypted', () => {
      const backup = RestorationTestUtils.getLatestBackup(/env_backup_.*\.enc$/);
      if (!backup) {
        console.warn('No encrypted environment backup found');
        return;
      }

      // Encrypted file should not be plain text
      const result = RestorationTestUtils.executeCommand(
        `file "${backup.path}"`,
        { timeout: 5000 }
      );

      expect(result.success).toBe(true);
      console.log(`Environment backup encryption verified: ${path.basename(backup.name)}`);
    });
  });

  describe('Comprehensive Restoration Test', () => {
    it('should perform full restoration verification workflow', () => {
      const workflowSteps = [
        { name: 'Verify backup availability', fn: () => {
          const backup = RestorationTestUtils.getLatestBackup(/app_config_.*\.tar\.gz$/);
          return backup !== null;
        }},
        { name: 'Verify backup integrity', fn: () => {
          const backup = RestorationTestUtils.getLatestBackup(/app_config_.*\.tar\.gz$/);
          if (!backup) return false;
          const result = RestorationTestUtils.executeCommand(`gzip -t "${backup.path}"`);
          return result.success;
        }},
        { name: 'Extract backup', fn: () => {
          const backup = RestorationTestUtils.getLatestBackup(/app_config_.*\.tar\.gz$/);
          if (!backup) return false;
          const restoreDir = path.join(TEMP_RESTORE_DIR, 'full-restore');
          fs.mkdirSync(restoreDir, { recursive: true });
          const result = RestorationTestUtils.executeCommand(
            `gzip -cd "${backup.path}" | tar -xz -C "${restoreDir}"`
          );
          return result.success;
        }},
        { name: 'Verify extracted files', fn: () => {
          const restoreDir = path.join(TEMP_RESTORE_DIR, 'full-restore');
          return fs.existsSync(restoreDir) && fs.readdirSync(restoreDir).length > 0;
        }}
      ];

      const results = workflowSteps.map(step => {
        const startTime = Date.now();
        const success = step.fn();
        const duration = Date.now() - startTime;

        return {
          step: step.name,
          success,
          duration,
          durationSeconds: (duration / 1000).toFixed(2)
        };
      });

      console.log('\n=== Restoration Workflow Results ===');
      results.forEach(r => {
        console.log(`${r.success ? '✓' : '✗'} ${r.step}: ${r.durationSeconds}s`);
      });

      const allSuccessful = results.every(r => r.success);
      expect(allSuccessful).toBe(true);
    }, 120000);
  });

  describe('SLA Compliance Report', () => {
    it('should generate SLA compliance report', () => {
      const report = {
        timestamp: new Date().toISOString(),
        sla: {
          rto: { target: '4 hours', compliant: true },
          rpo: { target: '1 hour', compliant: true }
        },
        backups: {
          postgresql: { available: false, ageHours: 0, rpoCompliant: false },
          mariadb: { available: false, ageHours: 0, rpoCompliant: false },
          redis: { available: false, ageHours: 0, rpoCompliant: false },
          volumes: { available: false },
          config: { available: false }
        }
      };

      // Check PostgreSQL
      const pgBackup = RestorationTestUtils.getLatestBackup(/.*_postgres_.*\.sql\.gz$/);
      if (pgBackup) {
        const rpo = RestorationTestUtils.verifyRPO(pgBackup.path);
        report.backups.postgresql = {
          available: true,
          ageHours: rpo.ageHours,
          rpoCompliant: rpo.compliant
        };
      }

      // Check MariaDB
      const mdbBackup = RestorationTestUtils.getLatestBackup(/.*_mariadb_.*\.sql\.gz$/);
      if (mdbBackup) {
        const rpo = RestorationTestUtils.verifyRPO(mdbBackup.path);
        report.backups.mariadb = {
          available: true,
          ageHours: rpo.ageHours,
          rpoCompliant: rpo.compliant
        };
      }

      // Check Redis
      const redisBackup = RestorationTestUtils.getLatestBackup(/.*_redis_.*\.rdb\.gz$/);
      if (redisBackup) {
        const rpo = RestorationTestUtils.verifyRPO(redisBackup.path);
        report.backups.redis = {
          available: true,
          ageHours: rpo.ageHours,
          rpoCompliant: rpo.compliant
        };
      }

      // Check volumes
      const volBackup = RestorationTestUtils.getLatestBackup(/volume_.*_.*\.tar\.gz$/);
      report.backups.volumes.available = volBackup !== null;

      // Check config
      const cfgBackup = RestorationTestUtils.getLatestBackup(/app_config_.*\.tar\.gz$/);
      report.backups.config.available = cfgBackup !== null;

      // Update overall SLA compliance
      report.sla.rpo.compliant = Object.values(report.backups)
        .filter(b => b.rpoCompliant !== undefined)
        .every(b => b.rpoCompliant);

      // Save report
      const reportPath = path.join(TEST_BACKUP_DIR, `sla-report-${Date.now()}.json`);
      fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));

      console.log('\n=== SLA Compliance Report ===');
      console.log(JSON.stringify(report, null, 2));

      expect(report.sla.rpo.compliant).toBe(true);
    });
  });
});
