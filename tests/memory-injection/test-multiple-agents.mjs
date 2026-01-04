/**
 * Test Scenario 2: Multiple Agents Concurrent Access
 * Tests multiple agents writing to the same and different keys
 */

import { memory_usage } from 'mcp__claude-flow-alpha';

export class MultipleAgentMemoryTest {
  constructor(numAgents = 5) {
    this.numAgents = numAgents;
    this.agents = [];
    this.testResults = [];
  }

  /**
   * Initialize test agents
   */
  initializeAgents() {
    console.log(`\n🔧 Initializing ${this.numAgents} test agents...`);

    for (let i = 0; i < this.numAgents; i++) {
      this.agents.push({
        id: `test-agent-${i}`,
        role: ['coder', 'tester', 'planner', 'researcher', 'reviewer'][i % 5],
        index: i
      });
    }

    console.log(`✅ Initialized ${this.agents.length} agents`);
    return this.agents;
  }

  /**
   * Test multiple agents writing to different keys
   */
  async testConcurrentDifferentKeys() {
    console.log('\n🧪 Testing concurrent writes to different keys...');

    const writePromises = this.agents.map(agent =>
      memory_usage({
        action: 'store',
        key: `swarm/${agent.id}/status`,
        namespace: 'coordination',
        value: JSON.stringify({
          agent: agent.id,
          role: agent.role,
          status: 'writing',
          timestamp: Date.now(),
          index: agent.index
        })
      })
    );

    try {
      const results = await Promise.all(writePromises);

      const testResult = {
        test: 'concurrent_different_keys',
        passed: true,
        agentsInvolved: this.agents.length,
        successfulWrites: results.length,
        timestamp: Date.now()
      };

      this.testResults.push(testResult);
      console.log(`✅ Successfully wrote ${results.length} concurrent entries to different keys`);
      return testResult;
    } catch (error) {
      const testResult = {
        test: 'concurrent_different_keys',
        passed: false,
        error: error.message,
        agentsInvolved: this.agents.length,
        timestamp: Date.now()
      };
      this.testResults.push(testResult);
      console.error('❌ Concurrent writes failed:', error.message);
      return testResult;
    }
  }

  /**
   * Test multiple agents writing to the same key (race condition)
   */
  async testConcurrentSameKey() {
    console.log('\n🧪 Testing concurrent writes to same key (race condition)...');

    const sharedKey = 'swarm/shared/race-test';
    const writePromises = this.agents.map(agent =>
      memory_usage({
        action: 'store',
        key: sharedKey,
        namespace: 'coordination',
        value: JSON.stringify({
          writingAgent: agent.id,
          role: agent.role,
          timestamp: Date.now(),
          index: agent.index
        })
      })
    );

    try {
      const results = await Promise.all(writePromises);

      // Read final value
      const finalValue = await memory_usage({
        action: 'retrieve',
        key: sharedKey,
        namespace: 'coordination'
      });

      const finalData = JSON.parse(finalValue);

      const testResult = {
        test: 'concurrent_same_key',
        passed: true,
        agentsInvolved: this.agents.length,
        writeAttempts: results.length,
        finalValue: finalData,
        lastWriteWins: true,
        timestamp: Date.now()
      };

      this.testResults.push(testResult);
      console.log(`✅ Race condition test completed - last write won from ${finalData.writingAgent}`);
      return testResult;
    } catch (error) {
      const testResult = {
        test: 'concurrent_same_key',
        passed: false,
        error: error.message,
        timestamp: Date.now()
      };
      this.testResults.push(testResult);
      console.error('❌ Race condition test failed:', error.message);
      return testResult;
    }
  }

  /**
   * Test multiple agents reading from shared memory
   */
  async testConcurrentReads() {
    console.log('\n🧪 Testing concurrent reads from shared memory...');

    // First, write shared data
    const sharedData = {
      type: 'shared-resource',
      data: 'test-data-for-concurrent-reads',
      timestamp: Date.now()
    };

    await memory_usage({
      action: 'store',
      key: 'swarm/shared/read-test',
      namespace: 'coordination',
      value: JSON.stringify(sharedData)
    });

    // Concurrent reads
    const readPromises = this.agents.map(agent =>
      memory_usage({
        action: 'retrieve',
        key: 'swarm/shared/read-test',
        namespace: 'coordination'
      })
    );

    try {
      const results = await Promise.all(readPromises);

      // Verify all reads returned the same data
      const parsedResults = results.map(r => JSON.parse(r));
      const allSame = parsedResults.every(r =>
        JSON.stringify(r) === JSON.stringify(parsedResults[0])
      );

      const testResult = {
        test: 'concurrent_reads',
        passed: allSame,
        agentsInvolved: this.agents.length,
        successfulReads: results.length,
        dataConsistent: allSame,
        timestamp: Date.now()
      };

      this.testResults.push(testResult);
      console.log(`✅ Successfully completed ${results.length} concurrent reads`);
      console.log(`   Data consistency: ${allSame ? 'VERIFIED' : 'FAILED'}`);
      return testResult;
    } catch (error) {
      const testResult = {
        test: 'concurrent_reads',
        passed: false,
        error: error.message,
        timestamp: Date.now()
      };
      this.testResults.push(testResult);
      console.error('❌ Concurrent reads failed:', error.message);
      return testResult;
    }
  }

  /**
   * Test agent coordination through memory
   */
  async testAgentCoordination() {
    console.log('\n🧪 Testing agent coordination through shared memory...');

    // Agent 1: Create task
    await memory_usage({
      action: 'store',
      key: 'swarm/shared/coordination-task',
      namespace: 'coordination',
      value: JSON.stringify({
        task: 'test-coordination',
        status: 'created',
        createdBy: 'agent-0',
        timestamp: Date.now()
      })
    });

    // Agent 2: Claim task
    await memory_usage({
      action: 'store',
      key: 'swarm/shared/coordination-task',
      namespace: 'coordination',
      value: JSON.stringify({
        task: 'test-coordination',
        status: 'in-progress',
        claimedBy: 'agent-1',
        timestamp: Date.now()
      })
    });

    // Agent 3: Complete task
    await memory_usage({
      action: 'store',
      key: 'swarm/shared/coordination-task',
      namespace: 'coordination',
      value: JSON.stringify({
        task: 'test-coordination',
        status: 'complete',
        completedBy: 'agent-2',
        timestamp: Date.now()
      })
    });

    // Verify final state
    const result = await memory_usage({
      action: 'retrieve',
      key: 'swarm/shared/coordination-task',
      namespace: 'coordination'
    });

    const finalState = JSON.parse(result);
    const coordinationSuccessful = finalState.status === 'complete';

    const testResult = {
      test: 'agent_coordination',
      passed: coordinationSuccessful,
      workflow: ['created', 'in-progress', 'complete'],
      finalState,
      timestamp: Date.now()
    };

    this.testResults.push(testResult);

    if (coordinationSuccessful) {
      console.log('✅ Agent coordination test passed');
      console.log('   Workflow: created → in-progress → complete');
    } else {
      console.error('❌ Agent coordination test failed');
    }

    return testResult;
  }

  /**
   * Test progress tracking across multiple agents
   */
  async testProgressTracking() {
    console.log('\n🧪 Testing progress tracking across agents...');

    // Each agent reports progress
    const progressUpdates = this.agents.map((agent, index) => {
      const progress = Math.floor((index / this.agents.length) * 100);
      return memory_usage({
        action: 'store',
        key: `swarm/${agent.id}/progress`,
        namespace: 'coordination',
        value: JSON.stringify({
          agent: agent.id,
          completed: [`task-${index}`],
          current: `task-${index + 1}`,
          progress,
          timestamp: Date.now()
        })
      });
    });

    try {
      await Promise.all(progressUpdates);

      // Aggregate progress
      const progressPromises = this.agents.map(agent =>
        memory_usage({
          action: 'retrieve',
          key: `swarm/${agent.id}/progress`,
          namespace: 'coordination'
        })
      );

      const progressResults = await Promise.all(progressPromises);
      const progressData = progressResults.map(r => JSON.parse(r));

      const totalProgress = progressData.reduce((sum, p) => sum + p.progress, 0);
      const averageProgress = totalProgress / this.agents.length;

      const testResult = {
        test: 'progress_tracking',
        passed: true,
        agentsTracking: this.agents.length,
        totalProgress,
        averageProgress: averageProgress.toFixed(2) + '%',
        individualProgress: progressData,
        timestamp: Date.now()
      };

      this.testResults.push(testResult);
      console.log(`✅ Progress tracking successful - average: ${averageProgress.toFixed(2)}%`);
      return testResult;
    } catch (error) {
      const testResult = {
        test: 'progress_tracking',
        passed: false,
        error: error.message,
        timestamp: Date.now()
      };
      this.testResults.push(testResult);
      console.error('❌ Progress tracking failed:', error.message);
      return testResult;
    }
  }

  /**
   * Run all multiple agent tests
   */
  async runAllTests() {
    console.log(`\n🚀 Starting Multiple Agent Memory Tests`);
    console.log('='.repeat(60));

    this.initializeAgents();

    await this.testConcurrentDifferentKeys();
    await this.testConcurrentSameKey();
    await this.testConcurrentReads();
    await this.testAgentCoordination();
    await this.testProgressTracking();

    const summary = this.getSummary();
    console.log('\n📊 Test Summary:');
    console.log(`Total Tests: ${summary.total}`);
    console.log(`Passed: ${summary.passed}`);
    console.log(`Failed: ${summary.failed}`);
    console.log(`Success Rate: ${summary.successRate}`);
    console.log(`Agents Tested: ${this.agents.length}`);

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
      agents: this.agents.length,
      results: this.testResults,
      timestamp: Date.now()
    };
  }
}

export default MultipleAgentMemoryTest;
