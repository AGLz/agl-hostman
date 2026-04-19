/**
 * Example: Parallel Neural Training
 * Train multiple neural patterns simultaneously
 */

const { HiveMindWorkerPool } = require('../src/hive-mind-integration');

async function main() {
  const pool = new HiveMindWorkerPool();

  console.log('Training neural patterns in parallel...\n');

  // Define training configurations
  const trainingConfigs = [
    {
      patterns: Array(200).fill(0).map(() => Math.random()),
      epochs: 20,
      learningRate: 0.01
    },
    {
      patterns: Array(200).fill(0).map(() => Math.random()),
      epochs: 15,
      learningRate: 0.02
    },
    {
      patterns: Array(200).fill(0).map(() => Math.random()),
      epochs: 25,
      learningRate: 0.015
    },
    {
      patterns: Array(200).fill(0).map(() => Math.random()),
      epochs: 20,
      learningRate: 0.01
    }
  ];

  const startTime = Date.now();
  const results = await pool.trainNeuralPatternsParallel(trainingConfigs);
  const duration = Date.now() - startTime;

  console.log(`Completed ${results.length} training sessions in ${duration}ms\n`);

  // Display results
  console.log('Training Results:');
  results.forEach((result, i) => {
    const r = result.result;
    console.log(`  Session ${i + 1}:`);
    console.log(`    Epochs: ${r.epochs}`);
    console.log(`    Accuracy: ${(r.accuracy * 100).toFixed(2)}%`);
    console.log(`    Weights (sample): [${r.weights.slice(0, 5).map(w => w.toFixed(3)).join(', ')}, ...]`);
  });

  // Performance comparison
  const avgEpochs = trainingConfigs.reduce((sum, c) => sum + c.epochs, 0) / trainingConfigs.length;
  const sequentialEstimate = trainingConfigs.length * avgEpochs * 50; // ~50ms per epoch sequential

  console.log(`\nPerformance:`);
  console.log(`  Sequential estimate: ${sequentialEstimate}ms`);
  console.log(`  Parallel actual: ${duration}ms`);
  console.log(`  Speedup: ${(sequentialEstimate / duration).toFixed(1)}x`);

  await pool.terminate();
}

main().catch(console.error);
