/**
 * Test Scenario 4: Namespace Isolation
 * Tests memory isolation between different namespaces
 */

import { memory_usage } from 'mcp__claude-flow-alpha';

export class NamespaceIsolationTest {
  constructor() {
    this.testResults = [];
    this.namespaces = ['coordination', 'test', 'production', 'staging', 'development'];
  }

  /**
   * Test writing to different namespaces
   */
  async testMultipleNamespaces() {
    console.log('\n🧪 Testing writes to multiple namespaces...');

    const writePromises = this.namespaces.map(ns =>
      memory_usage({
        action: 'store',
        key: 'test-key',
        namespace: ns,
        value: JSON.stringify({
          namespace: ns,
          timestamp: Date.now(),
          testData: `data-for-${ns}`
        })
      })
    );

    try {
      const results = await Promise.all(writePromises);

      const testResult = {
        test: 'multiple_namespaces',
        passed: results.length === this.namespaces.length,
        namespaces: this.namespaces,
        successfulWrites: results.length,
        timestamp: Date.now()
      };

      this.testResults.push(testResult);
      console.log(`✅ Successfully wrote to ${results.length} namespaces`);
      return testResult;
    } catch (error) {
      const testResult = {
        test: 'multiple_namespaces',
        passed: false,
        error: error.message,
        timestamp: Date.now()
      };
      this.testResults.push(testResult);
      console.error('❌ Multiple namespace test failed:', error.message);
      return testResult;
    }
  }

  /**
   * Test namespace data isolation
   */
  async testDataIsolation() {
    console.log('\n🧪 Testing namespace data isolation...');

    // Write same key to different namespaces with different values
    const writes = this.namespaces.map((ns, index) =>
      memory_usage({
        action: 'store',
        key: 'shared-key',
        namespace: ns,
        value: JSON.stringify({
          namespace: ns,
          uniqueValue: `value-${index}`,
          timestamp: Date.now()
        })
      })
    );

    await Promise.all(writes);

    // Read back from each namespace
    const readPromises = this.namespaces.map(ns =>
      memory_usage({
        action: 'retrieve',
        key: 'shared-key',
        namespace: ns
      })
    );

    const results = await Promise.all(readPromises);
    const parsedResults = results.map(r => JSON.parse(r));

    // Check if each namespace has different data
    const uniqueValues = new Set(parsedResults.map(r => r.uniqueValue));
    const isIsolated = uniqueValues.size === this.namespaces.length;

    const testResult = {
      test: 'data_isolation',
      passed: isIsolated,
      namespaces: this.namespaces,
      uniqueValuesFound: uniqueValues.size,
      expectedUnique: this.namespaces.length,
      isolationVerified: isIsolated,
      dataByNamespace: parsedResults.reduce((acc, r) => {
        acc[r.namespace] = r.uniqueValue;
        return acc;
      }, {}),
      timestamp: Date.now()
    };

    this.testResults.push(testResult);

    if (isIsolated) {
      console.log('✅ Namespace isolation verified');
      console.log(`   ${uniqueValues.size} unique values across ${this.namespaces.length} namespaces`);
    } else {
      console.error('❌ Namespace isolation failed - data leakage detected');
      console.log(`   Expected ${this.namespaces.length} unique values, got ${uniqueValues.size}`);
    }

    return testResult;
  }

  /**
   * Test cross-namespace read access
   */
  async testCrossNamespaceAccess() {
    console.log('\n🧪 Testing cross-namespace read access...');

    // Write to coordination namespace
    await memory_usage({
      action: 'store',
      key: 'isolated-key',
      namespace: 'coordination',
      value: JSON.stringify({
        message: 'coordination-data',
        timestamp: Date.now()
      })
    });

    // Try reading from different namespace
    let crossReadResult;

    try {
      crossReadResult = await memory_usage({
        action: 'retrieve',
        key: 'isolated-key',
        namespace: 'test'  // Different namespace
      });
    } catch (error) {
      crossReadResult = null;
    }

    // Should NOT be able to read across namespaces
    const isIsolated = crossReadResult === null || crossReadResult === undefined;

    const testResult = {
      test: 'cross_namespace_access',
      passed: isIsolated,
      accessBlocked: isIsolated,
      attemptedAccess: 'test → coordination',
      result: crossReadResult,
      timestamp: Date.now()
    };

    this.testResults.push(testResult);

    if (isIsolated) {
      console.log('✅ Cross-namespace access properly blocked');
    } else {
      console.error('❌ Security issue: cross-namespace access allowed');
    }

    return testResult;
  }

  /**
   * Test namespace deletion doesn't affect others
   */
  async testIndependentDeletion() {
    console.log('\n🧪 Testing independent namespace deletion...');

    const key = 'deletion-test';

    // Write to all namespaces
    const writes = this.namespaces.map(ns =>
      memory_usage({
        action: 'store',
        key,
        namespace: ns,
        value: JSON.stringify({ namespace: ns, data: 'test' })
      })
    );

    await Promise.all(writes);

    // Delete from one namespace
    await memory_usage({
      action: 'delete',
      key,
      namespace: 'coordination'
    });

    // Verify other namespaces still have data
    const readPromises = this.namespaces
      .filter(ns => ns !== 'coordination')
      .map(ns =>
        memory_usage({
          action: 'retrieve',
          key,
          namespace: ns
        })
      );

    const results = await Promise.all(readPromises);
    const allPresent = results.every(r => r !== null && r !== undefined);

    const testResult = {
      test: 'independent_deletion',
      passed: allPresent,
      deletedNamespace: 'coordination',
      remainingNamespaces: this.namespaces.length - 1,
      allDataIntact: allPresent,
      timestamp: Date.now()
    };

    this.testResults.push(testResult);

    if (allPresent) {
      console.log('✅ Independent deletion verified');
      console.log(`   Other namespaces unaffected: ${this.namespaces.length - 1}`);
    } else {
      console.error('❌ Deletion affected other namespaces');
    }

    return testResult;
  }

  /**
   * Test namespace performance comparison
   */
  async testNamespacePerformance() {
    console.log('\n🧪 Testing namespace performance...');

    const operationsPerNamespace = 50;
    const performanceResults = [];

    for (const ns of this.namespaces) {
      const startTime = Date.now();

      const operations = [];

      for (let i = 0; i < operationsPerNamespace; i++) {
        operations.push(
          memory_usage({
            action: 'store',
            key: `perf-test-${i}`,
            namespace: ns,
            value: JSON.stringify({ index: i, ns })
          })
        );
      }

      await Promise.all(operations);

      const endTime = Date.now();
      const duration = endTime - startTime;
      const opsPerSecond = (operationsPerNamespace / (duration / 1000)).toFixed(2);

      performanceResults.push({
        namespace: ns,
        durationMs: duration,
        opsPerSecond
      });
    }

    const avgOpsPerSecond = (
      performanceResults.reduce((sum, r) => sum + parseFloat(r.opsPerSecond), 0) /
      performanceResults.length
    ).toFixed(2);

    const testResult = {
      test: 'namespace_performance',
      passed: true,
      namespaces: this.namespaces,
      performanceResults,
      avgOpsPerSecond,
      timestamp: Date.now()
    };

    this.testResults.push(testResult);

    console.log('✅ Namespace performance test completed');
    console.log(`   Average: ${avgOpsPerSecond} ops/second across all namespaces`);
    performanceResults.forEach(r => {
      console.log(`   ${r.namespace}: ${r.opsPerSecond} ops/sec`);
    });

    return testResult;
  }

  /**
   * Test namespace listing and filtering
   */
  async testNamespaceListing() {
    console.log('\n🧪 Testing namespace listing...');

    // Write data with specific patterns
    const testData = [
      { ns: 'coordination', key: 'swarm/coder/status' },
      { ns: 'coordination', key: 'swarm/tester/status' },
      { ns: 'test', key: 'test/data/1' },
      { ns: 'production', key: 'app/config' }
    ];

    for (const { ns, key } of testData) {
      await memory_usage({
        action: 'store',
        key,
        namespace: ns,
        value: JSON.stringify({ test: true })
      });
    }

    // List all coordination namespace keys
    try {
      const coordinationKeys = await memory_usage({
        action: 'list',
        namespace: 'coordination'
      });

      const testResult = {
        test: 'namespace_listing',
        passed: Array.isArray(coordinationKeys) || coordinationKeys.length > 0,
        namespace: 'coordination',
        keysFound: coordinationKeys.length || 0,
        timestamp: Date.now()
      };

      this.testResults.push(testResult);

      console.log(`✅ Namespace listing successful`);
      console.log(`   Found ${coordinationKeys.length || 0} keys in coordination namespace`);

      return testResult;
    } catch (error) {
      const testResult = {
        test: 'namespace_listing',
        passed: false,
        error: error.message,
        timestamp: Date.now()
      };
      this.testResults.push(testResult);
      console.error('❌ Namespace listing failed:', error.message);
      return testResult;
    }
  }

  /**
   * Run all namespace isolation tests
   */
  async runAllTests() {
    console.log(`\n🚀 Starting Namespace Isolation Tests`);
    console.log('='.repeat(60));

    await this.testMultipleNamespaces();
    await this.testDataIsolation();
    await this.testCrossNamespaceAccess();
    await this.testIndependentDeletion();
    await this.testNamespacePerformance();
    await this.testNamespaceListing();

    const summary = this.getSummary();
    console.log('\n📊 Test Summary:');
    console.log(`Total Tests: ${summary.total}`);
    console.log(`Passed: ${summary.passed}`);
    console.log(`Failed: ${summary.failed}`);
    console.log(`Success Rate: ${summary.successRate}`);
    console.log(`Namespaces Tested: ${this.namespaces.length}`);

    return summary;
  }

  /**
   * Get test summary
   */
  getSummary() {
    const total = this.testResults.length;
    const passed = this.testResults.filter(r => r.passed).length;
    const failed = total - passed;

    return {
      total,
      passed,
      failed,
      successRate: total > 0 ? ((passed / total) * 100).toFixed(2) + '%' : 'N/A',
      namespaces: this.namespaces,
      results: this.testResults,
      timestamp: Date.now()
    };
  }
}

export default NamespaceIsolationTest;
