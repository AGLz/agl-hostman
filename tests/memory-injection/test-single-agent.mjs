/**
 * Test Scenario 1: Single Agent Memory Operations
 * Tests basic write/read operations for a single agent
 */

import { memory_usage } from 'mcp__claude-flow-alpha';

export class SingleAgentMemoryTest {
  constructor(agentId = 'test-agent') {
    this.agentId = agentId;
    this.testResults = [];
  }

  /**
   * Test basic memory write operation
   */
  async testWriteOperation() {
    console.log('\n🧪 Testing single agent write operation...');

    const testData = {
      agent: this.agentId,
      status: 'starting',
      timestamp: Date.now(),
      tasks: ['task1', 'task2'],
      progress: 0
    };

    try {
      const result = await memory_usage({
        action: 'store',
        key: `swarm/${this.agentId}/status`,
        namespace: 'coordination',
        value: JSON.stringify(testData)
      });

      const testResult = {
        test: 'write_operation',
        passed: true,
        data: testData,
        timestamp: Date.now()
      };

      this.testResults.push(testResult);
      console.log('✅ Write operation successful');
      return testResult;
    } catch (error) {
      const testResult = {
        test: 'write_operation',
        passed: false,
        error: error.message,
        timestamp: Date.now()
      };
      this.testResults.push(testResult);
      console.error('❌ Write operation failed:', error.message);
      return testResult;
    }
  }

  /**
   * Test basic memory read operation
   */
  async testReadOperation() {
    console.log('\n🧪 Testing single agent read operation...');

    try {
      const result = await memory_usage({
        action: 'retrieve',
        key: `swarm/${this.agentId}/status`,
        namespace: 'coordination'
      });

      const parsedData = JSON.parse(result);

      const testResult = {
        test: 'read_operation',
        passed: true,
        retrievedData: parsedData,
        timestamp: Date.now()
      };

      this.testResults.push(testResult);
      console.log('✅ Read operation successful');
      return testResult;
    } catch (error) {
      const testResult = {
        test: 'read_operation',
        passed: false,
        error: error.message,
        timestamp: Date.now()
      };
      this.testResults.push(testResult);
      console.error('❌ Read operation failed:', error.message);
      return testResult;
    }
  }

  /**
   * Test data persistence across operations
   */
  async testDataPersistence() {
    console.log('\n🧪 Testing data persistence...');

    // Write test data
    const originalData = {
      agent: this.agentId,
      status: 'testing',
      timestamp: Date.now(),
      testField: 'persistence-test-value'
    };

    await memory_usage({
      action: 'store',
      key: `swarm/${this.agentId}/test`,
      namespace: 'coordination',
      value: JSON.stringify(originalData)
    });

    // Read back
    const result = await memory_usage({
      action: 'retrieve',
      key: `swarm/${this.agentId}/test`,
      namespace: 'coordination'
    });

    const retrievedData = JSON.parse(result);
    const dataMatches = JSON.stringify(originalData) === JSON.stringify(retrievedData);

    const testResult = {
      test: 'data_persistence',
      passed: dataMatches,
      originalData,
      retrievedData,
      timestamp: Date.now()
    };

    this.testResults.push(testResult);

    if (dataMatches) {
      console.log('✅ Data persistence verified');
    } else {
      console.error('❌ Data persistence failed - data mismatch');
    }

    return testResult;
  }

  /**
   * Test memory update operation
   */
  async testUpdateOperation() {
    console.log('\n🧪 Testing memory update operation...');

    // Write initial data
    const initialData = {
      agent: this.agentId,
      status: 'initial',
      progress: 0
    };

    await memory_usage({
      action: 'store',
      key: `swarm/${this.agentId}/update-test`,
      namespace: 'coordination',
      value: JSON.stringify(initialData)
    });

    // Update with new data
    const updatedData = {
      agent: this.agentId,
      status: 'updated',
      progress: 50
    };

    await memory_usage({
      action: 'store',
      key: `swarm/${this.agentId}/update-test`,
      namespace: 'coordination',
      value: JSON.stringify(updatedData)
    });

    // Verify update
    const result = await memory_usage({
      action: 'retrieve',
      key: `swarm/${this.agentId}/update-test`,
      namespace: 'coordination'
    });

    const retrievedData = JSON.parse(result);
    const wasUpdated = retrievedData.status === 'updated' && retrievedData.progress === 50;

    const testResult = {
      test: 'update_operation',
      passed: wasUpdated,
      initialData,
      updatedData,
      retrievedData,
      timestamp: Date.now()
    };

    this.testResults.push(testResult);

    if (wasUpdated) {
      console.log('✅ Update operation successful');
    } else {
      console.error('❌ Update operation failed');
    }

    return testResult;
  }

  /**
   * Test memory delete operation
   */
  async testDeleteOperation() {
    console.log('\n🧪 Testing memory delete operation...');

    // Write test data
    const testData = { test: 'delete-me', timestamp: Date.now() };

    await memory_usage({
      action: 'store',
      key: `swarm/${this.agentId}/delete-test`,
      namespace: 'coordination',
      value: JSON.stringify(testData)
    });

    // Delete
    try {
      await memory_usage({
        action: 'delete',
        key: `swarm/${this.agentId}/delete-test`,
        namespace: 'coordination'
      });

      // Verify deletion
      const result = await memory_usage({
        action: 'retrieve',
        key: `swarm/${this.agentId}/delete-test`,
        namespace: 'coordination'
      });

      const wasDeleted = !result || result === null;

      const testResult = {
        test: 'delete_operation',
        passed: wasDeleted,
        timestamp: Date.now()
      };

      this.testResults.push(testResult);

      if (wasDeleted) {
        console.log('✅ Delete operation successful');
      } else {
        console.error('❌ Delete operation failed - data still exists');
      }

      return testResult;
    } catch (error) {
      const testResult = {
        test: 'delete_operation',
        passed: false,
        error: error.message,
        timestamp: Date.now()
      };
      this.testResults.push(testResult);
      console.error('❌ Delete operation failed:', error.message);
      return testResult;
    }
  }

  /**
   * Run all single agent tests
   */
  async runAllTests() {
    console.log(`\n🚀 Starting Single Agent Memory Tests for ${this.agentId}`);
    console.log('='.repeat(60));

    await this.testWriteOperation();
    await this.testReadOperation();
    await this.testDataPersistence();
    await this.testUpdateOperation();
    await this.testDeleteOperation();

    const summary = this.getSummary();
    console.log('\n📊 Test Summary:');
    console.log(`Total Tests: ${summary.total}`);
    console.log(`Passed: ${summary.passed}`);
    console.log(`Failed: ${summary.failed}`);
    console.log(`Success Rate: ${summary.successRate}`);

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
      agent: this.agentId,
      total,
      passed,
      failed,
      successRate: total > 0 ? ((passed / total) * 100).toFixed(2) + '%' : 'N/A',
      results: this.testResults,
      timestamp: Date.now()
    };
  }
}

export default SingleAgentMemoryTest;
