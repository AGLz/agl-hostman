/**
 * Hive Mind Worker Pool Integration Tests
 */

const { HiveMindWorkerPool } = require('../../src/hive-mind-integration');
const path = require('path');

async function runTests() {
  console.log('\n=== Hive Mind Worker Pool Integration Tests ===\n');

  const pool = new HiveMindWorkerPool({
    maxWorkers: 4,
    hiveMindDbPath: path.join(process.env.HOME, '.hive-mind/hive.db'),
    enableMetrics: true
  });

  try {
    // Test 1: Parallel Agent Spawning
    console.log('Test 1: Parallel Agent Spawning');
    const agentConfigs = [
      { type: 'researcher', name: 'Research-1', complexity: 1 },
      { type: 'coder', name: 'Dev-1', complexity: 2 },
      { type: 'analyst', name: 'Analyst-1', complexity: 1 },
      { type: 'coordinator', name: 'Coord-1', complexity: 1 }
    ];

    const startTime1 = Date.now();
    const agents = await pool.spawnAgentsParallel(agentConfigs, 'test-swarm-1');
    const duration1 = Date.now() - startTime1;

    console.log(`✅ Spawned ${agents.length} agents in ${duration1}ms`);
    console.log(`   Agents:`, agents.map(a => a.result.agentId).join(', '));

    // Test 2: Neural Training
    console.log('\nTest 2: Parallel Neural Training');
    const trainingConfigs = [
      { patterns: Array(100).fill(0), epochs: 5, learningRate: 0.01 },
      { patterns: Array(100).fill(0), epochs: 10, learningRate: 0.02 },
      { patterns: Array(100).fill(0), epochs: 5, learningRate: 0.01 }
    ];

    const startTime2 = Date.now();
    const trainResults = await pool.trainNeuralPatternsParallel(trainingConfigs);
    const duration2 = Date.now() - startTime2;

    console.log(`✅ Completed ${trainResults.length} training sessions in ${duration2}ms`);
    console.log(`   Average accuracy: ${(trainResults.reduce((sum, r) => sum + r.result.accuracy, 0) / trainResults.length).toFixed(2)}`);

    // Test 3: Batch Task Orchestration
    console.log('\nTest 3: Batch Task Orchestration');
    const tasks = Array.from({ length: 12 }, (_, i) => ({
      items: [{ value: i * 10 }, { value: i * 10 + 5 }],
      operation: 'aggregate'
    }));

    const startTime3 = Date.now();
    const taskResults = await pool.orchestrateTasksBatch(tasks, 4);
    const duration3 = Date.now() - startTime3;

    console.log(`✅ Orchestrated ${taskResults.length} tasks in ${duration3}ms`);
    console.log(`   Batches: ${Math.ceil(taskResults.length / 4)}`);

    // Test 4: Swarm Creation with Agents
    console.log('\nTest 4: Create Swarm with Parallel Agents');
    const swarmConfig = {
      objective: 'Performance testing swarm',
      queenType: 'strategic',
      agentCount: 6
    };

    const startTime4 = Date.now();
    const swarm = await pool.createSwarmWithAgents('Test-Swarm', swarmConfig);
    const duration4 = Date.now() - startTime4;

    console.log(`✅ Created swarm ${swarm.swarmId} in ${duration4}ms`);
    console.log(`   Agents: ${swarm.agents.length}`);
    console.log(`   Agent types:`, swarm.agents.map(a => a.type).join(', '));

    // Test 5: Performance Statistics
    console.log('\nTest 5: Performance Statistics');
    const stats = pool.getPerformanceStats();

    console.log('Worker Pool Stats:', {
      tasksCompleted: stats.workerPool.tasksCompleted,
      tasksFailed: stats.workerPool.tasksFailed,
      avgExecutionTime: stats.workerPool.avgExecutionTime.toFixed(1) + 'ms',
      utilization: stats.workerPool.utilization
    });

    console.log('Hive Mind Stats:', {
      agentsSpawned: stats.hiveMind.agentsSpawned,
      neuralTrainings: stats.hiveMind.neuralTrainings,
      tasksOrchestrated: stats.hiveMind.tasksOrchestrated,
      speedupFactor: stats.hiveMind.averageSpeedupFactor.toFixed(1) + 'x'
    });

    console.log('Database Stats:', stats.database);

    console.log('System Stats:', {
      cpuCores: stats.system.cpuCores,
      maxWorkers: stats.system.maxWorkers,
      utilization: stats.system.utilizationRate
    });

    console.log('\n✅ All tests passed!\n');

  } catch (error) {
    console.error('\n❌ Test failed:', error);
    console.error(error.stack);
  } finally {
    await pool.terminate();
  }
}

// Run tests
runTests().catch(console.error);
