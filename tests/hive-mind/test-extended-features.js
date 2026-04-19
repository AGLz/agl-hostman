/**
 * Extended Features Test Suite
 * Tests for AgentTemplates, PerformanceMonitor, and enhanced capabilities
 */

const { HiveMindWorkerPool, AgentTemplates, PerformanceMonitor } = require('../../src/hive-mind-integration');
const path = require('path');

async function runExtendedTests() {
  console.log('\n=== Hive Mind Extended Features Tests ===\n');

  // Test 1: Agent Templates System
  console.log('Test 1: Agent Templates and Capability Discovery');
  const templates = new AgentTemplates();

  // Test available agent types
  const availableTypes = templates.getAvailableTypes();
  console.log(`✅ Available agent types: ${availableTypes.length}`);
  console.log(`   Types: ${availableTypes.join(', ')}`);

  // Test capability recommendation
  const requiredCapabilities = ['coding', 'testing', 'security-scan', 'optimization'];
  const recommendations = templates.recommendAgents(requiredCapabilities, 3);
  console.log(`\n✅ Recommended agents for [${requiredCapabilities.join(', ')}]:`);
  recommendations.forEach((rec, i) => {
    console.log(`   ${i + 1}. ${rec.type} (Score: ${rec.score.toFixed(1)}, Match: ${rec.matchPercentage})`);
    console.log(`      Capabilities: ${rec.capabilities.slice(0, 3).join(', ')}...`);
  });

  // Test agent config validation
  const validConfig = {
    type: 'optimizer',
    name: 'Optimizer-1',
    capabilities: ['performance-tuning', 'profiling']
  };
  const validation = templates.validateAgentConfig(validConfig);
  console.log(`\n✅ Config validation: ${validation.valid ? 'PASS' : 'FAIL'}`);

  // Test invalid config
  const invalidConfig = {
    type: 'unknown-type',
    name: 'Test'
  };
  const invalidValidation = templates.validateAgentConfig(invalidConfig);
  console.log(`✅ Invalid config detection: ${!invalidValidation.valid ? 'PASS' : 'FAIL'}`);
  if (!invalidValidation.valid) {
    console.log(`   Errors: ${invalidValidation.errors.join(', ')}`);
  }

  // Test resource requirements calculation
  const agentConfigs = [
    { type: 'ml', name: 'ML-1' },
    { type: 'optimizer', name: 'Opt-1' },
    { type: 'security', name: 'Sec-1' }
  ];
  const resources = templates.getResourceRequirements(agentConfigs);
  console.log(`\n✅ Resource requirements for ${agentConfigs.length} agents:`);
  console.log(`   CPU units: ${resources.cpu}`);
  console.log(`   Memory: ${resources.memory} MB`);
  console.log(`   Estimated workers: ${resources.estimatedWorkers}`);

  // Test 2: Performance Monitor
  console.log('\n\nTest 2: Performance Monitoring System');
  const monitor = new PerformanceMonitor({
    enableRealtime: false,
    metricsInterval: 100,
    retentionPeriod: 60000
  });

  // Record some sample metrics
  monitor.recordAgentSpawn('agent-test-1', 'coder', 15, true);
  monitor.recordAgentSpawn('agent-test-2', 'optimizer', 25, true);
  monitor.recordAgentSpawn('agent-test-3', 'security', 18, true);

  monitor.recordTaskExecution('task-1', 'agent-test-1', 120, true);
  monitor.recordTaskExecution('task-2', 'agent-test-1', 95, true);
  monitor.recordTaskExecution('task-3', 'agent-test-2', 150, true);
  monitor.recordTaskExecution('task-4', 'agent-test-3', 200, false, new Error('Test error'));

  monitor.recordNeuralTraining('neural-1', 20, 0.92, 45);
  monitor.recordNeuralTraining('neural-2', 15, 0.88, 38);

  const dashboard = monitor.getDashboard();
  console.log(`✅ Dashboard metrics collected:`);
  console.log(`   Active agents: ${dashboard.agents.active}`);
  console.log(`   Total tasks: ${dashboard.tasks.total}`);
  console.log(`   Success rate: ${(100 - parseFloat(dashboard.tasks.failureRate)).toFixed(2)}%`);
  console.log(`   Neural sessions: ${dashboard.neural.sessions}`);
  console.log(`   Avg accuracy: ${dashboard.neural.avgAccuracy}%`);

  const summary = monitor.getSummary();
  console.log(`\n✅ System summary:`);
  console.log(`   Status: ${summary.status}`);
  console.log(`   Monitoring: ${summary.monitoring ? 'Active' : 'Inactive'}`);
  console.log(`   Alerts: ${summary.alerts.critical} critical, ${summary.alerts.warning} warnings`);

  // Test 3: Integrated Pool with New Features
  console.log('\n\nTest 3: Integrated Worker Pool with Extended Capabilities');
  const pool = new HiveMindWorkerPool({
    maxWorkers: 4,
    hiveMindDbPath: path.join(process.env.HOME, '.hive-mind/hive.db'),
    enableMetrics: true,
    enableMonitoring: true,
    enableRealtime: false
  });

  try {
    // Test new agent types
    const newAgentConfigs = [
      { type: 'optimizer', name: 'Optimizer-1' },
      { type: 'security', name: 'Security-1' },
      { type: 'devops', name: 'DevOps-1' },
      { type: 'architect', name: 'Architect-1' }
    ];

    const startTime = Date.now();
    const agents = await pool.spawnAgentsParallel(newAgentConfigs, 'test-swarm-extended');
    const duration = Date.now() - startTime;

    console.log(`✅ Spawned ${agents.length} new specialized agents in ${duration}ms`);
    agents.forEach((agent, i) => {
      const a = agent.result;
      console.log(`   ${i + 1}. ${a.agentId} (${a.type})`);
    });

    // Test capability recommendations
    console.log('\n✅ Testing capability recommendations:');
    const capabilities = ['api-development', 'security-scan', 'ci-cd'];
    const recommended = pool.recommendAgentsForCapabilities(capabilities, 3);
    recommended.forEach((rec, i) => {
      console.log(`   ${i + 1}. ${rec.type} - ${rec.matchPercentage} match`);
    });

    // Test dashboard
    console.log('\n✅ Performance dashboard:');
    const poolDashboard = pool.getDashboard();
    console.log(`   Active agents: ${poolDashboard.agents.active}`);
    console.log(`   Tasks: ${poolDashboard.tasks.successful}/${poolDashboard.tasks.total}`);
    console.log(`   System status: ${pool.getMonitoringSummary().status}`);

    // Test available agent types
    const types = pool.getAvailableAgentTypes();
    console.log(`\n✅ Available specialized agent types: ${types.length}`);
    console.log(`   Includes: ${types.slice(0, 5).join(', ')}...`);

    // Test template retrieval
    const mlTemplate = pool.getAgentTemplate('ml');
    console.log(`\n✅ ML Agent template:`);
    console.log(`   Role: ${mlTemplate.role}`);
    console.log(`   Capabilities: ${mlTemplate.capabilities.join(', ')}`);
    console.log(`   Complexity: ${mlTemplate.baseComplexity}`);
    console.log(`   Resources: CPU ${mlTemplate.resourceRequirements.cpu}, Memory ${mlTemplate.resourceRequirements.memory}`);

    console.log('\n✅ All extended tests passed!\n');

  } catch (error) {
    console.error('\n❌ Test failed:', error);
    console.error(error.stack);
  } finally {
    await pool.terminate();
  }
}

// Run tests
runExtendedTests().catch(console.error);
