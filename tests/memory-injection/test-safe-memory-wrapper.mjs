#!/usr/bin/env node

/**
 * Integration Tests for Safe Memory Wrapper
 * Tests all security features against injection vulnerabilities
 */

import { memory_usage } from 'mcp__claude-flow-alpha';
import {
  sanitizeKey,
  validateNamespace,
  validateValueSize,
  checkRateLimit,
  validateMemoryParams,
  safeMemoryStore,
  safeMemoryRetrieve,
  safeMemoryDelete,
  safeMemorySearch,
  safeMemoryList,
  getRateLimiterStats,
  resetRateLimiter,
  CONFIG
} from '../../src/memory-operations/safe-memory-wrapper.mjs';

export class SafeMemoryWrapperTest {
  constructor(testAgentId = 'safe-wrapper-test') {
    this.testAgentId = testAgentId;
    this.testResults = [];
  }

  /**
   * Test 1: Key Sanitization - Prevents Path Traversal
   */
  async testPathTraversalPrevention() {
    console.log('\n🧪 Testing path traversal prevention...');

    const maliciousKeys = [
      '../../../etc/passwd',
      '../../sensitive-data',
      '~/.ssh/config',
      'swarm/../../etc/hosts',
      '..\\..\\windows\\system32'
    ];

    const results = [];

    for (const key of maliciousKeys) {
      const sanitized = sanitizeKey(key);
      results.push({
        key,
        valid: sanitized.valid,
        error: sanitized.error,
        blocked: !sanitized.valid
      });
    }

    const allBlocked = results.every(r => r.blocked);

    const testResult = {
      test: 'path_traversal_prevention',
      passed: allBlocked,
      results,
      timestamp: Date.now()
    };

    this.testResults.push(testResult);

    if (allBlocked) {
      console.log('✅ All path traversal attempts blocked');
    } else {
      console.error('❌ Some path traversal attempts were NOT blocked');
    }

    return testResult;
  }

  /**
   * Test 2: Namespace Whitelist Enforcement
   */
  async testNamespaceWhitelist() {
    console.log('\n🧪 Testing namespace whitelist enforcement...');

    const testCases = [
      { namespace: 'coordination', shouldPass: true },
      { namespace: 'session', shouldPass: true },
      { namespace: 'cache', shouldPass: true },
      { namespace: 'malicious', shouldPass: false },
      { namespace: '../../etc', shouldPass: false },
      { namespace: 'admin', shouldPass: false }
    ];

    const results = [];

    for (const tc of testCases) {
      const validated = validateNamespace(tc.namespace);
      const passed = validated.valid === tc.shouldPass;
      results.push({
        namespace: tc.namespace,
        expected: tc.shouldPass,
        actual: validated.valid,
        passed,
        error: validated.error
      });
    }

    const allCorrect = results.every(r => r.passed);

    const testResult = {
      test: 'namespace_whitelist',
      passed: allCorrect,
      results,
      timestamp: Date.now()
    };

    this.testResults.push(testResult);

    if (allCorrect) {
      console.log('✅ Namespace whitelist working correctly');
    } else {
      console.error('❌ Namespace whitelist has issues');
    }

    return testResult;
  }

  /**
   * Test 3: Value Size Limits
   */
  async testValueSizeLimits() {
    console.log('\n🧪 Testing value size limits...');

    const testCases = [
      { value: { small: 'data' }, shouldPass: true },
      { value: 'x'.repeat(1024 * 512), shouldPass: true }, // 512KB
      { value: 'x'.repeat(1024 * 1024 * 2), shouldPass: false } // 2MB - exceeds limit
    ];

    const results = [];

    for (const tc of testCases) {
      const validated = validateValueSize(tc.value);
      const passed = validated.valid === tc.shouldPass;
      results.push({
        size: validated.size,
        expected: tc.shouldPass,
        actual: validated.valid,
        passed,
        error: validated.error
      });
    }

    const allCorrect = results.every(r => r.passed);

    const testResult = {
      test: 'value_size_limits',
      passed: allCorrect,
      results,
      timestamp: Date.now()
    };

    this.testResults.push(testResult);

    if (allCorrect) {
      console.log('✅ Value size limits working correctly');
    } else {
      console.error('❌ Value size limits have issues');
    }

    return testResult;
  }

  /**
   * Test 4: Rate Limiting
   */
  async testRateLimiting() {
    console.log('\n🧪 Testing rate limiting...');

    // Reset rate limiter first
    resetRateLimiter('rate-test-agent');

    const results = [];
    let blockedAt = null;

    // Attempt MAX_OPS_PER_MINUTE + 10 operations
    for (let i = 0; i < CONFIG.MAX_OPS_PER_MINUTE + 10; i++) {
      const check = checkRateLimit('rate-test-agent');
      results.push({
        operation: i + 1,
        allowed: check.allowed,
        error: check.error
      });

      if (!check.allowed && blockedAt === null) {
        blockedAt = i + 1;
      }
    }

    const wasBlocked = blockedAt === CONFIG.MAX_OPS_PER_MINUTE + 1;

    const testResult = {
      test: 'rate_limiting',
      passed: wasBlocked,
      blockedAt,
      expectedLimit: CONFIG.MAX_OPS_PER_MINUTE,
      results,
      timestamp: Date.now()
    };

    this.testResults.push(testResult);

    if (wasBlocked) {
      console.log(`✅ Rate limiting blocked at operation ${blockedAt} (expected: ${CONFIG.MAX_OPS_PER_MINUTE + 1})`);
    } else {
      console.error('❌ Rate limiting not working correctly');
    }

    // Cleanup
    resetRateLimiter('rate-test-agent');

    return testResult;
  }

  /**
   * Test 5: Comprehensive Parameter Validation
   */
  async testParameterValidation() {
    console.log('\n🧪 Testing comprehensive parameter validation...');

    const testCases = [
      {
        params: { action: 'store', key: 'test-key', namespace: 'coordination', value: 'test' },
        shouldPass: true
      },
      {
        params: { action: 'invalid', key: 'test', namespace: 'coordination' },
        shouldPass: false
      },
      {
        params: { action: 'store', key: '../../../etc', namespace: 'coordination' },
        shouldPass: false
      },
      {
        params: { action: 'store', key: 'test', namespace: 'malicious' },
        shouldPass: false
      },
      {
        params: { action: 'store', key: 'test', namespace: 'coordination', value: 'x'.repeat(2 * 1024 * 1024) },
        shouldPass: false
      }
    ];

    const results = [];

    for (const tc of testCases) {
      const validated = validateMemoryParams(tc.params);
      const passed = validated.valid === tc.shouldPass;
      results.push({
        params: tc.params,
        expected: tc.shouldPass,
        actual: validated.valid,
        passed,
        errors: validated.errors
      });
    }

    const allCorrect = results.every(r => r.passed);

    const testResult = {
      test: 'parameter_validation',
      passed: allCorrect,
      results,
      timestamp: Date.now()
    };

    this.testResults.push(testResult);

    if (allCorrect) {
      console.log('✅ Parameter validation working correctly');
    } else {
      console.error('❌ Parameter validation has issues');
    }

    return testResult;
  }

  /**
   * Test 6: Safe Memory Operations (End-to-End)
   */
  async testSafeMemoryOperations() {
    console.log('\n🧪 Testing safe memory operations (end-to-end)...');

    const testKey = `swarm/${this.testAgentId}/safe-test`;
    const testNamespace = 'coordination';
    const testValue = {
      agent: this.testAgentId,
      status: 'testing-safe-wrapper',
      timestamp: Date.now(),
      data: { secure: true }
    };

    const results = [];

    try {
      // Test 1: Safe Store
      console.log('   Testing safeMemoryStore...');
      const storeResult = await safeMemoryStore(testKey, testNamespace, testValue, {
        identifier: this.testAgentId
      });
      results.push({
        operation: 'store',
        success: storeResult.success,
        timestamp: storeResult.timestamp
      });
      console.log('   ✅ Store successful');

      // Test 2: Safe Retrieve
      console.log('   Testing safeMemoryRetrieve...');
      const retrieveResult = await safeMemoryRetrieve(testKey, testNamespace, {
        identifier: this.testAgentId
      });
      results.push({
        operation: 'retrieve',
        success: retrieveResult.success,
        found: retrieveResult.found,
        dataMatches: JSON.stringify(retrieveResult.result) === JSON.stringify(testValue),
        timestamp: retrieveResult.timestamp
      });
      console.log('   ✅ Retrieve successful');

      // Test 3: Safe Search
      console.log('   Testing safeMemorySearch...');
      const searchResult = await safeMemorySearch('safe-test', testNamespace, {
        identifier: this.testAgentId,
        limit: 10
      });
      results.push({
        operation: 'search',
        success: searchResult.success,
        count: searchResult.count,
        timestamp: searchResult.timestamp
      });
      console.log('   ✅ Search successful');

      // Test 4: Safe List
      console.log('   Testing safeMemoryList...');
      const listResult = await safeMemoryList(testNamespace, {
        identifier: this.testAgentId
      });
      results.push({
        operation: 'list',
        success: listResult.success,
        count: listResult.count,
        timestamp: listResult.timestamp
      });
      console.log('   ✅ List successful');

      // Test 5: Safe Delete
      console.log('   Testing safeMemoryDelete...');
      const deleteResult = await safeMemoryDelete(testKey, testNamespace, {
        identifier: this.testAgentId
      });
      results.push({
        operation: 'delete',
        success: deleteResult.success,
        deleted: deleteResult.deleted,
        timestamp: deleteResult.timestamp
      });
      console.log('   ✅ Delete successful');

      // Verify deletion
      const verifyResult = await safeMemoryRetrieve(testKey, testNamespace, {
        identifier: this.testAgentId
      });

      const allSuccessful = results.every(r => r.success) && !verifyResult.found;

      const testResult = {
        test: 'safe_memory_operations',
        passed: allSuccessful,
        results,
        verifiedDeletion: !verifyResult.found,
        timestamp: Date.now()
      };

      this.testResults.push(testResult);

      if (allSuccessful) {
        console.log('✅ All safe memory operations successful');
      } else {
        console.error('❌ Some safe memory operations failed');
      }

      return testResult;
    } catch (error) {
      const testResult = {
        test: 'safe_memory_operations',
        passed: false,
        error: error.message,
        timestamp: Date.now()
      };

      this.testResults.push(testResult);
      console.error('❌ Safe memory operations test failed:', error.message);

      return testResult;
    }
  }

  /**
   * Test 7: Injection Attack Prevention
   */
  async testInjectionAttackPrevention() {
    console.log('\n🧪 Testing injection attack prevention...');

    const attackVectors = [
      {
        name: 'Null Byte Injection',
        key: 'test\0hidden',
        expectedBlock: true
      },
      {
        name: 'Path Traversal',
        key: '../../etc/passwd',
        expectedBlock: true
      },
      {
        name: 'Special Characters',
        key: 'test; rm -rf /',
        expectedBlock: true
      },
      {
        name: 'Unicode Homograph',
        key: 'te\u030st', // 't' + combining character
        expectedBlock: true
      },
      {
        name: 'Valid Key',
        key: 'swarm/agent/status',
        expectedBlock: false
      }
    ];

    const results = [];

    for (const vector of attackVectors) {
      const sanitized = sanitizeKey(vector.key);
      const wasBlocked = !sanitized.valid;
      const passed = wasBlocked === vector.expectedBlock;

      results.push({
        attack: vector.name,
        key: vector.key,
        expectedBlock: vector.expectedBlock,
        wasBlocked,
        passed,
        error: sanitized.error
      });
    }

    const allBlocked = results.every(r => r.passed);

    const testResult = {
      test: 'injection_attack_prevention',
      passed: allBlocked,
      results,
      timestamp: Date.now()
    };

    this.testResults.push(testResult);

    if (allBlocked) {
      console.log('✅ All injection attacks prevented');
    } else {
      console.error('❌ Some injection attacks were NOT prevented');
    }

    return testResult;
  }

  /**
   * Generate test summary
   */
  getSummary() {
    const total = this.testResults.length;
    const passed = this.testResults.filter(r => r.passed).length;
    const failed = total - passed;

    return {
      agent: this.testAgentId,
      total,
      passed,
      failed,
      successRate: total > 0 ? ((passed / total) * 100).toFixed(2) + '%' : 'N/A',
      results: this.testResults,
      timestamp: Date.now()
    };
  }

  /**
   * Run all tests
   */
  async runAllTests() {
    console.log(`\n🚀 Starting Safe Memory Wrapper Integration Tests`);
    console.log('='.repeat(70));

    await this.testPathTraversalPrevention();
    await this.testNamespaceWhitelist();
    await this.testValueSizeLimits();
    await this.testRateLimiting();
    await this.testParameterValidation();
    await this.testSafeMemoryOperations();
    await this.testInjectionAttackPrevention();

    const summary = this.getSummary();

    console.log('\n📊 Test Summary:');
    console.log(`   Total Tests: ${summary.total}`);
    console.log(`   Passed: ${summary.passed}`);
    console.log(`   Failed: ${summary.failed}`);
    console.log(`   Success Rate: ${summary.successRate}`);

    return summary;
  }
}

export default SafeMemoryWrapperTest;
