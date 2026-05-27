#!/usr/bin/env node
/**
 * Exemplo Claude Flow: Route → Hive Mind spawn → múltiplos agentes
 * Uso: node scripts/exemplo-claude-flow-completo.js "Implemente API e testes"
 * Ref: docs/CLAUDE-FLOW-EXEMPLO-COMPLETO.md
 */

const path = require('path');

// Route (keyword matching)
const routerPath = path.join(__dirname, '../.claude/helpers/router.js');
const router = require(routerPath);

async function main() {
  const prompt = process.argv[2] || 'Implemente API REST e escreva testes';

  console.log('\n=== Claude Flow — Route + Hive Mind Spawn ===\n');

  // 1. Route — qual agente para esta tarefa?
  const route = router.routeTask(prompt);
  console.log(`[ROUTE] Agent: ${route.agent} (${(route.confidence * 100).toFixed(0)}%)`);
  console.log(`        Reason: ${route.reason}\n`);

  // 2. Mapear para configs de agentes
  const agentTypes =
    route.agent === 'backend-dev'
      ? ['backend-dev', 'tester', 'reviewer']
      : [route.agent, 'coder', 'reviewer'];

  const agentConfigs = agentTypes.map((type, i) => ({
    type,
    name: `${type}-${i + 1}`,
    complexity: type === 'tester' ? 1 : 2,
  }));

  console.log('[SPAWN] Agentes a spawnar:', agentConfigs.map((a) => a.type).join(', '));

  // 3. Hive Mind spawn (se HiveMindWorkerPool disponível)
  try {
    const { HiveMindWorkerPool } = require('../src/hive-mind-integration');
    const pool = new HiveMindWorkerPool({
      maxWorkers: 4,
      hiveMindDbPath: path.join(process.env.HOME || '/tmp', '.hive-mind/hive.db'),
    });

    const agents = await pool.spawnAgentsParallel(agentConfigs, 'exemplo-demo');
    console.log(`\n✅ Spawned ${agents.length} agentes:`, agents.map((a) => a.result?.agentId || a).join(', '));
    await pool.terminate();
  } catch (err) {
    console.log('\n⚠️  HiveMindWorkerPool não disponível:', err.message);
    console.log('   Para spawn real: npx ruflo hive-mind spawn "' + prompt + '" --queen-type tactical');
  }

  console.log('\n=== Fim ===\n');
}

main().catch(console.error);
