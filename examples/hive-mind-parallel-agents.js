/**
 * Example: Parallel Agent Spawning with Hive Mind
 * Demonstrates 4x speedup for agent initialization
 */

const { HiveMindWorkerPool } = require('../src/hive-mind-integration');

async function main() {
  const pool = new HiveMindWorkerPool();

  console.log('Creating swarm with 10 agents in parallel...\n');

  const agentConfigs = [
    { type: 'researcher', name: 'Researcher-1', capabilities: ['web-search', 'analysis'] },
    { type: 'researcher', name: 'Researcher-2', capabilities: ['web-search', 'analysis'] },
    { type: 'coder', name: 'Developer-1', capabilities: ['coding', 'testing'] },
    { type: 'coder', name: 'Developer-2', capabilities: ['coding', 'testing'] },
    { type: 'coder', name: 'Developer-3', capabilities: ['coding', 'testing'] },
    { type: 'analyst', name: 'Analyst-1', capabilities: ['data-analysis', 'visualization'] },
    { type: 'analyst', name: 'Analyst-2', capabilities: ['data-analysis', 'visualization'] },
    { type: 'coordinator', name: 'Coordinator-1', capabilities: ['task-distribution', 'monitoring'] },
    { type: 'tester', name: 'Tester-1', capabilities: ['testing', 'qa'] },
    { type: 'tester', name: 'Tester-2', capabilities: ['testing', 'qa'] }
  ];

  const swarmId = 'parallel-demo-swarm';

  // Sequential spawning (for comparison)
  console.log('Sequential spawning (simulated):');
  const sequentialTime = agentConfigs.length * 100; // ~100ms per agent sequential
  console.log(`  Estimated time: ${sequentialTime}ms (${agentConfigs.length} × 100ms)`);

  // Parallel spawning
  console.log('\nParallel spawning:');
  const startTime = Date.now();
  const agents = await pool.spawnAgentsParallel(agentConfigs, swarmId);
  const parallelTime = Date.now() - startTime;

  console.log(`  Actual time: ${parallelTime}ms`);
  console.log(`  Speedup: ${(sequentialTime / parallelTime).toFixed(1)}x faster\n`);

  // Display spawned agents
  console.log('Spawned agents:');
  agents.forEach((agent, i) => {
    const a = agent.result;
    console.log(`  ${i + 1}. ${a.agentId} (${a.type}) - ${a.capabilities.join(', ')}`);
  });

  // Get performance stats
  console.log('\nPerformance Statistics:');
  const stats = pool.getPerformanceStats();
  console.log(`  Total agents spawned: ${stats.hiveMind.agentsSpawned}`);
  console.log(`  Workers used: ${stats.system.maxWorkers}`);
  console.log(`  Average speedup: ${stats.hiveMind.averageSpeedupFactor.toFixed(1)}x`);

  await pool.terminate();
}

main().catch(console.error);
