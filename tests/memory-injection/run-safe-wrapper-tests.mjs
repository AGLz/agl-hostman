#!/usr/bin/env node

/**
 * Test Runner for Safe Memory Wrapper
 * Executes tests while using the safe wrapper for coordination
 * This demonstrates the wrapper in action
 */

import { memory_usage } from 'mcp__claude-flow-alpha';
import {
  safeMemoryStore,
  safeMemoryRetrieve,
  safeMemorySearch,
  safeMemoryList,
  safeMemoryDelete
} from '../../src/memory-operations/safe-memory-wrapper.mjs';

import SafeMemoryWrapperTest from './test-safe-memory-wrapper.mjs';

class SafeWrapperTestRunner {
  constructor(testAgentId = 'safe-wrapper-tester') {
    this.testAgentId = testAgentId;
    this.startTime = null;
    this.endTime = null;
  }

  /**
   * Initialize test environment using SAFE memory operations
   */
  async initialize() {
    console.log('\n🚀 Initializing Safe Memory Wrapper Test Suite...');
    console.log('='.repeat(70));

    this.startTime = Date.now();

    // Use SAFE wrapper to store initial status
    await safeMemoryStore(
      `swarm/${this.testAgentId}/status`,
      'coordination',
      {
        agent: this.testAgentId,
        status: 'initializing',
        timestamp: this.startTime,
        tests: [
          'path-traversal-prevention',
          'namespace-whitelist',
          'value-size-limits',
          'rate-limiting',
          'parameter-validation',
          'safe-memory-operations',
          'injection-attack-prevention'
        ]
      },
      { identifier: this.testAgentId }
    );

    console.log('✅ Test environment initialized using SAFE memory operations');
    console.log(`   Start time: ${new Date(this.startTime).toISOString()}`);
  }

  /**
   * Store progress to memory using SAFE operations
   */
  async storeProgress(completed, current, progress) {
    await safeMemoryStore(
      `swarm/${this.testAgentId}/progress`,
      'coordination',
      {
        agent: this.testAgentId,
        completed,
        current,
        progress,
        timestamp: Date.now()
      },
      { identifier: this.testAgentId }
    );
  }

  /**
   * Share results to swarm using SAFE operations
   */
  async shareResults(results) {
    await safeMemoryStore(
      'swarm/shared/safe-memory-wrapper-test-results',
      'coordination',
      {
        type: 'test-results',
        suite: 'safe-memory-wrapper',
        results,
        created_by: this.testAgentId,
        timestamp: Date.now()
      },
      { identifier: this.testAgentId }
    );
  }

  /**
   * Run all tests
   */
  async runAll() {
    try {
      await this.initialize();

      const test = new SafeMemoryWrapperTest(this.testAgentId);

      // Update progress
      await this.storeProgress(
        [],
        'running path traversal prevention tests',
        10
      );

      const test1Result = await test.testPathTraversalPrevention();
      console.log(`   Test 1 Complete: ${test1Result.passed ? 'PASSED' : 'FAILED'}`);

      await this.storeProgress(
        ['path-traversal-prevention'],
        'running namespace whitelist tests',
        25
      );

      const test2Result = await test.testNamespaceWhitelist();
      console.log(`   Test 2 Complete: ${test2Result.passed ? 'PASSED' : 'FAILED'}`);

      await this.storeProgress(
        ['path-traversal-prevention', 'namespace-whitelist'],
        'running value size limits tests',
        40
      );

      const test3Result = await test.testValueSizeLimits();
      console.log(`   Test 3 Complete: ${test3Result.passed ? 'PASSED' : 'FAILED'}`);

      await this.storeProgress(
        ['path-traversal-prevention', 'namespace-whitelist', 'value-size-limits'],
        'running rate limiting tests',
        55
      );

      const test4Result = await test.testRateLimiting();
      console.log(`   Test 4 Complete: ${test4Result.passed ? 'PASSED' : 'FAILED'}`);

      await this.storeProgress(
        ['path-traversal-prevention', 'namespace-whitelist', 'value-size-limits', 'rate-limiting'],
        'running parameter validation tests',
        70
      );

      const test5Result = await test.testParameterValidation();
      console.log(`   Test 5 Complete: ${test5Result.passed ? 'PASSED' : 'FAILED'}`);

      await this.storeProgress(
        ['path-traversal-prevention', 'namespace-whitelist', 'value-size-limits', 'rate-limiting', 'parameter-validation'],
        'running safe memory operations tests',
        85
      );

      const test6Result = await test.testSafeMemoryOperations();
      console.log(`   Test 6 Complete: ${test6Result.passed ? 'PASSED' : 'FAILED'}`);

      await this.storeProgress(
        ['path-traversal-prevention', 'namespace-whitelist', 'value-size-limits', 'rate-limiting', 'parameter-validation', 'safe-memory-operations'],
        'running injection attack prevention tests',
        95
      );

      const test7Result = await test.testInjectionAttackPrevention();
      console.log(`   Test 7 Complete: ${test7Result.passed ? 'PASSED' : 'FAILED'}`);

      // Get summary
      const summary = test.getSummary();

      // Mark completion
      await safeMemoryStore(
        `swarm/${this.testAgentId}/complete`,
        'coordination',
        {
          status: 'complete',
          deliverables: ['safe-memory-wrapper', 'comprehensive-test-suite'],
          summary,
          timestamp: Date.now()
        },
        { identifier: this.testAgentId }
      );

      // Share results with swarm
      await this.shareResults(summary);

      // Print report
      this.printReport(summary);

      return summary;
    } catch (error) {
      console.error('\n❌ Test execution failed:', error);

      // Store error to memory
      await safeMemoryStore(
        `swarm/${this.testAgentId}/error`,
        'coordination',
        {
          agent: this.testAgentId,
          error: error.message,
          stack: error.stack,
          timestamp: Date.now()
        },
        { identifier: this.testAgentId }
      ).catch(e => console.error('Failed to store error:', e));

      throw error;
    }
  }

  /**
   * Print test report
   */
  printReport(summary) {
    this.endTime = Date.now();
    const duration = this.endTime - this.startTime;

    console.log('\n' + '='.repeat(70));
    console.log('📊 SAFE MEMORY WRAPPER TEST REPORT');
    console.log('='.repeat(70));

    console.log('\n📈 Overall Statistics:');
    console.log(`   Agent: ${summary.agent}`);
    console.log(`   Total Tests: ${summary.total}`);
    console.log(`   Passed: ${summary.passed}`);
    console.log(`   Failed: ${summary.failed}`);
    console.log(`   Success Rate: ${summary.successRate}`);
    console.log(`   Duration: ${(duration / 1000).toFixed(2)}s`);

    console.log('\n📋 Individual Test Results:');
    summary.results.forEach(result => {
      const icon = result.passed ? '✅' : '❌';
      console.log(`   ${icon} ${result.test}:`);
      console.log(`      Status: ${result.passed ? 'PASSED' : 'FAILED'}`);

      if (result.results) {
        console.log(`      Checks: ${result.results.length} sub-tests performed`);
      }
      if (result.error) {
        console.log(`      Error: ${result.error}`);
      }
    });

    // Final status
    const allPassed = summary.failed === 0;
    const finalIcon = allPassed ? '✅' : '❌';

    console.log('\n' + '='.repeat(70));
    console.log(`${finalIcon} FINAL RESULT: ${allPassed ? 'ALL TESTS PASSED' : 'SOME TESTS FAILED'}`);
    console.log('='.repeat(70));

    if (allPassed) {
      console.log('\n✅ Security Features Verified:');
      console.log('   ✓ Path traversal prevention');
      console.log('   ✓ Namespace whitelist enforcement');
      console.log('   ✓ Value size limits');
      console.log('   ✓ Rate limiting');
      console.log('   ✓ Comprehensive parameter validation');
      console.log('   ✓ Safe memory operations');
      console.log('   ✓ Injection attack prevention');
      console.log('\n🎯 The safe-memory-wrapper is production-ready!');
    } else {
      console.log('\n⚠️  Some security features need attention.');
      console.log('   Please review the failed tests above.');
    }
  }
}

// CLI interface
async function main() {
  const runner = new SafeWrapperTestRunner();

  try {
    await runner.runAll();
  } catch (error) {
    console.error('Fatal error:', error);
    process.exit(1);
  }
}

// Export for programmatic use
export default SafeWrapperTestRunner;

// Run if called directly
if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch(console.error);
}
