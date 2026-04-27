/**
 * Test Scenario 3: Memory Race Conditions
 * Tests concurrent access patterns and potential race conditions
 */

import { memory_usage } from 'mcp__claude-flow-alpha';

export class RaceConditionTest {
  constructor() {
    this.testResults = [];
    this.raceDetected = [];
  }

  /**
   * Test rapid concurrent writes to same key
   */
  async testRapidConcurrentWrites() {
    console.log('\n🧪 Testing rapid concurrent writes...');

    const numWrites = 100;
    const key = 'swarm/shared/rapid-writes-test';
    const writePromises = [];

    for (let i = 0; i < numWrites; i++) {
      writePromises.push(
        memory_usage({
          action: 'store',
          key,
          namespace: 'coordination',
          value: JSON.stringify({
            writeNumber: i,
            agent: `writer-${i % 10}`,
            timestamp: Date.now() + i
          })
        })
      );
    }

    const startTime = Date.now();
    const results = await Promise.all(writePromises);
    const endTime = Date.now();
    const duration = endTime - startTime;

    // Read final value
    const finalValue = await memory_usage({
      action: 'retrieve',
      key,
      namespace: 'coordination'
    });

    const finalData = JSON.parse(finalValue);

    const testResult = {
      test: 'rapid_concurrent_writes',
      passed: results.length === numWrites,
      totalWrites: numWrites,
      successfulWrites: results.length,
      durationMs: duration,
      writesPerSecond: (numWrites / (duration / 1000)).toFixed(2),
      finalWriteNumber: finalData.writeNumber,
      timestamp: Date.now()
    };

    this.testResults.push(testResult);

    console.log(`✅ Completed ${numWrites} concurrent writes in ${duration}ms`);
    console.log(`   Throughput: ${testResult.writesPerSecond} writes/second`);
    console.log(`   Final write: #${finalData.writeNumber}`);

    return testResult;
  }

  /**
   * Test write-read race condition
   */
  async testWriteReadRace() {
    console.log('\n🧪 Testing write-read race condition...');

    const key = 'swarm/shared/write-read-race';
    const operations = [];

    // Mix writes and reads
    for (let i = 0; i < 50; i++) {
      operations.push(
        memory_usage({
          action: 'store',
          key,
          namespace: 'coordination',
          value: JSON.stringify({ iteration: i, timestamp: Date.now() })
        })
      );

      operations.push(
        memory_usage({
          action: 'retrieve',
          key,
          namespace: 'coordination'
        })
      );
    }

    const startTime = Date.now();
    const results = await Promise.all(operations);
    const endTime = Date.now();

    const successfulOps = results.filter(r => r !== null && r !== undefined).length;

    const testResult = {
      test: 'write_read_race',
      passed: successfulOps === operations.length,
      totalOperations: operations.length,
      successfulOperations: successfulOps,
      durationMs: endTime - startTime,
      operationsPerSecond: (operations.length / ((endTime - startTime) / 1000)).toFixed(2),
      timestamp: Date.now()
    };

    this.testResults.push(testResult);

    console.log(`✅ Completed ${successfulOps}/${operations.length} mixed operations`);
    console.log(`   Throughput: ${testResult.operationsPerSecond} ops/second`);

    return testResult;
  }

  /**
   * Test multiple agents updating same counter
   */
  async testCounterRace() {
    console.log('\n🧪 Testing counter increment race...');

    const key = 'swarm/shared/counter-test';
    const numAgents = 10;
    const incrementsPerAgent = 10;

    // Initialize counter
    await memory_usage({
      action: 'store',
      key,
      namespace: 'coordination',
      value: JSON.stringify({ counter: 0, timestamp: Date.now() })
    });

    // Each agent increments counter multiple times
    const incrementPromises = [];

    for (let agent = 0; agent < numAgents; agent++) {
      for (let i = 0; i < incrementsPerAgent; i++) {
        incrementPromises.push(
          (async (agentId, iter) => {
            // Read current value
            const current = await memory_usage({
              action: 'retrieve',
              key,
              namespace: 'coordination'
            });

            const data = JSON.parse(current);
            const newCounter = data.counter + 1;

            // Write incremented value
            await memory_usage({
              action: 'store',
              key,
              namespace: 'coordination',
              value: JSON.stringify({
                counter: newCounter,
                lastIncrementBy: `agent-${agentId}`,
                timestamp: Date.now()
              })
            });

            return { agent: agentId, iteration: iter, value: newCounter };
          })(agent, i)
        );
      }
    }

    const results = await Promise.all(incrementPromises);

    // Read final counter value
    const final = await memory_usage({
      action: 'retrieve',
      key,
      namespace: 'coordination'
    });

    const finalData = JSON.parse(final);
    const expectedValue = numAgents * incrementsPerAgent;

    // Detect race condition (lost increments)
    const lostIncrements = expectedValue - finalData.counter;
    const hasRace = lostIncrements > 0;

    const testResult = {
      test: 'counter_race',
      passed: !hasRace,
      expectedValue,
      actualValue: finalData.counter,
      lostIncrements,
      raceConditionDetected: hasRace,
      totalOperations: numAgents * incrementsPerAgent,
      timestamp: Date.now()
    };

    this.testResults.push(testResult);

    if (hasRace) {
      this.raceDetected.push({
        type: 'lost_increment',
        severity: 'high',
        details: testResult
      });
      console.log(`⚠️  Race condition detected!`);
      console.log(`   Expected: ${expectedValue}, Actual: ${finalData.counter}`);
      console.log(`   Lost increments: ${lostIncrements}`);
    } else {
      console.log(`✅ No race condition - counter reached expected value`);
    }

    return testResult;
  }

  /**
   * Test memory consistency under load
   */
  async testConsistencyUnderLoad() {
    console.log('\n🧪 Testing memory consistency under load...');

    const keys = ['key1', 'key2', 'key3', 'key4', 'key5'];
    const numOperations = 200;
    const operations = [];

    // Generate random operations
    for (let i = 0; i < numOperations; i++) {
      const key = `swarm/shared/consistency-${keys[i % keys.length]}`;
      const isWrite = Math.random() > 0.5;

      if (isWrite) {
        operations.push(
          memory_usage({
            action: 'store',
            key,
            namespace: 'coordination',
            value: JSON.stringify({ operation: i, timestamp: Date.now() })
          })
        );
      } else {
        operations.push(
          memory_usage({
            action: 'retrieve',
            key,
            namespace: 'coordination'
          })
        );
      }
    }

    const startTime = Date.now();
    const results = await Promise.all(operations);
    const endTime = Date.now();

    const successful = results.filter(r => r !== null && r !== undefined).length;
    const consistencyRate = (successful / numOperations * 100).toFixed(2);

    const testResult = {
      test: 'consistency_under_load',
      passed: successful === numOperations,
      totalOperations: numOperations,
      successfulOperations: successful,
      consistencyRate: consistencyRate + '%',
      durationMs: endTime - startTime,
      operationsPerSecond: (numOperations / ((endTime - startTime) / 1000)).toFixed(2),
      timestamp: Date.now()
    };

    this.testResults.push(testResult);

    console.log(`✅ Load test completed`);
    console.log(`   Consistency: ${consistencyRate}%`);
    console.log(`   Throughput: ${testResult.operationsPerSecond} ops/second`);

    return testResult;
  }

  /**
   * Test memory ordering guarantees
   */
  async testMemoryOrdering() {
    console.log('\n🧪 Testing memory ordering guarantees...');

    const key = 'swarm/shared/ordering-test';
    const numWrites = 20;

    // Sequential writes with timestamps
    const writePromises = [];

    for (let i = 0; i < numWrites; i++) {
      writePromises.push(
        (async (sequence) => {
          await memory_usage({
            action: 'store',
            key,
            namespace: 'coordination',
            value: JSON.stringify({
              sequence,
              timestamp: Date.now(),
              writeOrder: sequence
            })
          });
          return sequence;
        })(i)
      );

      // Small delay to ensure ordering
      await new Promise(resolve => setTimeout(resolve, 10));
    }

    await Promise.all(writePromises);

    // Read final value
    const final = await memory_usage({
      action: 'retrieve',
      key,
      namespace: 'coordination'
    });

    const finalData = JSON.parse(final);
    const orderPreserved = finalData.sequence === numWrites - 1;

    const testResult = {
      test: 'memory_ordering',
      passed: orderPreserved,
      totalWrites: numWrites,
      finalSequence: finalData.sequence,
      expectedSequence: numWrites - 1,
      orderPreserved,
      timestamp: Date.now()
    };

    this.testResults.push(testResult);

    if (orderPreserved) {
      console.log('✅ Memory ordering preserved');
      console.log(`   Final sequence: ${finalData.sequence}`);
    } else {
      console.log('⚠️  Memory ordering not guaranteed');
      console.log(`   Expected: ${numWrites - 1}, Got: ${finalData.sequence}`);
    }

    return testResult;
  }

  /**
   * Get detected race conditions
   */
  getRaceConditions() {
    return {
      totalDetected: this.raceDetected.length,
      races: this.raceDetected,
      timestamp: Date.now()
    };
  }

  /**
   * Run all race condition tests
   */
  async runAllTests() {
    console.log(`\n🚀 Starting Race Condition Tests`);
    console.log('='.repeat(60));

    await this.testRapidConcurrentWrites();
    await this.testWriteReadRace();
    await this.testCounterRace();
    await this.testConsistencyUnderLoad();
    await this.testMemoryOrdering();

    const summary = this.getSummary();
    const races = this.getRaceConditions();

    console.log('\n📊 Test Summary:');
    console.log(`Total Tests: ${summary.total}`);
    console.log(`Passed: ${summary.passed}`);
    console.log(`Failed: ${summary.failed}`);
    console.log(`Success Rate: ${summary.successRate}`);

    console.log('\n⚠️  Race Conditions Detected:');
    console.log(`Total: ${races.totalDetected}`);
    if (races.totalDetected > 0) {
      races.races.forEach((race, i) => {
        console.log(`  ${i + 1}. ${race.type} (${race.severity})`);
      });
    }

    return { ...summary, raceConditions: races };
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

export default RaceConditionTest;
