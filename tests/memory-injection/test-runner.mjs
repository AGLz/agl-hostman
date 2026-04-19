#!/usr/bin/env node

/**
 * Memory Injection Test Suite Runner
 * Executes all memory coordination protocol tests
 */

import SingleAgentMemoryTest from './test-single-agent.mjs';
import MultipleAgentMemoryTest from './test-multiple-agents.mjs';
import RaceConditionTest from './test-race-conditions.mjs';
import NamespaceIsolationTest from './test-namespace-isolation.mjs';
import CorruptionDetectionTest from './test-corruption-detection.mjs';
import { memory_usage } from 'mcp__claude-flow-alpha';

class TestRunner {
  constructor() {
    this.results = [];
    this.startTime = null;
    this.endTime = null;
  }

  /**
   * Initialize test environment
   */
  async initialize() {
    console.log('\n🚀 Initializing Memory Injection Test Suite...');
    console.log('='.repeat(70));

    this.startTime = Date.now();

    // Write runner status to memory
    await memory_usage({
      action: 'store',
      key: 'swarm/test-runner/status',
      namespace: 'coordination',
      value: JSON.stringify({
        agent: 'test-runner',
        status: 'initializing',
        timestamp: this.startTime,
        tests: [
          'single-agent',
          'multiple-agents',
          'race-conditions',
          'namespace-isolation',
          'corruption-detection'
        ]
      })
    });

    console.log('✅ Test environment initialized');
    console.log(`   Start time: ${new Date(this.startTime).toISOString()}`);
  }

  /**
   * Run single agent tests
   */
  async runSingleAgentTests() {
    console.log('\n\n' + '='.repeat(70));
    console.log('📦 TEST SUITE 1: Single Agent Operations');
    console.log('='.repeat(70));

    const test = new SingleAgentMemoryTest('agent-single-test');
    const results = await test.runAllTests();

    this.results.push({
      suite: 'single-agent',
      ...results
    });

    return results;
  }

  /**
   * Run multiple agent tests
   */
  async runMultipleAgentTests() {
    console.log('\n\n' + '='.repeat(70));
    console.log('📦 TEST SUITE 2: Multiple Agent Coordination');
    console.log('='.repeat(70));

    const test = new MultipleAgentMemoryTest(5);
    const results = await test.runAllTests();

    this.results.push({
      suite: 'multiple-agents',
      ...results
    });

    return results;
  }

  /**
   * Run race condition tests
   */
  async runRaceConditionTests() {
    console.log('\n\n' + '='.repeat(70));
    console.log('📦 TEST SUITE 3: Race Condition Detection');
    console.log('='.repeat(70));

    const test = new RaceConditionTest();
    const results = await test.runAllTests();

    this.results.push({
      suite: 'race-conditions',
      ...results
    });

    return results;
  }

  /**
   * Run namespace isolation tests
   */
  async runNamespaceIsolationTests() {
    console.log('\n\n' + '='.repeat(70));
    console.log('📦 TEST SUITE 4: Namespace Isolation');
    console.log('='.repeat(70));

    const test = new NamespaceIsolationTest();
    const results = await test.runAllTests();

    this.results.push({
      suite: 'namespace-isolation',
      ...results
    });

    return results;
  }

  /**
   * Run corruption detection tests
   */
  async runCorruptionDetectionTests() {
    console.log('\n\n' + '='.repeat(70));
    console.log('📦 TEST SUITE 5: Corruption Detection');
    console.log('='.repeat(70));

    const test = new CorruptionDetectionTest();
    const results = await test.runAllTests();

    this.results.push({
      suite: 'corruption-detection',
      ...results
    });

    return results;
  }

  /**
   * Generate comprehensive report
   */
  generateReport() {
    this.endTime = Date.now();
    const duration = this.endTime - this.startTime;

    console.log('\n\n' + '='.repeat(70));
    console.log('📊 COMPREHENSIVE TEST REPORT');
    console.log('='.repeat(70));

    // Overall statistics
    const totalTests = this.results.reduce((sum, r) => sum + r.total, 0);
    const totalPassed = this.results.reduce((sum, r) => sum + r.passed, 0);
    const totalFailed = this.results.reduce((sum, r) => sum + r.failed, 0);
    const overallSuccessRate = ((totalPassed / totalTests) * 100).toFixed(2);

    console.log('\n📈 Overall Statistics:');
    console.log(`   Total Test Suites: ${this.results.length}`);
    console.log(`   Total Tests: ${totalTests}`);
    console.log(`   Passed: ${totalPassed}`);
    console.log(`   Failed: ${totalFailed}`);
    console.log(`   Success Rate: ${overallSuccessRate}%`);
    console.log(`   Duration: ${(duration / 1000).toFixed(2)}s`);

    // Per-suite results
    console.log('\n📋 Suite Results:');
    this.results.forEach(result => {
      const icon = result.failed === 0 ? '✅' : '⚠️';
      console.log(`   ${icon} ${result.suite}:`);
      console.log(`      Tests: ${result.total}, Passed: ${result.passed}, Failed: ${result.failed}`);
      console.log(`      Success Rate: ${result.successRate}`);
    });

    // Race conditions detected
    const raceSuite = this.results.find(r => r.suite === 'race-conditions');
    if (raceSuite && raceSuite.raceConditions) {
      console.log('\n⚠️  Race Conditions Detected:');
      console.log(`   Total: ${raceSuite.raceConditions.totalDetected}`);
      if (raceSuite.raceConditions.totalDetected > 0) {
        raceSuite.raceConditions.races.forEach((race, i) => {
          console.log(`   ${i + 1}. ${race.type} (${race.severity})`);
        });
      }
    }

    // Validation report
    const corruptionSuite = this.results.find(r => r.suite === 'corruption-detection');
    if (corruptionSuite && corruptionSuite.validationReport) {
      console.log('\n🔍 Validation Summary:');
      console.log(`   Total Validations: ${corruptionSuite.validationReport.totalValidations}`);
      console.log(`   Success Rate: ${corruptionSuite.validationReport.successRate}`);
    }

    // Performance metrics
    console.log('\n⚡ Performance Metrics:');
    this.results.forEach(result => {
      if (result.avgOpsPerSecond) {
        console.log(`   ${result.suite}: ${result.avgOpsPerSecond} ops/sec`);
      }
    });

    // Final status
    const allPassed = totalFailed === 0;
    const finalIcon = allPassed ? '✅' : '⚠️';

    console.log('\n' + '='.repeat(70));
    console.log(`${finalIcon} FINAL RESULT: ${allPassed ? 'ALL TESTS PASSED' : 'SOME TESTS FAILED'}`);
    console.log('='.repeat(70));

    return {
      overall: {
        totalTests,
        totalPassed,
        totalFailed,
        successRate: overallSuccessRate + '%',
        duration: `${(duration / 1000).toFixed(2)}s`,
        allPassed
      },
      suites: this.results,
      timestamp: new Date().toISOString()
    };
  }

  /**
   * Save results to memory
   */
  async saveResults(report) {
    console.log('\n💾 Saving test results to memory...');

    await memory_usage({
      action: 'store',
      key: 'swarm/test-runner/results',
      namespace: 'coordination',
      value: JSON.stringify({
        agent: 'test-runner',
        status: 'complete',
        report,
        timestamp: Date.now()
      })
    });

    await memory_usage({
      action: 'store',
      key: 'swarm/shared/test-results',
      namespace: 'coordination',
      value: JSON.stringify({
        type: 'test-results',
        suite: 'memory-injection',
        report,
        created_by: 'coder-agent'
      })
    });

    console.log('✅ Results saved to memory');
  }

  /**
   * Run all tests
   */
  async runAll() {
    try {
      await this.initialize();

      await this.runSingleAgentTests();
      await this.runMultipleAgentTests();
      await this.runRaceConditionTests();
      await this.runNamespaceIsolationTests();
      await this.runCorruptionDetectionTests();

      const report = this.generateReport();
      await this.saveResults(report);

      return report;
    } catch (error) {
      console.error('\n❌ Test execution failed:', error);
      throw error;
    }
  }

  /**
   * Run specific test suite
   */
  async runSuite(suiteName) {
    await this.initialize();

    switch (suiteName) {
      case 'single-agent':
        return await this.runSingleAgentTests();
      case 'multiple-agents':
        return await this.runMultipleAgentTests();
      case 'race-conditions':
        return await this.runRaceConditionTests();
      case 'namespace-isolation':
        return await this.runNamespaceIsolationTests();
      case 'corruption-detection':
        return await this.runCorruptionDetectionTests();
      default:
        throw new Error(`Unknown test suite: ${suiteName}`);
    }
  }
}

// CLI interface
async function main() {
  const args = process.argv.slice(2);
  const runner = new TestRunner();

  if (args.length === 0) {
    // Run all tests
    await runner.runAll();
  } else {
    const suite = args[0];
    console.log(`\n🎯 Running test suite: ${suite}`);
    await runner.runSuite(suite);
  }
}

// Export for programmatic use
export default TestRunner;

// Run if called directly
if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch(console.error);
}
