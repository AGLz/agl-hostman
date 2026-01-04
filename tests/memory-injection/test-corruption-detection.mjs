/**
 * Test Scenario 5: Memory Corruption Detection
 * Tests data integrity and corruption detection mechanisms
 */

import { memory_usage } from 'mcp__claude-flow-alpha';
import { MemoryValidator } from './validation-utils.js';

export class CorruptionDetectionTest {
  constructor() {
    this.testResults = [];
    this.validator = new MemoryValidator();
  }

  /**
   * Test data integrity validation
   */
  async testDataIntegrity() {
    console.log('\n🧪 Testing data integrity validation...');

    const testData = {
      agent: 'test-agent',
      status: 'active',
      timestamp: Date.now(),
      metadata: {
        version: '1.0.0',
        environment: 'test'
      }
    };

    // Calculate checksum before storage
    const originalData = JSON.stringify(testData);
    const originalChecksum = this.validator.calculateChecksum(originalData);

    // Store in memory
    await memory_usage({
      action: 'store',
      key: 'swarm/test/integrity-test',
      namespace: 'coordination',
      value: originalData
    });

    // Retrieve and verify
    const retrieved = await memory_usage({
      action: 'retrieve',
      key: 'swarm/test/integrity-test',
      namespace: 'coordination'
    });

    const validationResult = this.validator.detectCorruption(
      JSON.parse(retrieved),
      originalChecksum
    );

    const testResult = {
      test: 'data_integrity',
      passed: !validationResult.isCorrupted,
      originalChecksum,
      retrievedChecksum: validationResult.checksum,
      integrityVerified: !validationResult.isCorrupted,
      timestamp: Date.now()
    };

    this.testResults.push(testResult);

    if (!validationResult.isCorrupted) {
      console.log('✅ Data integrity verified');
      console.log(`   Checksum: ${validationResult.checksum}`);
    } else {
      console.error('❌ Data corruption detected!');
    }

    return testResult;
  }

  /**
   * Test corrupted data detection
   */
  async testCorruptionDetection() {
    console.log('\n🧪 Testing corruption detection...');

    const originalData = {
      message: 'original data',
      value: 100,
      timestamp: Date.now()
    };

    // Store original
    await memory_usage({
      action: 'store',
      key: 'swarm/test/corruption-test',
      namespace: 'coordination',
      value: JSON.stringify(originalData)
    });

    // Retrieve and corrupt
    const retrieved = await memory_usage({
      action: 'retrieve',
      key: 'swarm/test/corruption-test',
      namespace: 'coordination'
    });

    const data = JSON.parse(retrieved);

    // Simulate corruption by modifying data
    const corruptedData = { ...data, value: 999, corrupted: true };
    const originalChecksum = this.validator.calculateChecksum(JSON.stringify(originalData));

    // Detect corruption
    const detectionResult = this.validator.detectCorruption(
      corruptedData,
      originalChecksum
    );

    const testResult = {
      test: 'corruption_detection',
      passed: detectionResult.isCorrupted,
      originalChecksum,
      corruptedChecksum: detectionResult.checksum,
      corruptionDetected: detectionResult.isCorrupted,
      timestamp: Date.now()
    };

    this.testResults.push(testResult);

    if (detectionResult.isCorrupted) {
      console.log('✅ Corruption successfully detected');
      console.log(`   Original checksum: ${originalChecksum}`);
      console.log(`   Corrupted checksum: ${detectionResult.checksum}`);
    } else {
      console.error('❌ Failed to detect corruption');
    }

    return testResult;
  }

  /**
   * Test memory structure validation
   */
  async testStructureValidation() {
    console.log('\n🧪 Testing memory structure validation...');

    const testCases = [
      {
        name: 'valid_structure',
        data: {
          action: 'store',
          key: 'swarm/test/valid',
          namespace: 'coordination',
          value: JSON.stringify({ test: true })
        },
        shouldPass: true
      },
      {
        name: 'missing_action',
        data: {
          key: 'swarm/test/invalid',
          namespace: 'coordination',
          value: 'test'
        },
        shouldPass: false
      },
      {
        name: 'invalid_namespace',
        data: {
          action: 'store',
          key: 'test-key',
          namespace: 'invalid',
          value: 'test'
        },
        shouldPass: false
      },
      {
        name: 'invalid_key_pattern',
        data: {
          action: 'store',
          key: 'invalid-key',
          namespace: 'coordination',
          value: 'test'
        },
        shouldPass: false
      },
      {
        name: 'missing_value',
        data: {
          action: 'store',
          key: 'swarm/test/missing-value',
          namespace: 'coordination'
        },
        shouldPass: false
      }
    ];

    const validationResults = [];

    for (const testCase of testCases) {
      const result = this.validator.validateMemoryStructure(testCase.data);
      const passed = result.valid === testCase.shouldPass;

      validationResults.push({
        testCase: testCase.name,
        passed,
        expected: testCase.shouldPass,
        actual: result.valid,
        errors: result.errors
      });
    }

    const allPassed = validationResults.every(r => r.passed);

    const testResult = {
      test: 'structure_validation',
      passed: allPassed,
      testCases: validationResults,
      validationRate: (validationResults.filter(r => r.passed).length / validationResults.length * 100).toFixed(2) + '%',
      timestamp: Date.now()
    };

    this.testResults.push(testResult);

    if (allPassed) {
      console.log('✅ Structure validation working correctly');
      console.log(`   Passed ${validationResults.length}/${validationResults.length} test cases`);
    } else {
      console.error('❌ Structure validation issues detected');
      validationResults.forEach(r => {
        if (!r.passed) {
          console.log(`   ${r.testCase}: expected=${r.expected}, actual=${r.actual}`);
        }
      });
    }

    return testResult;
  }

  /**
   * Test agent status validation
   */
  async testAgentStatusValidation() {
    console.log('\n🧪 Testing agent status validation...');

    const statusCases = [
      {
        name: 'valid_status',
        data: {
          agent: 'test-agent',
          status: 'starting',
          timestamp: Date.now(),
          tasks: ['task1'],
          progress: 0
        },
        shouldPass: true
      },
      {
        name: 'missing_agent',
        data: {
          status: 'active',
          timestamp: Date.now()
        },
        shouldPass: false
      },
      {
        name: 'invalid_status',
        data: {
          agent: 'test-agent',
          status: 'invalid-status',
          timestamp: Date.now()
        },
        shouldPass: false
      },
      {
        name: 'missing_timestamp',
        data: {
          agent: 'test-agent',
          status: 'active'
        },
        shouldPass: false
      }
    ];

    const validationResults = [];

    for (const testCase of statusCases) {
      const result = this.validator.validateAgentStatus(testCase.data);
      const passed = result.valid === testCase.shouldPass;

      validationResults.push({
        testCase: testCase.name,
        passed,
        expected: testCase.shouldPass,
        actual: result.valid,
        errors: result.errors
      });
    }

    const allPassed = validationResults.every(r => r.passed);

    const testResult = {
      test: 'agent_status_validation',
      passed: allPassed,
      testCases: validationResults,
      validationRate: (validationResults.filter(r => r.passed).length / validationResults.length * 100).toFixed(2) + '%',
      timestamp: Date.now()
    };

    this.testResults.push(testResult);

    if (allPassed) {
      console.log('✅ Agent status validation working correctly');
    } else {
      console.error('❌ Agent status validation issues detected');
    }

    return testResult;
  }

  /**
   * Test concurrent write corruption
   */
  async testConcurrentWriteCorruption() {
    console.log('\n🧪 Testing concurrent write corruption...');

    const key = 'swarm/test/concurrent-corruption';
    const numWriters = 20;

    // Write initial data
    const initialData = {
      value: 'initial',
      checksum: this.validator.calculateChecksum('initial'),
      timestamp: Date.now()
    };

    await memory_usage({
      action: 'store',
      key,
      namespace: 'coordination',
      value: JSON.stringify(initialData)
    });

    // Concurrent writes
    const writePromises = [];

    for (let i = 0; i < numWriters; i++) {
      writePromises.push(
        (async (writerId) => {
          const data = {
            writerId,
            value: `data-${writerId}`,
            checksum: this.validator.calculateChecksum(`data-${writerId}`),
            timestamp: Date.now()
          };

          await memory_usage({
            action: 'store',
            key,
            namespace: 'coordination',
            value: JSON.stringify(data)
          });

          return data;
        })(i)
      );
    }

    await Promise.all(writePromises);

    // Verify final state
    const final = await memory_usage({
      action: 'retrieve',
      key,
      namespace: 'coordination'
    });

    const finalData = JSON.parse(final);

    // Check if data is consistent
    const dataConsistent = finalData.checksum === this.validator.calculateChecksum(finalData.value);

    const testResult = {
      test: 'concurrent_write_corruption',
      passed: dataConsistent,
      numWriters,
      finalWriter: finalData.writerId,
      dataConsistent,
      checksumValid: dataConsistent,
      timestamp: Date.now()
    };

    this.testResults.push(testResult);

    if (dataConsistent) {
      console.log('✅ No corruption detected after concurrent writes');
      console.log(`   Final writer: ${finalData.writerId}`);
    } else {
      console.error('❌ Data corruption detected after concurrent writes');
    }

    return testResult;
  }

  /**
   * Test recovery from corruption
   */
  async testCorruptionRecovery() {
    console.log('\n🧪 Testing corruption recovery...');

    const key = 'swarm/test/recovery-test';

    // Store valid data
    const validData = {
      version: 1,
      data: 'valid-data',
      checksum: this.validator.calculateChecksum('valid-data'),
      timestamp: Date.now()
    };

    await memory_usage({
      action: 'store',
      key,
      namespace: 'coordination',
      value: JSON.stringify(validData)
    });

    // Simulate corruption
    const corruptedData = { ...validData, data: 'corrupted', version: 999 };

    // Validate
    const isCorrupted = this.validator.detectCorruption(
      corruptedData,
      validData.checksum
    ).isCorrupted;

    if (isCorrupted) {
      // Recovery: restore original data
      await memory_usage({
        action: 'store',
        key,
        namespace: 'coordination',
        value: JSON.stringify(validData)
      });

      // Verify recovery
      const recovered = await memory_usage({
        action: 'retrieve',
        key,
        namespace: 'coordination'
      });

      const recoveredData = JSON.parse(recovered);
      const recoveredSuccessfully = recoveredData.data === validData.data;

      const testResult = {
        test: 'corruption_recovery',
        passed: recoveredSuccessfully,
        corruptionDetected: isCorrupted,
        recoverySuccessful: recoveredSuccessfully,
        timestamp: Date.now()
      };

      this.testResults.push(testResult);

      if (recoveredSuccessfully) {
        console.log('✅ Corruption recovery successful');
      } else {
        console.error('❌ Corruption recovery failed');
      }

      return testResult;
    }

    const testResult = {
      test: 'corruption_recovery',
      passed: false,
      error: 'Corruption not detected',
      timestamp: Date.now()
    };

    this.testResults.push(testResult);
    console.error('❌ Failed to detect corruption for recovery');

    return testResult;
  }

  /**
   * Run all corruption detection tests
   */
  async runAllTests() {
    console.log(`\n🚀 Starting Corruption Detection Tests`);
    console.log('='.repeat(60));

    await this.testDataIntegrity();
    await this.testCorruptionDetection();
    await this.testStructureValidation();
    await this.testAgentStatusValidation();
    await this.testConcurrentWriteCorruption();
    await this.testCorruptionRecovery();

    const summary = this.getSummary();
    const validationReport = this.validator.getValidationReport();

    console.log('\n📊 Test Summary:');
    console.log(`Total Tests: ${summary.total}`);
    console.log(`Passed: ${summary.passed}`);
    console.log(`Failed: ${summary.failed}`);
    console.log(`Success Rate: ${summary.successRate}`);

    console.log('\n📋 Validation Report:');
    console.log(`Total Validations: ${validationReport.totalValidations}`);
    console.log(`Failed Validations: ${validationReport.failedValidations}`);
    console.log(`Success Rate: ${validationReport.successRate}`);

    return { ...summary, validationReport };
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
      results: this.testResults,
      timestamp: Date.now()
    };
  }
}

export default CorruptionDetectionTest;
