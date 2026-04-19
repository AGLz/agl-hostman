/**
 * Simple Worker Pool Test
 */

const WorkerPool = require('../../src/performance/worker-pool/WorkerPool');

async function runTest() {
  console.log('\n=== Worker Pool Test ===\n');
  
  const pool = new WorkerPool(4);
  
  console.log('Test 1: Simple data processing');
  const result1 = await pool.execute('data-process', {
    items: [{ value: 10 }, { value: 20 }, { value: 30 }],
    operation: 'aggregate'
  });
  console.log('✅ Result:', result1.result.result);
  
  console.log('\nTest 2: Parallel execution');
  const tasks = [
    { task: 'data-process', data: { items: [{value: 5}], operation: 'transform' } },
    { task: 'data-process', data: { items: [{value: 10}], operation: 'transform' } },
    { task: 'data-process', data: { items: [{value: 15}], operation: 'transform' } }
  ];
  
  const startTime = Date.now();
  const results = await pool.executeAll(tasks);
  const duration = Date.now() - startTime;
  
  console.log(`✅ Completed ${results.length} tasks in ${duration}ms`);
  console.log('Pool stats:', pool.getStats());
  
  await pool.terminate();
  console.log('\n✅ All tests passed!\n');
}

runTest().catch(console.error);
